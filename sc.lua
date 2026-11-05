--[[
    StructScope v2.0  -  ByteNet Debugger + Framework Generator (LINORIA UI)
    PASIF: hanya membaca / merekam. Debugger tidak mengirim, mengubah, atau memutar ulang packet.

    FITUR UTAMA
      * Channel RELIABLE / UNRELIABLE per packet:
          - OUT : pasti (hook process.client.sendReliable / sendUnreliable)
          - IN  : dari definisi packet (reliabilityType) atau heuristik RemoteEvent
                  (tanda "~" artinya hasil tebakan)
      * Tiga sumber struct: DECLARED (definisi ByteNet), OBSERVED (data nyata), TEBAKAN
      * Statistik channel: jumlah packet, byte mentah RemoteEvent, packet/detik
      * Log packet + chat log, filter arah / channel / kategori / nama
      * Generator FRAMEWORK : Packets.lua (definePacket + reliabilityType),
                              Dokumentasi Markdown, Template script per packet
      * API untuk script baru: getgenv().StructScope

    API (getgenv().StructScope) untuk script lain:
      StructScope.Packets.get(namaAtauId)   -> objek ByteNet asli (listen / send)
      StructScope.Packets.info(namaAtauId)  -> { id, name, channel, source, struct, schema, counts }
      StructScope.Packets.list()            -> daftar nama packet
      StructScope.Subscribe(function(name, dir, chan, data, entry) end) -> fungsi unsubscribe
      StructScope.Log / StructScope.Chat    -> tabel log
      StructScope.Stats()                   -> { inR, inU, outR, outU, ... }
      StructScope.Export.framework() / .docs() / .report()  -> string
]]

------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------
local VERSION = "2.0"
local CFG = {
	MaxSamples = 12,     -- sampel terakhir yang disimpan per packet
	LearnLimit = 300,    -- jumlah data per packet yang dipelajari penuh (sisanya 1 dari 20)
	FeedMax    = 250,    -- baris live feed
	LogMax     = 1500,   -- entri log packet keseluruhan
	MoveCap    = 6,      -- maks packet movement dicatat per detik (0 = tanpa batas)
	TextLimit  = 12000,  -- batas karakter di viewer (Copy/Save tetap penuh)
	Ascii      = true,   -- ganti karakter non-ASCII jadi '?' (cegah huruf kotak)
	MenuKey    = "RightShift",
	AutoScanEvery = 20,  -- detik, bila Auto-scan dinyalakan
}

------------------------------------------------------------------
-- SERVICES
------------------------------------------------------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

if getgenv and getgenv().__StructScopeUnload then
	pcall(getgenv().__StructScopeUnload)
end

------------------------------------------------------------------
-- LOAD LINORIA
------------------------------------------------------------------
local REPO = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local okLib, Library = pcall(function()
	return loadstring(game:HttpGet(REPO .. "Library.lua"))()
end)
if not okLib or type(Library) ~= "table" then
	warn("[StructScope] Gagal memuat Linoria: " .. tostring(Library))
	return
end

------------------------------------------------------------------
-- UTIL
------------------------------------------------------------------
local conns, running = {}, true
local function track(c) conns[#conns + 1] = c return c end

local function notify(text, t)
	pcall(function() Library:Notify(text, t or 3) end)
end

local function clip(text)
	local fn = setclipboard or toclipboard
	if fn then return (pcall(fn, text)) end
	return false
end

local function ascii(s) return (tostring(s):gsub("[\128-\255]", "?")) end

local function pad(s, n)
	s = tostring(s)
	if #s >= n then return s end
	return s .. string.rep(" ", n - #s)
end

local function fnum(n)
	if n ~= n then return "nan" end
	if n == math.huge then return "inf" end
	if n == -math.huge then return "-inf" end
	if n % 1 == 0 and math.abs(n) < 1e15 then return string.format("%d", n) end
	return string.format("%.7g", n)
end

local RESERVED = {}
for w in ("and break do else elseif end false for function goto if in local nil not or repeat return then true until while continue export type"):gmatch("%S+") do
	RESERVED[w] = true
end
local IDENT = "^[%a_][%w_]*$"

local function isArray(v)
	local n = #v
	if n == 0 then return false end
	for k in pairs(v) do
		if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then return false end
	end
	return true
end

local function sortedKeys(t)
	local keys = {}
	for k in next, t do keys[#keys + 1] = k end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta == tb and (ta == "number" or ta == "string") then return a < b end
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function identOf(s)
	s = (tostring(s):gsub("[^%w_]", "_"))
	if s == "" then s = "_" end
	if s:match("^%d") or RESERVED[s] then s = "_" .. s end
	return s
end

-- literal satu baris (ringkas)
local function lit(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "nil" then return "nil"
	elseif t == "boolean" then return tostring(v)
	elseif t == "number" then return fnum(v)
	elseif t == "string" then
		local s = v
		if #s > 80 then s = s:sub(1, 77) .. "..." end
		return string.format("%q", s)
	elseif t == "Vector3" then return ("Vector3.new(%s, %s, %s)"):format(fnum(v.X), fnum(v.Y), fnum(v.Z))
	elseif t == "Vector2" then return ("Vector2.new(%s, %s)"):format(fnum(v.X), fnum(v.Y))
	elseif t == "CFrame" then
		local p = v.Position
		return ("CFrame.new(%s, %s, %s)"):format(fnum(p.X), fnum(p.Y), fnum(p.Z))
	elseif t == "Color3" then return ("Color3.new(%s, %s, %s)"):format(fnum(v.R), fnum(v.G), fnum(v.B))
	elseif t == "EnumItem" then return tostring(v)
	elseif t == "Instance" then
		local ok, name = pcall(function() return v:GetFullName() end)
		return string.format("%q", "@" .. (ok and name or "?"))
	elseif t == "buffer" then return "buffer(len=" .. buffer.len(v) .. ")"
	elseif t == "table" then
		if depth >= 4 then return "{...}" end
		local parts = {}
		if isArray(v) then
			for i = 1, math.min(#v, 8) do parts[#parts + 1] = lit(v[i], depth + 1) end
			if #v > 8 then parts[#parts + 1] = "...(+" .. (#v - 8) .. ")" end
		else
			local n = 0
			for _, k in ipairs(sortedKeys(v)) do
				n += 1
				if n > 12 then parts[#parts + 1] = "..." break end
				local ks = (type(k) == "string" and k:match(IDENT)) and k or ("[" .. lit(k, depth + 1) .. "]")
				parts[#parts + 1] = ks .. " = " .. lit(v[k], depth + 1)
			end
		end
		if #parts == 0 then return "{}" end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	return "<" .. t .. ">"
end

-- source Lua multi-baris (untuk Copy / Save)
local function luaSrc(v, indent, depth, seen)
	local t = typeof(v)
	if t == "table" then
		if seen[v] then return "nil --[[siklik]]" end
		if depth >= 10 then return "nil --[[terlalu dalam]]" end
		seen[v] = true
		local p1, parts = string.rep("\t", indent + 1), {}
		if isArray(v) then
			for i = 1, #v do parts[#parts + 1] = p1 .. luaSrc(v[i], indent + 1, depth + 1, seen) end
		else
			for _, k in ipairs(sortedKeys(v)) do
				local ks = (type(k) == "string" and k:match(IDENT) and not RESERVED[k]) and k
					or ("[" .. luaSrc(k, indent + 1, depth + 1, seen) .. "]")
				parts[#parts + 1] = p1 .. ks .. " = " .. luaSrc(v[k], indent + 1, depth + 1, seen)
			end
		end
		seen[v] = nil
		if #parts == 0 then return "{}" end
		return "{\n" .. table.concat(parts, ",\n") .. ",\n" .. string.rep("\t", indent) .. "}"
	elseif t == "string" then
		return string.format("%q", v)
	elseif t == "buffer" then
		local ok, s = pcall(buffer.tostring, v)
		if not ok then return "nil" end
		if #s > 128 then s = s:sub(1, 128) end
		local hex = s:gsub(".", function(c) return ("\\x%02X"):format(c:byte()) end)
		return 'buffer.fromstring("' .. hex .. '")'
	end
	return lit(v)
end

-- salinan data (tabel dalam); buffer disimpan apa adanya
local function deepCopy(v, depth, seen)
	depth = depth or 0
	if typeof(v) ~= "table" then return v end
	seen = seen or {}
	if seen[v] or depth >= 8 then return nil end
	seen[v] = true
	local out, n = {}, 0
	for k, val in next, v do
		n += 1
		if n > 300 then break end
		out[type(k) == "table" and tostring(k) or k] = deepCopy(val, depth + 1, seen)
	end
	seen[v] = nil
	return out
end

-- pohon bertipe (mudah dibaca)
local function tree(v, name, ind, out, depth)
	local p = string.rep("  ", ind)
	local t = typeof(v)
	if t == "table" then
		local arr = isArray(v)
		local cnt = 0
		for _ in next, v do cnt += 1 end
		out[#out + 1] = ("%s%s: %s (%d)"):format(p, name, arr and "array" or "object", cnt)
		if depth >= 8 then out[#out + 1] = p .. "  ..." return end
		local keys = sortedKeys(v)
		for i, k in ipairs(keys) do
			if i > 40 then out[#out + 1] = ("%s  ... +%d lainnya"):format(p, #keys - 40) break end
			tree(v[k], arr and ("[" .. tostring(k) .. "]") or tostring(k), ind + 1, out, depth + 1)
		end
	elseif t == "buffer" then
		out[#out + 1] = ("%s%s: buffer (len=%d)"):format(p, name, buffer.len(v))
	else
		out[#out + 1] = ("%s%s: %s = %s"):format(p, name, t, lit(v))
	end
end

------------------------------------------------------------------
-- LEARN: skema dari data nyata
------------------------------------------------------------------
local function newNode() return { n = 0, types = {} } end

local function addVal(node, key, v)
	node.vals = node.vals or {}
	node.valSet = node.valSet or {}
	if node.valSet[key] then return end
	if #node.vals >= 8 then node.valOver = true return end
	node.valSet[key] = true
	node.vals[#node.vals + 1] = v
end

local function learn(node, v, depth)
	depth = depth or 0
	node = node or newNode()
	node.n += 1
	local t = typeof(v)
	if t == "table" then
		if depth >= 8 then node.types.object = true return node end
		if next(v) == nil then
			node.types.array = true
			node.len = node.len or { min = 0, max = 0 }
			node.len.min = 0
		elseif isArray(v) then
			node.types.array = true
			local n = #v
			node.len = node.len or { min = n, max = n }
			node.len.min = math.min(node.len.min, n)
			node.len.max = math.max(node.len.max, n)
			for i = 1, math.min(n, 30) do node.item = learn(node.item, v[i], depth + 1) end
		else
			node.types.object = true
			node.objN = (node.objN or 0) + 1
			node.fields = node.fields or {}
			for k, val in next, v do
				local key = tostring(k)
				node.fields[key] = learn(node.fields[key], val, depth + 1)
			end
		end
	elseif t == "number" then
		node.types.number = true
		if v == v then
			local s = node.num
			if not s then s = { min = v, max = v, int = true, f32 = true } node.num = s end
			if v < s.min then s.min = v end
			if v > s.max then s.max = v end
			if v % 1 ~= 0 or v == math.huge or v == -math.huge then s.int = false end
			if s.f32 then
				local ok, back = pcall(function() return string.unpack("<f", string.pack("<f", v)) end)
				if not ok or back ~= v then s.f32 = false end
			end
			addVal(node, v, v)
		end
	elseif t == "string" then
		node.types.string = true
		local s = node.str or { min = #v, max = #v }
		node.str = s
		s.min, s.max = math.min(s.min, #v), math.max(s.max, #v)
		if #v <= 40 then addVal(node, v, v) end
	elseif t == "boolean" then
		node.types.boolean = true
		addVal(node, v, v)
	elseif t == "buffer" then
		node.types.buffer = true
		local l = buffer.len(v)
		local s = node.blen or { min = l, max = l }
		node.blen = s
		s.min, s.max = math.min(s.min, l), math.max(s.max, l)
	else
		node.types[t] = true
	end
	return node
end

local function typeLabel(node)
	local ks = {}
	for k in pairs(node.types) do
		if k == "number" and node.num then ks[#ks + 1] = node.num.int and "int" or "float"
		else ks[#ks + 1] = k end
	end
	table.sort(ks)
	return #ks > 0 and table.concat(ks, "|") or "any"
end

local function detail(node)
	local parts, t = {}, node.types
	if t.number and node.num then
		local s = node.num
		local d = ("%s..%s"):format(fnum(s.min), fnum(s.max))
		if not s.int then d = d .. (s.f32 and " (muat f32)" or " (butuh f64)") end
		parts[#parts + 1] = d
	end
	if t.string and node.str then parts[#parts + 1] = ("len %d..%d"):format(node.str.min, node.str.max) end
	if t.array and node.len then parts[#parts + 1] = ("panjang %d..%d"):format(node.len.min, node.len.max) end
	if t.buffer and node.blen then parts[#parts + 1] = ("byte %d..%d"):format(node.blen.min, node.blen.max) end
	if node.vals and #node.vals > 0 then
		local vs = {}
		for i = 1, math.min(#node.vals, 6) do vs[i] = lit(node.vals[i]) end
		local label = node.valOver and "contoh: " or ((node.n >= 5) and "nilai (enum?): " or "nilai: ")
		parts[#parts + 1] = label .. table.concat(vs, ", ") .. (node.valOver and ", ..." or "")
	end
	return table.concat(parts, " | ")
end

local function flatten(node, path, rows, optional)
	rows[#rows + 1] = { path = path == "" and "(root)" or path, node = node, opt = optional }
	if node.fields then
		for _, k in ipairs(sortedKeys(node.fields)) do
			local f = node.fields[k]
			flatten(f, path == "" and k or (path .. "." .. k), rows, f.n < (node.objN or f.n))
		end
	end
	if node.item then flatten(node.item, path .. "[]", rows, false) end
end

-- tebakan definisi ByteNet dari data observed
local function numExpr(node)
	local s = node.num
	if not s then return "ByteNet.float64" end
	if s.int then
		if s.min >= 0 then
			if s.max <= 255 then return "ByteNet.uint8"
			elseif s.max <= 65535 then return "ByteNet.uint16"
			elseif s.max <= 4294967295 then return "ByteNet.uint32" end
		else
			if s.min >= -128 and s.max <= 127 then return "ByteNet.int8"
			elseif s.min >= -32768 and s.max <= 32767 then return "ByteNet.int16"
			elseif s.min >= -2147483648 and s.max <= 2147483647 then return "ByteNet.int32" end
		end
		return "ByteNet.float64"
	end
	return s.f32 and "ByteNet.float32" or "ByteNet.float64"
end

local function nodeExpr(node, ind)
	local p = string.rep("\t", ind)
	local kinds = {}
	for k in pairs(node.types) do kinds[#kinds + 1] = k end
	table.sort(kinds)
	if #kinds == 0 then return "ByteNet.unknown" end
	if #kinds > 1 then return "ByteNet.unknown --[[campuran: " .. table.concat(kinds, "|") .. "]]" end
	local k = kinds[1]
	if k == "number" then return numExpr(node)
	elseif k == "boolean" then return "ByteNet.bool"
	elseif k == "string" then return "ByteNet.string"
	elseif k == "Vector3" then return "ByteNet.vec3"
	elseif k == "Vector2" then return "ByteNet.vec2"
	elseif k == "CFrame" then return "ByteNet.cframe"
	elseif k == "Instance" then return "ByteNet.inst"
	elseif k == "buffer" then return "ByteNet.buff"
	elseif k == "array" then
		return "ByteNet.array(" .. (node.item and nodeExpr(node.item, ind) or "ByteNet.unknown") .. ")"
	elseif k == "object" then
		local lines = {}
		for _, key in ipairs(sortedKeys(node.fields or {})) do
			local f = node.fields[key]
			local e = nodeExpr(f, ind + 1)
			if f.n < (node.objN or f.n) then e = "ByteNet.optional(" .. e .. ")" end
			local ks = (key:match(IDENT) and not RESERVED[key]) and key or ("[" .. string.format("%q", key) .. "]")
			lines[#lines + 1] = p .. "\t" .. ks .. " = " .. e .. ","
		end
		if #lines == 0 then return "ByteNet.struct({})" end
		return "ByteNet.struct({\n" .. table.concat(lines, "\n") .. "\n" .. p .. "})"
	end
	return "ByteNet.unknown --[[" .. k .. "]]"
end

------------------------------------------------------------------
-- STATE & REGISTRY
------------------------------------------------------------------
local state = {
	active = false, dirty = true, listDirty = true, view = "full", selected = nil,
	filter = "", auto = true, logLines = 60, autoScan = false, t0 = nil, lastScan = 0,
}
local muted = {}
local entries, byObj, byId, byName = {}, {}, {}, {}
local Store = { feed = {}, log = {}, chat = {} }
local Raw = { reliable = { n = 0, bytes = 0 }, unreliable = { n = 0, bytes = 0 } }
local Subs = {}
local chatConn
local remoteConns = {}
local remotesFound = 0

local logCfg = {
	dir = "Semua", cat = "Semua", chan = "Semua", name = "",
	seq = 0, dropped = 0, moveT = 0, moveN = 0,
	chatKeys = { "chat", "msg", "message", "say", "talk", "whisper", "emote", "shout", "speak" },
	moveKeys = { "move", "walk", "cframe", "velocity", "jump", "teleport", "dash", "sprint", "position" },
}

local function matchAny(s, keys)
	for _, k in ipairs(keys) do
		if k ~= "" and s:find(k, 1, true) then return true end
	end
	return false
end

local function classify(name, data)
	local lname = tostring(name or ""):lower()
	if lname ~= "" then
		if matchAny(lname, logCfg.chatKeys) then return "chat" end
		if matchAny(lname, logCfg.moveKeys) then return "movement" end
	end
	local t = typeof(data)
	if t == "Vector3" or t == "Vector2" or t == "CFrame" then return "movement" end
	if t == "table" then
		local n = 0
		for k, v in next, data do
			n += 1
			if n > 20 then break end
			local lk = tostring(k):lower()
			local vt = typeof(v)
			if vt == "string" and matchAny(lk, logCfg.chatKeys) then return "chat" end
			if vt == "Vector3" or vt == "Vector2" or vt == "CFrame" then return "movement" end
		end
	end
	return "other"
end

local function extractChat(data)
	if type(data) == "string" then return nil, data end
	if type(data) ~= "table" then return nil, nil end
	local who, msg
	for k, v in next, data do
		local lk = tostring(k):lower()
		local vt = typeof(v)
		if vt == "string" then
			if lk:find("msg") or lk:find("message") or lk:find("text") or lk:find("chat") or lk:find("content") then
				msg = msg or v
			elseif lk:find("name") or lk:find("player") or lk:find("user") or lk:find("sender") or lk:find("from") then
				who = who or v
			end
		elseif vt == "Instance" and v:IsA("Player") then
			who = who or v.Name
		elseif vt == "number" and (lk:find("userid") or lk:find("player") or lk:find("sender")) then
			local p = Players:GetPlayerByUserId(v)
			who = who or (p and p.Name) or tostring(v)
		end
	end
	if not msg then
		for _, v in next, data do
			if type(v) == "string" and (not msg or #v > #msg) then msg = v end
		end
	end
	return who, msg
end

------------------------------------------------------------------
-- CHANNEL (reliable / unreliable)
------------------------------------------------------------------
local Chan = { last = nil, t = 0, fresh = false, pending = {} }

-- e.chan   : channel dari definisi packet (declared)
-- e.outR/U : OUT pasti dari hook process.client
-- e.vR/vU  : suara heuristik dari RemoteEvent (IN)
local function chanInfo(e)
	if e.chan then return e.chan, "declared" end
	local r, u = e.outR, e.outU
	if r + u > 0 then return (r >= u) and "reliable" or "unreliable", "observed" end
	r, u = e.vR, e.vU
	if r + u > 0 then return (r >= u) and "reliable" or "unreliable", "heuristic" end
	return nil, nil
end

local function chanTag(e)
	local c, src = chanInfo(e)
	if not c then return "?" end
	local t = c == "reliable" and "R" or "U"
	if src == "heuristic" then t = t .. "~" end
	return t
end

local function chanText(e)
	local c, src = chanInfo(e)
	if not c then return "tidak diketahui" end
	return c:upper() .. " (" .. src .. ")"
end

local function recordLog(e, dir, data, ch)
	local cat = classify(e.short, data)
	local now = os.clock()
	if cat == "movement" and CFG.MoveCap > 0 then
		if now - logCfg.moveT >= 1 then logCfg.moveT, logCfg.moveN = now, 0 end
		if logCfg.moveN >= CFG.MoveCap then logCfg.dropped += 1 return nil end
		logCfg.moveN += 1
	end
	logCfg.seq += 1
	local rec = {
		n = logCfg.seq, time = os.date("%H:%M:%S"), dir = dir, name = e.short, id = e.id,
		chan = ch, cat = cat, data = deepCopy(data),
	}
	local L = Store.log
	L[#L + 1] = rec
	while #L > CFG.LogMax do table.remove(L, 1) end
	if cat == "chat" then
		local who, msg = extractChat(rec.data)
		if msg then
			if not who and dir == "OUT" then who = LocalPlayer.Name end
			local C = Store.chat
			C[#C + 1] = { n = rec.n, time = rec.time, dir = dir, player = who or "?", message = msg, packet = e.short }
			while #C > CFG.LogMax do table.remove(C, 1) end
		end
	end
	return rec
end

local function connectChatService()
	if chatConn then return end
	pcall(function()
		local TCS = game:GetService("TextChatService")
		chatConn = TCS.MessageReceived:Connect(function(m)
			if not state.active then return end
			local src = m.TextSource
			local C = Store.chat
			C[#C + 1] = { n = 0, time = os.date("%H:%M:%S"), dir = "IN", player = src and src.Name or "?", message = tostring(m.Text), packet = "TextChatService" }
			while #C > CFG.LogMax do table.remove(C, 1) end
			state.dirty = true
		end)
	end)
end

local function getUps(f)
	local fn = getupvalues or (debug and debug.getupvalues)
	if not fn then return nil end
	local ok, res = pcall(fn, f)
	return (ok and type(res) == "table") and res or nil
end

local function upList(f)
	local ups = getUps(f)
	if not ups then return {} end
	local idx = {}
	for i in pairs(ups) do idx[#idx + 1] = i end
	table.sort(idx, function(a, b)
		if type(a) == "number" and type(b) == "number" then return a < b end
		return tostring(a) < tostring(b)
	end)
	local out = {}
	for _, i in ipairs(idx) do out[#out + 1] = ups[i] end
	return out
end

local function srcOf(f)
	local ok, s = pcall(function() return debug.info(f, "s") end)
	if ok and type(s) == "string" and s ~= "" then return s end
	if debug and debug.getinfo then
		local ok2, info = pcall(debug.getinfo, f)
		if ok2 and type(info) == "table" then return tostring(info.source or info.short_src or "") end
	end
	return nil
end

local function isPacketObj(t)
	if type(t) ~= "table" then return false end
	local ok, res = pcall(function()
		return type(rawget(t, "reader")) == "function"
			and type(rawget(t, "listen")) == "function"
			and type(rawget(t, "getListeners")) == "function"
	end)
	return ok and res
end

local SEND_KEYS = { "send", "sendTo", "sendToAll" }

local function findPacketId(obj)
	for _, key in ipairs(SEND_KEYS) do
		local f = rawget(obj, key)
		if type(f) == "function" then
			for _, v in ipairs(upList(f)) do
				if type(v) == "number" and v % 1 == 0 and v >= 0 and v < 65536 then return v end
			end
		end
	end
	return nil
end

-- cari string "reliable"/"unreliable" di upvalue fungsi send (definisi reliabilityType)
local function detectChannel(obj)
	for _, key in ipairs(SEND_KEYS) do
		local f = rawget(obj, key)
		if type(f) == "function" then
			for _, v in ipairs(upList(f)) do
				if type(v) == "string" then
					local l = v:lower()
					if l == "reliable" or l == "unreliable" then return l end
				end
			end
		end
	end
	return nil
end

local function resetEntry(e)
	e.schema, e.samples, e.cIn, e.cOut, e.learned = nil, {}, 0, 0, 0
	e.inR, e.inU, e.inX, e.outR, e.outU, e.outX, e.vR, e.vU = 0, 0, 0, 0, 0, 0, 0, 0
end

local function indexEntry(e)
	local short = e.name:match("([^%.]+)$") or e.name
	e.short = short
	local k = short:lower()
	if not byName[k] then byName[k] = e end
	byName[e.name:lower()] = e
	if e.id and not byId[e.id] then byId[e.id] = e end
	state.listDirty = true
end

local function makeEntry(obj, id, name)
	local e = {
		obj = obj, id = id, auto = name == nil,
		name = name or (id and ("pkt_" .. id)) or ("pkt_" .. (#entries + 1)),
	}
	resetEntry(e)
	entries[#entries + 1] = e
	if obj then byObj[obj] = e end
	indexEntry(e)
	return e
end

local function publish(e, dir, ch, data)
	for i = 1, #Subs do
		local cb = Subs[i]
		if cb then pcall(cb, e.short, dir, ch, data, e) end
	end
end

local function observe(e, dir, data, chan)
	if dir == "IN" then e.cIn += 1 else e.cOut += 1 end

	-- tentukan channel
	local ch, pending = chan, false
	if dir == "OUT" then
		ch = chan or e.chan
		if ch == "reliable" then e.outR += 1 elseif ch == "unreliable" then e.outU += 1 else e.outX += 1 end
	else
		ch = e.chan
		if not ch and Chan.fresh then
			ch = Chan.last
			if ch == "reliable" then e.vR += 1 elseif ch then e.vU += 1 end
		end
		if ch == "reliable" then e.inR += 1
		elseif ch == "unreliable" then e.inU += 1
		else e.inX += 1 pending = true end
	end

	if muted[e.short] then return end

	local rec = select(2, pcall(recordLog, e, dir, data, ch))
	if type(rec) ~= "table" then rec = nil end
	if pending and remotesFound > 0 then
		local P = Chan.pending
		P[#P + 1] = { e = e, t = os.clock(), rec = rec }
		while #P > 200 do table.remove(P, 1) end
	end

	local now = os.clock()
	e.learned += 1
	if e.learned <= CFG.LearnLimit or e.learned % 20 == 0 then
		e.schema = learn(e.schema, data)
	end
	if now - (e.lastSample or 0) >= 0.1 or #e.samples < 3 then
		e.lastSample = now
		e.samples[#e.samples + 1] = { dir = dir, chan = ch, time = os.date("%H:%M:%S"), data = deepCopy(data) }
		while #e.samples > CFG.MaxSamples do table.remove(e.samples, 1) end
	end
	if now - (e.lastFeed or 0) >= 0.15 then
		e.lastFeed = now
		local tag = ch and (ch == "reliable" and "R" or "U") or "?"
		local line = ("[%s] %-3s %s %s %s"):format(os.date("%H:%M:%S"), dir, tag, e.short, lit(data))
		if #line > 220 then line = line:sub(1, 217) .. "..." end
		local f = Store.feed
		f[#f + 1] = line
		while #f > CFG.FeedMax do table.remove(f, 1) end
	end
	publish(e, dir, ch, data)
	state.dirty = true
end

-- RemoteEvent ByteNet: dipakai untuk heuristik channel IN + statistik byte mentah
local function resolvePending(chan)
	local now = os.clock()
	local P = Chan.pending
	for i = #P, 1, -1 do
		local p = P[i]
		if now - p.t <= 0.1 then
			local e = p.e
			if e.inX > 0 then e.inX -= 1 end
			if chan == "reliable" then e.inR += 1 e.vR += 1 else e.inU += 1 e.vU += 1 end
			if p.rec and not p.rec.chan then p.rec.chan = chan end
		end
		table.remove(P, i)
	end
end

local function onRemote(chan, ...)
	if not state.active then return end
	Chan.last, Chan.t, Chan.fresh = chan, os.clock(), true
	task.defer(function() Chan.fresh = false end)
	local a = ...
	local R = Raw[chan]
	R.n += 1
	if typeof(a) == "buffer" then R.bytes += buffer.len(a) end
	resolvePending(chan)
	state.dirty = true
end

local function connectRemotes()
	if #remoteConns > 0 then return #remoteConns end
	local okD, desc = pcall(function() return ReplicatedStorage:GetDescendants() end)
	if not okD then return 0 end
	for _, inst in ipairs(desc) do
		local isRemote = inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent")
		if isRemote then
			local lname = inst.Name:lower()
			local inBN = lname:find("bytenet", 1, true) or inst:FindFirstAncestor("ByteNet") ~= nil
			if inBN then
				local chan = (inst:IsA("UnreliableRemoteEvent") or lname:find("unreliable", 1, true)) and "unreliable" or "reliable"
				local ok, c = pcall(function()
					return inst.OnClientEvent:Connect(function(...) onRemote(chan, ...) end)
				end)
				if ok and c then remoteConns[#remoteConns + 1] = c end
			end
		end
	end
	remotesFound = #remoteConns
	return remotesFound
end

local function disconnectRemotes()
	for _, c in ipairs(remoteConns) do pcall(function() c:Disconnect() end) end
	table.clear(remoteConns)
	remotesFound = 0
	table.clear(Chan.pending)
end

local function attach(e)
	if e.attached or not e.listeners then return end
	e.master = function(data) pcall(observe, e, "IN", data) end
	table.insert(e.listeners, e.master)
	e.attached = true
end

local function detach(e)
	if e.attached and e.listeners and e.master then
		local i = table.find(e.listeners, e.master)
		if i then table.remove(e.listeners, i) end
	end
	e.attached = false
	if e.origSend and e.obj then
		pcall(rawset, e.obj, "send", e.origSend)
		e.origSend = nil
	end
end

local function register(obj, name)
	local e = byObj[obj]
	if e then
		if name and e.auto then e.name, e.auto = name, false indexEntry(e) end
		return e
	end
	local id = findPacketId(obj)
	local existing = id and byId[id]
	if existing and not existing.obj then
		-- placeholder dari hook OUT (id_N) digabung dengan objek asli
		e = existing
		e.obj = obj
		byObj[obj] = e
		if name then e.name, e.auto = name, false indexEntry(e) end
		e.declTried = nil
	else
		e = makeEntry(obj, id, name)
	end
	e.chan = e.chan or detectChannel(obj)
	local okL, ls = pcall(function() return rawget(obj, "getListeners")() end)
	if okL and type(ls) == "table" then e.listeners = ls end
	if state.active then attach(e) end
	state.listDirty = true
	return e
end

local function scanPackets()
	local before = #entries
	if getloadedmodules then
		local okM, mods = pcall(getloadedmodules)
		if okM and type(mods) == "table" then
			local visited = {}
			local function walk(t, prefix, depth)
				if visited[t] or depth > 4 then return end
				visited[t] = true
				pcall(function()
					local n = 0
					for k, v in next, t do
						n += 1
						if n > 400 then break end
						if type(v) == "table" then
							if isPacketObj(v) then register(v, prefix .. tostring(k))
							else walk(v, prefix .. tostring(k) .. ".", depth + 1) end
						end
					end
				end)
			end
			for i, m in ipairs(mods) do
				if typeof(m) == "Instance" and m:IsA("ModuleScript") then
					local okR, res = pcall(require, m)
					if okR and type(res) == "table" then
						if isPacketObj(res) then register(res, m.Name) else walk(res, "", 1) end
					end
				end
				if i % 40 == 0 then task.wait() end
			end
		end
	end
	if getgc then
		local okG, gc = pcall(getgc, true)
		if okG and type(gc) == "table" then
			for i = 1, #gc do
				local v = gc[i]
				if type(v) == "table" and not byObj[v] and isPacketObj(v) then register(v, nil) end
				if i % 4000 == 0 then task.wait() end
			end
		end
	end
	return #entries - before
end

-- Hook OUT: process.client.sendReliable / sendUnreliable (id, writer, data)
local function onOut(id, chan, data)
	if not state.active then return end
	local e = byId[id]
	if not e then
		e = makeEntry(nil, id, "id_" .. tostring(id))
		e.auto = true
		byId[id] = e
	end
	observe(e, "OUT", data, chan)
end

local function installClientHook()
	if not hookfunction then return false, "hookfunction tidak tersedia" end
	local genv = getgenv and getgenv() or nil
	if genv then genv.__SS_out = onOut end
	if genv and genv.__SS_hooked then return true end
	local bn = ReplicatedStorage:FindFirstChild("ByteNet")
	local proc = bn and bn:FindFirstChild("process")
	local m = proc and proc:FindFirstChild("client")
	if not m then return false, "ReplicatedStorage.ByteNet.process.client tidak ditemukan" end
	local okR, client = pcall(require, m)
	if not okR or type(client) ~= "table" then return false, "require process.client gagal" end
	local hooked = 0
	for _, fname in ipairs({ "sendReliable", "sendUnreliable" }) do
		local f = rawget(client, fname)
		if type(f) == "function" then
			local chan = fname == "sendReliable" and "reliable" or "unreliable"
			local orig
			local ok = pcall(function()
				orig = hookfunction(f, function(id, writer, data, ...)
					local cb = getgenv and getgenv().__SS_out
					if cb then pcall(cb, id, chan, data) end
					return orig(id, writer, data, ...)
				end)
			end)
			if ok and orig then hooked += 1 end
		end
	end
	if hooked > 0 and genv then genv.__SS_hooked = true end
	return hooked > 0, hooked == 0 and "hook gagal (fungsi send tidak ditemukan)" or nil
end

local function wrapSendFallback(e)
	if e.origSend or not e.obj then return end
	local orig = rawget(e.obj, "send")
	if type(orig) ~= "function" then return end
	e.origSend = orig
	local ok = pcall(rawset, e.obj, "send", function(data, ...)
		if state.active then pcall(observe, e, "OUT", data, e.chan) end
		return orig(data, ...)
	end)
	if not ok then e.origSend = nil end
end

------------------------------------------------------------------
-- INTROSPEKSI DEFINISI BYTENET (DECLARED)
------------------------------------------------------------------
local function isDT(t)
	if type(t) ~= "table" then return false end
	local ok, res = pcall(function()
		return type(rawget(t, "read")) == "function" and type(rawget(t, "write")) == "function"
	end)
	return ok and res
end

local function dtName(dt)
	for _, k in ipairs({ "read", "write" }) do
		local f = rawget(dt, k)
		if type(f) == "function" then
			local s = srcOf(f)
			local n = s and s:match("dataTypes[%./\\]([%w_]+)")
			if n then return n end
		end
	end
	return nil
end

local function dtUps(dt)
	local f = rawget(dt, "read")
	if type(f) ~= "function" then f = rawget(dt, "write") end
	if type(f) ~= "function" then return {} end
	return upList(f)
end

local function describeDT(dt, depth, stack)
	depth = depth or 0
	stack = stack or {}
	local node = { kind = dtName(dt) or "?" }
	if depth > 10 or stack[dt] then node.cyclic = true return node end
	stack[dt] = true
	local k = node.kind
	if k == "struct" then
		for _, up in ipairs(dtUps(dt)) do
			if type(up) == "table" and not isDT(up) then
				local fields, count = {}, 0
				for fk, fv in pairs(up) do
					if type(fk) == "string" and isDT(fv) then
						fields[fk] = describeDT(fv, depth + 1, stack)
						count += 1
					end
				end
				if count > 0 then node.fields = fields break end
			end
		end
	elseif k == "array" or k == "optional" then
		local found = {}
		for _, up in ipairs(dtUps(dt)) do if isDT(up) then found[#found + 1] = up end end
		if found[1] then node.inner = describeDT(found[1], depth + 1, stack) end
		if #found > 1 then node.extra = #found - 1 end
	elseif k == "map" then
		local found = {}
		for _, up in ipairs(dtUps(dt)) do if isDT(up) then found[#found + 1] = up end end
		if found[1] then node.key = describeDT(found[1], depth + 1, stack) end
		if found[2] then node.value = describeDT(found[2], depth + 1, stack) end
	end
	stack[dt] = nil
	return node
end

local function declExpr(node, ind)
	local p = string.rep("\t", ind)
	local k = node.kind
	if node.cyclic then return "ByteNet.unknown --[[siklik]]" end
	if k == "struct" then
		if not node.fields then return "ByteNet.struct({ --[[field tidak terbaca dari upvalue]] })" end
		local lines = {}
		for _, key in ipairs(sortedKeys(node.fields)) do
			local ks = (key:match(IDENT) and not RESERVED[key]) and key or ("[" .. string.format("%q", key) .. "]")
			lines[#lines + 1] = p .. "\t" .. ks .. " = " .. declExpr(node.fields[key], ind + 1) .. ","
		end
		return "ByteNet.struct({\n" .. table.concat(lines, "\n") .. "\n" .. p .. "})"
	elseif k == "array" or k == "optional" then
		return ("ByteNet.%s(%s)"):format(k, node.inner and declExpr(node.inner, ind) or "?")
	elseif k == "map" then
		return ("ByteNet.map(%s, %s)"):format(node.key and declExpr(node.key, ind) or "?", node.value and declExpr(node.value, ind) or "?")
	elseif k == "?" then
		return "?"
	end
	return "ByteNet." .. k
end

local function introspect(e)
	if e.declTried then return e.declared end
	e.declTried = true
	e.declared = false
	local obj = e.obj
	if not obj then return false end
	local cands = {}

	for _, key in ipairs({ "reader", "writer" }) do
		local f = rawget(obj, key)
		if type(f) == "function" then
			local s = srcOf(f)
			if s and s:find("dataTypes", 1, true) then cands[#cands + 1] = { read = f, write = f } end
		end
	end
	if #cands == 0 then
		for _, f in next, obj do
			if type(f) == "function" then
				for _, up in ipairs(upList(f)) do
					if isDT(up) then cands[#cands + 1] = up end
				end
			end
		end
	end
	if #cands == 0 then
		for _, f in next, obj do
			if type(f) == "function" then
				for _, up in ipairs(upList(f)) do
					if type(up) == "function" then
						for _, up2 in ipairs(upList(up)) do
							if isDT(up2) then cands[#cands + 1] = up2 end
						end
					end
				end
			end
		end
	end

	for _, dt in ipairs(cands) do
		local ok, node = pcall(describeDT, dt)
		if ok and node and node.kind ~= "?" then
			e.declared = node
			break
		end
	end
	return e.declared
end

------------------------------------------------------------------
-- LAPORAN
------------------------------------------------------------------
local function sortedEntries()
	local list = table.clone(entries)
	table.sort(list, function(a, b)
		local ia, ib = a.id or 1e9, b.id or 1e9
		if ia ~= ib then return ia < ib end
		return (a.short or "") < (b.short or "")
	end)
	return list
end

local function headerOf(e)
	return ("%s  (id %s)"):format(e.short, tostring(e.id or "?"))
end

local function relLine(e)
	local c, src = chanInfo(e)
	if not c then return "" end
	return ("\n\treliabilityType = %q,%s"):format(c, src ~= "declared" and (" -- " .. src) or "")
end

local function declaredText(e)
	local d = introspect(e)
	if not d then
		return "(tidak terbaca: executor tanpa debug.info/getupvalues, atau struktur modul ByteNet berbeda)\nGunakan bagian OBSERVED di bawah."
	end
	return ("ByteNet.definePacket({\n\tvalue = %s,%s\n})"):format(declExpr(d, 1), relLine(e))
end

local function observedText(e)
	if not e.schema then
		return "(belum ada data. Aktifkan Rekam Packet lalu lakukan aksinya di game)"
	end
	local rows = {}
	flatten(e.schema, "", rows, false)
	local w = 5
	for _, r in ipairs(rows) do w = math.max(w, #r.path) end
	w = math.min(w, 42)
	local out = { pad("FIELD", w) .. "  " .. pad("TIPE", 12) .. "  " .. pad("WAJIB", 8) .. "  DETAIL" }
	out[#out + 1] = string.rep("-", w + 40)
	for _, r in ipairs(rows) do
		out[#out + 1] = ("%s  %s  %s  %s"):format(pad(r.path, w), pad(typeLabel(r.node), 12), pad(r.opt and "opsional" or "ya", 8), detail(r.node))
	end
	out[#out + 1] = ("(dipelajari dari %d data)"):format(e.schema.n)
	return table.concat(out, "\n")
end

local function guessText(e)
	if not e.schema then return "(belum ada data)" end
	return ("-- TEBAKAN minimal dari data nyata (tipe bisa lebih besar di definisi asli)\nByteNet.definePacket({\n\tvalue = %s,%s\n})"):format(nodeExpr(e.schema, 1), relLine(e))
end

local function lastSampleText(e)
	local s = e.samples[#e.samples]
	if not s then return "(belum ada sampel)" end
	local out = { ("Sampel terakhir [%s/%s] %s"):format(s.dir, s.chan or "?", s.time) }
	tree(s.data, "data", 0, out, 0)
	out[#out + 1] = ""
	out[#out + 1] = "-- sebagai Lua:"
	out[#out + 1] = luaSrc(s.data, 0, 0, {})
	return table.concat(out, "\n")
end

local function samplesText(e)
	if #e.samples == 0 then return "(belum ada sampel)" end
	local list = {}
	for i, s in ipairs(e.samples) do list[i] = { dir = s.dir, chan = s.chan, time = s.time, data = s.data } end
	return ("-- %s : %d sampel terakhir\nreturn %s"):format(headerOf(e), #list, luaSrc(list, 0, 0, {}))
end

local function countsLine(e)
	return ("IN: R %d / U %d / ? %d | OUT: R %d / U %d / ? %d"):format(e.inR, e.inU, e.inX, e.outR, e.outU, e.outX)
end

local function packetReport(e)
	local o = {}
	o[#o + 1] = "=================================================="
	o[#o + 1] = "PACKET " .. headerOf(e)
	o[#o + 1] = ("Nama lengkap: %s | sampel: %d"):format(e.name, #e.samples)
	o[#o + 1] = ("Channel: %s | %s"):format(chanText(e), countsLine(e))
	if e.chan and (e.outR + e.outU) > 0 then
		local obs = e.outR >= e.outU and "reliable" or "unreliable"
		if obs ~= e.chan then o[#o + 1] = "PERINGATAN: channel declared (" .. e.chan .. ") berbeda dengan OUT teramati (" .. obs .. ")" end
	end
	o[#o + 1] = "=================================================="
	o[#o + 1] = ""
	o[#o + 1] = "[DECLARED] dibaca dari definisi ByteNet"
	o[#o + 1] = declaredText(e)
	o[#o + 1] = ""
	o[#o + 1] = "[OBSERVED] dipelajari dari data nyata"
	o[#o + 1] = observedText(e)
	o[#o + 1] = ""
	o[#o + 1] = "[TEBAKAN]"
	o[#o + 1] = guessText(e)
	o[#o + 1] = ""
	o[#o + 1] = "[SAMPEL TERAKHIR]"
	o[#o + 1] = lastSampleText(e)
	return table.concat(o, "\n") .. "\n"
end

local function structSummary(e)
	local d = introspect(e)
	local desc = "?"
	if d then
		desc = d.kind
		if d.fields then
			local ks = sortedKeys(d.fields)
			local names = {}
			for i, k in ipairs(ks) do
				if i > 6 then names[#names + 1] = "..." break end
				names[#names + 1] = k .. ":" .. d.fields[k].kind
			end
			desc = "struct{" .. table.concat(names, ", ") .. "}"
		elseif d.inner then
			desc = d.kind .. "<" .. d.inner.kind .. ">"
		end
	elseif e.schema then
		desc = "(observed) " .. typeLabel(e.schema)
	end
	return desc
end

local function summaryText()
	local list = sortedEntries()
	if #list == 0 then return "(belum ada packet. Klik Scan atau aktifkan Rekam Packet)" end
	local out = {
		("%s  %s  %s  %s  %s  %s"):format(pad("ID", 5), pad("NAMA", 22), pad("CH", 3), pad("IN", 6), pad("OUT", 6), "STRUCT (declared)"),
		string.rep("-", 84),
		"CH: R=reliable U=unreliable ~=heuristik ?=belum diketahui",
	}
	for _, e in ipairs(list) do
		out[#out + 1] = ("%s  %s  %s  %s  %s  %s"):format(pad(e.id or "?", 5), pad(e.short, 22), pad(chanTag(e), 3), pad(e.cIn, 6), pad(e.cOut, 6), structSummary(e))
	end
	return table.concat(out, "\n")
end

local function sumCounts()
	local s = { inR = 0, inU = 0, inX = 0, outR = 0, outU = 0, outX = 0 }
	for _, e in ipairs(entries) do
		for k in pairs(s) do s[k] += e[k] end
	end
	return s
end

local function channelStatsText()
	local s = sumCounts()
	local el = state.t0 and math.max(os.clock() - state.t0, 0.001) or nil
	local nR, nU, nX = 0, 0, 0
	for _, e in ipairs(entries) do
		local c = chanInfo(e)
		if c == "reliable" then nR += 1 elseif c == "unreliable" then nU += 1 else nX += 1 end
	end
	local o = {
		"STATISTIK CHANNEL",
		string.rep("-", 60),
		("Packet terdaftar : %d  (reliable %d | unreliable %d | belum diketahui %d)"):format(#entries, nR, nU, nX),
		("IN  reliable     : %d"):format(s.inR),
		("IN  unreliable   : %d"):format(s.inU),
		("IN  belum jelas  : %d"):format(s.inX),
		("OUT reliable     : %d"):format(s.outR),
		("OUT unreliable   : %d"):format(s.outU),
		("OUT belum jelas  : %d"):format(s.outX),
		"",
		("RemoteEvent ByteNet terhubung: %d"):format(remotesFound),
		("Raw IN reliable   : %d event, %d byte"):format(Raw.reliable.n, Raw.reliable.bytes),
		("Raw IN unreliable : %d event, %d byte"):format(Raw.unreliable.n, Raw.unreliable.bytes),
	}
	if el then
		o[#o + 1] = ("Durasi rekam      : %.1f detik"):format(el)
		o[#o + 1] = ("Rata-rata IN/OUT  : %.1f / %.1f packet per detik"):format((s.inR + s.inU + s.inX) / el, (s.outR + s.outU + s.outX) / el)
		o[#o + 1] = ("Raw byte IN/detik : reliable %.0f | unreliable %.0f"):format(Raw.reliable.bytes / el, Raw.unreliable.bytes / el)
	end
	o[#o + 1] = ""
	o[#o + 1] = "TOP PACKET (paling ramai)"
	o[#o + 1] = ("%s  %s  %s  %s  %s"):format(pad("NAMA", 22), pad("CH", 3), pad("IN", 7), pad("OUT", 7), "PER DETIK")
	local list = table.clone(entries)
	table.sort(list, function(a, b) return (a.cIn + a.cOut) > (b.cIn + b.cOut) end)
	for i = 1, math.min(15, #list) do
		local e = list[i]
		if e.cIn + e.cOut == 0 then break end
		o[#o + 1] = ("%s  %s  %s  %s  %s"):format(pad(e.short, 22), pad(chanTag(e), 3), pad(e.cIn, 7), pad(e.cOut, 7), el and ("%.1f"):format((e.cIn + e.cOut) / el) or "-")
	end
	return table.concat(o, "\n")
end

local function feedText()
	if #Store.feed == 0 then return "(belum ada packet. Aktifkan Rekam Packet)" end
	return table.concat(Store.feed, "\n")
end

local function allReport()
	local out = {
		"# StructScope - laporan semua packet",
		("PlaceId: %s | dibuat: %s | packet: %d\n"):format(tostring(game.PlaceId), os.date("%Y-%m-%d %H:%M:%S"), #entries),
		summaryText(),
		"",
		channelStatsText(),
		"",
	}
	for _, e in ipairs(sortedEntries()) do out[#out + 1] = packetReport(e) end
	return table.concat(out, "\n")
end

local function logPasses(r)
	if logCfg.dir ~= "Semua" and r.dir ~= logCfg.dir then return false end
	if logCfg.cat ~= "Semua" and r.cat ~= logCfg.cat then return false end
	if logCfg.chan ~= "Semua" and (r.chan or "?") ~= logCfg.chan then return false end
	if logCfg.name ~= "" then
		if not (tostring(r.name):lower():find(logCfg.name, 1, true) or tostring(r.id):find(logCfg.name, 1, true)) then return false end
	end
	return true
end

local function filteredLog()
	local out = {}
	for _, r in ipairs(Store.log) do
		if logPasses(r) then out[#out + 1] = r end
	end
	return out
end

local function clipLine(s, n)
	if #s > n then return s:sub(1, n - 3) .. "..." end
	return s
end

local function logText()
	local list = filteredLog()
	if #list == 0 then return "(belum ada log yang cocok filter. Aktifkan Rekam Packet lalu lakukan aksi di game)" end
	local out = { ("Log packet: %d entri cocok filter (total %d) | movement dilewati: %d"):format(#list, #Store.log, logCfg.dropped), "" }
	for i = math.max(1, #list - state.logLines + 1), #list do
		local r = list[i]
		local tag = r.chan and (r.chan == "reliable" and "R" or "U") or "?"
		out[#out + 1] = clipLine(("#%d %s %-3s %s [%s] %s(%s) %s"):format(r.n, r.time, r.dir, tag, r.cat, r.name, tostring(r.id or "?"), lit(r.data)), 200)
	end
	return table.concat(out, "\n")
end

local function chatText()
	local C = Store.chat
	if #C == 0 then return "(belum ada chat terdeteksi. Kirim / terima chat di game dengan Rekam Packet aktif)" end
	local out = { ("Chat log: %d pesan"):format(#C), "" }
	for i = math.max(1, #C - state.logLines + 1), #C do
		local c = C[i]
		out[#out + 1] = clipLine(("[%s] %-3s %s: %s  <%s>"):format(c.time, c.dir, tostring(c.player), tostring(c.message), c.packet), 180)
	end
	return table.concat(out, "\n")
end

local function logToLua(list, title)
	local plain = {}
	for i, r in ipairs(list) do
		plain[i] = { n = r.n, time = r.time, dir = r.dir, name = r.name, id = r.id, chan = r.chan, cat = r.cat, data = r.data }
	end
	return ("-- %s\n-- Dibuat: %s | Entri: %d | PlaceId: %s\nreturn %s\n"):format(
		title, os.date("%Y-%m-%d %H:%M:%S"), #plain, tostring(game.PlaceId), luaSrc(plain, 0, 0, {}))
end

local function chatToLua()
	return ("-- Chat log\n-- Dibuat: %s | Entri: %d | PlaceId: %s\nreturn %s\n"):format(
		os.date("%Y-%m-%d %H:%M:%S"), #Store.chat, tostring(game.PlaceId), luaSrc(Store.chat, 0, 0, {}))
end

local function registryLua()
	local list = {}
	for _, e in ipairs(sortedEntries()) do
		local d = introspect(e)
		local c, src = chanInfo(e)
		list[#list + 1] = {
			id = e.id, name = e.short, fullName = e.name, channel = c, channelSource = src,
			countIn = e.cIn, countOut = e.cOut,
			declared = d and declExpr(d, 0) or nil,
			observed = e.schema and typeLabel(e.schema) or nil,
		}
	end
	return ("-- Tabel packet\n-- Dibuat: %s | Packet: %d | PlaceId: %s\nreturn %s\n"):format(
		os.date("%Y-%m-%d %H:%M:%S"), #list, tostring(game.PlaceId), luaSrc(list, 0, 0, {}))
end

------------------------------------------------------------------
-- FRAMEWORK GENERATOR (modul, dokumentasi, template)
------------------------------------------------------------------
local function valueExpr(e, ind)
	local d = introspect(e)
	if d then return declExpr(d, ind), "declared" end
	if e.schema then return nodeExpr(e.schema, ind), "observed" end
	return "ByteNet.unknown", "unknown"
end

local function frameworkModule()
	local list = sortedEntries()
	local o = {
		("-- Packets.lua  (dibuat StructScope v%s)"):format(VERSION),
		("-- PlaceId: %s | dibuat: %s | packet: %d"):format(tostring(game.PlaceId), os.date("%Y-%m-%d %H:%M:%S"), #list),
		"-- Struct 'observed' hanya sebesar data yang pernah muncul. Periksa lagi sebelum dipakai.",
		"-- reliabilityType: reliable = RemoteEvent (terurut, pasti sampai), unreliable = UnreliableRemoteEvent.",
		"",
		"local ByteNet = require(game:GetService(\"ReplicatedStorage\"):WaitForChild(\"ByteNet\")) -- sesuaikan path",
		"",
		"return ByteNet.defineNamespace(\"app\", function()",
		"\treturn {",
		"\t\tpackets = {",
	}
	local used = {}
	for _, e in ipairs(list) do
		local key = identOf(e.short)
		if used[key] then key = key .. "_" .. tostring(e.id or #used) end
		used[key] = true
		local expr, src = valueExpr(e, 4)
		local c, csrc = chanInfo(e)
		o[#o + 1] = ("\t\t\t-- id %s | struct: %s | channel: %s"):format(tostring(e.id or "?"), src, c and (c .. " (" .. csrc .. ")") or "tidak diketahui")
		o[#o + 1] = ("\t\t\t%s = ByteNet.definePacket({"):format(key)
		o[#o + 1] = ("\t\t\t\tvalue = %s,"):format(expr)
		if c then o[#o + 1] = ("\t\t\t\treliabilityType = %q,"):format(c) end
		o[#o + 1] = "\t\t\t}),"
	end
	o[#o + 1] = "\t\t},"
	o[#o + 1] = "\t}"
	o[#o + 1] = "end)"
	return table.concat(o, "\n") .. "\n"
end

local function templateText(e)
	local c, src = chanInfo(e)
	local s = e.samples[#e.samples]
	local o = {
		("-- Template script: packet %s (id %s)"):format(e.short, tostring(e.id or "?")),
		("-- Channel: %s"):format(c and (c:upper() .. " (" .. src .. ")") or "tidak diketahui"),
		"",
		"local SS = getgenv().StructScope -- jalankan StructScope dulu",
		("local packet = SS.Packets.get(%q) -- objek ByteNet asli (listen / send)"):format(e.short),
		"",
		"-- 1) Pantau pasif lewat StructScope (IN dan OUT, tanpa mengubah apa pun)",
		"local unsubscribe = SS.Subscribe(function(name, dir, chan, data)",
		("\tif name ~= %q then return end"):format(e.short),
		"\tprint(dir, chan, data)",
		"end)",
		"-- unsubscribe() untuk berhenti",
		"",
		"-- 2) Listener langsung ke packet (IN dari server)",
		"if packet then",
		"\tpacket.listen(function(data)",
		"\t\tprint(\"diterima\", data)",
		"\tend)",
		"end",
		"",
		"-- 3) Mengirim ke server (AKTIF, bukan bagian debugger). Struct dari sampel terakhir:",
	}
	if s then
		local src2 = luaSrc(s.data, 0, 0, {})
		o[#o + 1] = "local sample = " .. src2
		o[#o + 1] = "-- packet.send(sample)"
	else
		o[#o + 1] = "-- (belum ada sampel; rekam dulu)"
		o[#o + 1] = "-- packet.send({ ... })"
	end
	o[#o + 1] = ""
	o[#o + 1] = "-- Struct:"
	local decl = declaredText(e)
	for line in (decl .. "\n"):gmatch("(.-)\n") do o[#o + 1] = "-- " .. line end
	return table.concat(o, "\n") .. "\n"
end

local DOC_INTRO = [==[
## Konsep ByteNet singkat

- **Packet** = definisi pesan dengan `id` unik, struct data, dan channel.
- **reliable** (default): lewat RemoteEvent. Urutan terjamin dan pasti sampai.
- **unreliable**: lewat UnreliableRemoteEvent. Bisa hilang atau tidak berurutan, ukuran dibatasi. Cocok untuk data sering seperti posisi.
- Arah **IN** = server ke client (listener). Arah **OUT** = client ke server (send).
- Data yang dilihat debugger adalah hasil decode (table), bukan buffer mentah.

## Cara mengambil data dari StructScope untuk script baru

```lua
local SS = getgenv().StructScope            -- StructScope harus sudah jalan

local packet = SS.Packets.get("NamaPacket") -- objek ByteNet asli
local info   = SS.Packets.info("NamaPacket")-- id, channel, struct, schema, counts

-- pantau semua packet (pasif)
local off = SS.Subscribe(function(name, dir, chan, data)
	print(name, dir, chan, data)
end)
```

## Alur kerja membuat script baru

1. Nyalakan **Rekam Packet**, lakukan aksi di game.
2. Lihat struct di tab **Viewer** (Declared lebih akurat dari Observed).
3. Pakai tab **Framework**: salin `Packets.lua`, template per packet, atau dokumentasi ini.
4. Tulis script baru memakai `SS.Packets.get(...)` dan `SS.Subscribe(...)`.
5. Cek kolom channel sebelum menulis ulang definisi: reliable dan unreliable tidak bisa dipertukarkan.

## Arti tanda channel

| Tanda | Arti |
| --- | --- |
| R / U | reliable / unreliable, pasti (declared atau OUT teramati) |
| R~ / U~ | tebakan dari RemoteEvent yang memicu packet |
| ? | belum diketahui |
]==]

local function mdEscape(s) return (tostring(s):gsub("|", "\\|")) end

local function docsMarkdown()
	local list = sortedEntries()
	local o = {
		"# Dokumentasi Packet ByteNet",
		"",
		("- PlaceId: `%s`"):format(tostring(game.PlaceId)),
		("- Dibuat: %s"):format(os.date("%Y-%m-%d %H:%M:%S")),
		("- Jumlah packet: %d"):format(#list),
		("- Dibuat oleh: StructScope v%s"):format(VERSION),
		"",
		"## Ringkasan packet",
		"",
		"| ID | Nama | Channel | Arah | IN | OUT | Struct |",
		"| --- | --- | --- | --- | --- | --- | --- |",
	}
	for _, e in ipairs(list) do
		local dirs = (e.cIn > 0 and e.cOut > 0) and "IN/OUT" or (e.cIn > 0 and "IN" or (e.cOut > 0 and "OUT" or "-"))
		local c = chanInfo(e)
		o[#o + 1] = ("| %s | `%s` | %s | %s | %d | %d | %s |"):format(
			tostring(e.id or "?"), e.short, c or "?", dirs, e.cIn, e.cOut, mdEscape(structSummary(e)))
	end
	o[#o + 1] = ""
	o[#o + 1] = DOC_INTRO
	o[#o + 1] = ""
	o[#o + 1] = "## Detail packet"
	for _, e in ipairs(list) do
		o[#o + 1] = ""
		o[#o + 1] = ("### %s (id %s)"):format(e.short, tostring(e.id or "?"))
		o[#o + 1] = ""
		o[#o + 1] = ("- Nama lengkap: `%s`"):format(e.name)
		o[#o + 1] = ("- Channel: **%s**"):format(chanText(e))
		o[#o + 1] = ("- %s"):format(countsLine(e))
		o[#o + 1] = ""
		o[#o + 1] = "**Declared**"
		o[#o + 1] = ""
		o[#o + 1] = "```lua"
		o[#o + 1] = declaredText(e)
		o[#o + 1] = "```"
		if e.schema then
			local rows = {}
			flatten(e.schema, "", rows, false)
			o[#o + 1] = ""
			o[#o + 1] = ("**Observed** (dari %d data)"):format(e.schema.n)
			o[#o + 1] = ""
			o[#o + 1] = "| Field | Tipe | Wajib | Detail |"
			o[#o + 1] = "| --- | --- | --- | --- |"
			for _, r in ipairs(rows) do
				o[#o + 1] = ("| `%s` | %s | %s | %s |"):format(mdEscape(r.path), mdEscape(typeLabel(r.node)), r.opt and "opsional" or "ya", mdEscape(detail(r.node)))
			end
		end
		local s = e.samples[#e.samples]
		if s then
			o[#o + 1] = ""
			o[#o + 1] = ("**Contoh data** (%s, %s)"):format(s.dir, s.chan or "?")
			o[#o + 1] = ""
			o[#o + 1] = "```lua"
			o[#o + 1] = "return " .. luaSrc(s.data, 0, 0, {})
			o[#o + 1] = "```"
		end
	end
	return table.concat(o, "\n") .. "\n"
end

------------------------------------------------------------------
-- RENDER (pilihan tampilan viewer)
------------------------------------------------------------------
local MODES = {
	{ key = "full",      label = "Struct lengkap",              needsPacket = true },
	{ key = "declared",  label = "Declared (definisi ByteNet)", needsPacket = true },
	{ key = "observed",  label = "Observed (tabel field)",      needsPacket = true },
	{ key = "sample",    label = "Sample terakhir (tree)",      needsPacket = true },
	{ key = "samples",   label = "Semua sampel (Lua table)",    needsPacket = true },
	{ key = "template",  label = "Template script (terpilih)",  needsPacket = true },
	{ key = "registry",  label = "Tabel packet (semua)" },
	{ key = "stats",     label = "Statistik channel (R/U)" },
	{ key = "log",       label = "Log packet (sesuai filter)" },
	{ key = "chat",      label = "Chat log" },
	{ key = "feed",      label = "Live feed ringkas" },
	{ key = "report",    label = "Laporan SEMUA packet" },
	{ key = "framework", label = "Modul Packets.lua (framework)" },
	{ key = "docs",      label = "Dokumentasi Markdown" },
}
local MODE_LABELS, MODE_BY_LABEL, MODE_BY_KEY = {}, {}, {}
for i, m in ipairs(MODES) do
	MODE_LABELS[i] = m.label
	MODE_BY_LABEL[m.label] = m
	MODE_BY_KEY[m.key] = m
end

local function render()
	local m, e = MODE_BY_KEY[state.view] or MODES[1], state.selected
	if m.needsPacket and not e then return "(pilih packet dulu di dropdown)", "-" end
	local k = m.key
	if k == "full" then return packetReport(e), headerOf(e)
	elseif k == "declared" then return declaredText(e), "Declared - " .. headerOf(e)
	elseif k == "observed" then return observedText(e) .. "\n\n" .. guessText(e), "Observed - " .. headerOf(e)
	elseif k == "sample" then return lastSampleText(e), "Sample - " .. headerOf(e)
	elseif k == "samples" then return samplesText(e), "Sampel - " .. headerOf(e)
	elseif k == "template" then return templateText(e), "Template - " .. headerOf(e)
	elseif k == "registry" then return summaryText(), "Tabel packet"
	elseif k == "stats" then return channelStatsText(), "Statistik channel"
	elseif k == "log" then return logText(), "Log packet"
	elseif k == "chat" then return chatText(), "Chat log"
	elseif k == "feed" then return feedText(), "Live feed"
	elseif k == "framework" then return frameworkModule(), "Packets.lua"
	elseif k == "docs" then return docsMarkdown(), "Dokumentasi"
	end
	return allReport(), "Laporan semua packet"
end

------------------------------------------------------------------
-- VIEWER (state; UI dibuat di dalam menu Linoria)
------------------------------------------------------------------
local Viewer = { full = "", title = "" }

function Viewer.set(text, ttl)
	text = CFG.Ascii and ascii(text) or text
	ttl = CFG.Ascii and ascii(ttl or "") or (ttl or "")
	Viewer.full, Viewer.title = text, ttl
	if Viewer.titleLabel then
		pcall(function() Viewer.titleLabel:SetText("Tampil: " .. ttl) end)
	end
	if Viewer.box then
		if #text > CFG.TextLimit then
			Viewer.box.Text = text:sub(1, CFG.TextLimit) .. ("\n\n... [dipotong, total %d karakter. Pakai Copy / Save untuk teks penuh]"):format(#text)
		else
			Viewer.box.Text = text
		end
	end
end

function Viewer.isOpen()
	if Library.Toggled == false then return false end
	if state.minimized then return false end
	local ok, vis = pcall(function() return Viewer.tab.Container.Visible end)
	if ok and type(vis) == "boolean" then return vis end
	return true
end

function Viewer.show()
	if Viewer.tab then pcall(function() Viewer.tab:ShowTab() end) end
end

function Viewer.applyTheme(t)
	if not Viewer.holder then return end
	Viewer.holder.BackgroundColor3 = t.Outline
	Viewer.scroll.BackgroundColor3 = t.View
	Viewer.box.TextColor3 = t.Font
end

------------------------------------------------------------------
-- EXPORT
------------------------------------------------------------------
local function ensureDir(dir)
	pcall(function()
		if makefolder and not (isfolder and isfolder(dir)) then makefolder(dir) end
	end)
end

local function writeOut(prefix, text, ext, subdir)
	ext = ext or "txt"
	if not writefile then return nil, "writefile tidak didukung executor" end
	local dir = "StructScope"
	ensureDir(dir)
	if subdir then
		dir = dir .. "/" .. subdir
		ensureDir(dir)
	end
	local path = ("%s/%s_%d.%s"):format(dir, prefix, os.time(), ext)
	if subdir then path = ("%s/%s.%s"):format(dir, prefix, ext) end
	if not pcall(writefile, path, text) then
		path = ("%s_%d.%s"):format(prefix, os.time(), ext)
		if not pcall(writefile, path, text) then return nil, "gagal menulis file" end
	end
	return path
end

local function safeName(s)
	return (ascii(s ~= "" and s or "view"):gsub("[^%w_%-]", "_"))
end

local function currentText()
	local text, title = render()
	return CFG.Ascii and ascii(text) or text, title
end

local function showView()
	local text, title = render()
	Viewer.set(text, title)
	Viewer.show()
	state.dirty = false
end

------------------------------------------------------------------
-- START / STOP
------------------------------------------------------------------
local labelMap = {}
local ddPacket, ddMute, statusLabel, statLabel, modeDD

local function labelOf(e) return ("%s (id %s)"):format(e.short, tostring(e.id or "?")) end

local function refreshLists()
	state.listDirty = false
	labelMap = {}
	local labels, names, seenName = {}, {}, {}
	for _, e in ipairs(sortedEntries()) do
		local lab = labelOf(e)
		if labelMap[lab] then lab = lab .. " #" .. (#labels + 1) end
		if state.filter == "" or lab:lower():find(state.filter, 1, true) then
			labels[#labels + 1] = lab
			labelMap[lab] = e
		end
		if not seenName[e.short] then
			seenName[e.short] = true
			names[#names + 1] = e.short
		end
	end
	if #labels == 0 then labels = { "(tidak ada packet)" } end
	if #names == 0 then names = { "(tidak ada packet)" } end
	if ddPacket then pcall(function() ddPacket:SetValues(labels) end) end
	if ddMute then pcall(function() ddMute:SetValues(names) end) end
	if not state.selected and labelMap[labels[1]] then
		state.selected = labelMap[labels[1]]
		if ddPacket then pcall(function() ddPacket:SetValue(labels[1]) end) end
	end
end

local starting = false
local function startSpy()
	if starting then return end
	starting = true
	state.active = true
	state.t0 = state.t0 or os.clock()
	notify("Scan packet ByteNet ...", 3)
	connectChatService()
	task.spawn(function()
		local added = scanPackets()
		for _, e in ipairs(entries) do attach(e) end
		local okC, errC = installClientHook()
		if not okC then
			for _, e in ipairs(entries) do wrapSendFallback(e) end
		end
		local nRem = connectRemotes()
		state.lastScan = os.clock()
		refreshLists()
		starting = false
		state.dirty = true
		notify(("Aktif: %d packet (%d baru), remote %d. OUT: %s"):format(
			#entries, added, nRem, okC and "hook process.client" or ("fallback obj.send (" .. tostring(errC) .. ")")), 6)
	end)
end

local function stopSpy()
	state.active = false
	for _, e in ipairs(entries) do detach(e) end
	disconnectRemotes()
	if chatConn then pcall(function() chatConn:Disconnect() end) chatConn = nil end
	state.dirty = true
end

local function clearAll()
	for _, e in ipairs(entries) do resetEntry(e) end
	table.clear(Store.feed)
	table.clear(Store.log)
	table.clear(Store.chat)
	table.clear(Chan.pending)
	Raw.reliable.n, Raw.reliable.bytes, Raw.unreliable.n, Raw.unreliable.bytes = 0, 0, 0, 0
	logCfg.seq, logCfg.dropped = 0, 0
	state.t0 = state.active and os.clock() or nil
	state.dirty = true
end

------------------------------------------------------------------
-- API UNTUK SCRIPT BARU: getgenv().StructScope
------------------------------------------------------------------
local function lookup(k)
	if type(k) == "number" then return byId[k] end
	if type(k) == "string" then return byName[k:lower()] end
	return nil
end

local API = {
	Version = VERSION,
	Packets = {
		get = function(k) local e = lookup(k) return e and e.obj or nil end,
		info = function(k)
			local e = lookup(k)
			if not e then return nil end
			local c, src = chanInfo(e)
			return {
				id = e.id, name = e.short, fullName = e.name, channel = c, source = src,
				struct = introspect(e), schema = e.schema,
				counts = { inR = e.inR, inU = e.inU, inX = e.inX, outR = e.outR, outU = e.outU, outX = e.outX },
				samples = e.samples,
			}
		end,
		list = function()
			local out = {}
			for _, e in ipairs(sortedEntries()) do out[#out + 1] = e.short end
			return out
		end,
	},
	Subscribe = function(cb)
		if type(cb) ~= "function" then return function() end end
		Subs[#Subs + 1] = cb
		return function()
			local i = table.find(Subs, cb)
			if i then table.remove(Subs, i) end
		end
	end,
	Log = Store.log,
	Chat = Store.chat,
	Stats = function()
		local s = sumCounts()
		s.rawReliable, s.rawUnreliable = Raw.reliable, Raw.unreliable
		return s
	end,
	Export = { framework = frameworkModule, docs = docsMarkdown, report = allReport },
}

------------------------------------------------------------------
-- LINORIA UI
------------------------------------------------------------------
local Window = Library:CreateWindow({
	Title = "StructScope v" .. VERSION,
	Center = true,
	AutoShow = true,
	TabPadding = 6,
	MenuFadeTime = 0.15,
	Size = UDim2.fromOffset(720, 450),
})

local Tabs = {
	Main  = Window:AddTab("Utama"),
	View  = Window:AddTab("Viewer"),
	Log   = Window:AddTab("Log"),
	Copy  = Window:AddTab("Copy"),
	Frame = Window:AddTab("Framework"),
	Theme = Window:AddTab("Tema"),
	Info  = Window:AddTab("Info"),
}
Viewer.tab = Tabs.View

-- panel teks di dalam tab Viewer
local GBText = Tabs.View:AddLeftGroupbox("Isi Struct")
Viewer.titleLabel = GBText:AddLabel("Tampil: -")
do
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 300)
	holder.BackgroundColor3 = Library.OutlineColor
	holder.BorderSizePixel = 0
	holder.Parent = GBText.Container

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -2, 1, -2)
	scroll.Position = UDim2.fromOffset(1, 1)
	scroll.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
	scroll.ScrollingDirection = Enum.ScrollingDirection.XY
	scroll.Parent = holder

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0, 0, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.XY
	box.Position = UDim2.fromOffset(4, 4)
	box.BackgroundTransparency = 1
	box.MultiLine = true
	box.ClearTextOnFocus = false
	box.TextEditable = false
	box.TextWrapped = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.Font = Enum.Font.Code
	box.TextSize = 12
	box.TextColor3 = Color3.fromRGB(215, 222, 240)
	box.Text = ""
	box.Parent = scroll
	local minSize = Instance.new("UISizeConstraint")
	minSize.MinSize = Vector2.new(300, 200)
	minSize.Parent = box

	Viewer.holder, Viewer.scroll, Viewer.box = holder, scroll, box
	pcall(function() GBText:Resize() end)
end

-- minimize / close di title bar menu
local WinCtl = { minimized = false, hidden = {}, btns = {} }
do
	local holder = Window.Holder
	if not holder then
		pcall(function()
			for _, c in ipairs(Library.ScreenGui:GetChildren()) do
				if c:IsA("Frame") and c.AbsoluteSize.X > 400 then holder = c break end
			end
		end)
	end
	WinCtl.holder = holder

	function WinCtl.setMinimized(v)
		local h = WinCtl.holder
		if not h then notify("Minimize tidak didukung versi Linoria ini.", 3) return end
		if v then
			WinCtl.fullSize = h.Size
			WinCtl.hidden = {}
			local inner = h:FindFirstChildOfClass("Frame")
			if inner then
				for _, c in ipairs(inner:GetChildren()) do
					if c:IsA("GuiObject") and c.Visible and c.AbsoluteSize.Y > 40 then
						c.Visible = false
						WinCtl.hidden[#WinCtl.hidden + 1] = c
					end
				end
			end
			h.Size = UDim2.new(h.Size.X.Scale, h.Size.X.Offset, 0, 26)
		else
			for _, c in ipairs(WinCtl.hidden) do c.Visible = true end
			if WinCtl.fullSize then h.Size = WinCtl.fullSize end
		end
		WinCtl.minimized = v
		state.minimized = v
		state.dirty = true
		if WinCtl.minBtn then WinCtl.minBtn.Text = v and "+" or "-" end
	end
	function WinCtl.toggle() WinCtl.setMinimized(not WinCtl.minimized) end

	function WinCtl.unload()
		local fn = getgenv and getgenv().__StructScopeUnload
		if fn then fn() else pcall(function() Library:Unload() end) end
	end

	function WinCtl.applyTheme(t)
		for _, b in ipairs(WinCtl.btns) do
			b.BackgroundColor3 = t.Background
			b.TextColor3 = t.Font
		end
	end

	if holder then
		local function mk(text, xoff, cb)
			local b = Instance.new("TextButton")
			b.Size = UDim2.fromOffset(24, 18)
			b.Position = UDim2.new(1, xoff, 0, 4)
			b.BackgroundColor3 = Library.BackgroundColor
			b.BorderSizePixel = 0
			b.Text = text
			b.Font = Enum.Font.Code
			b.TextSize = 14
			b.TextColor3 = Library.FontColor
			b.ZIndex = 100
			b.Parent = holder
			track(b.MouseButton1Click:Connect(cb))
			WinCtl.btns[#WinCtl.btns + 1] = b
			return b
		end
		WinCtl.minBtn = mk("-", -56, function() WinCtl.toggle() end)
		local armed = false
		local xBtn
		xBtn = mk("X", -28, function()
			if not armed then
				armed = true
				xBtn.Text = "?"
				notify("Klik X sekali lagi untuk menutup semua.", 3)
				task.delay(3, function()
					armed = false
					pcall(function() xBtn.Text = "X" end)
				end)
				return
			end
			WinCtl.unload()
		end)
	end
end

local function doCopy(text, label)
	if CFG.Ascii then text = ascii(text) end
	notify(clip(text) and ("%s disalin (%d karakter)."):format(label, #text) or "setclipboard tidak didukung executor.", 3)
end

local function doSave(prefix, text, ext, subdir)
	if CFG.Ascii then text = ascii(text) end
	local path, err = writeOut(prefix, text, ext, subdir)
	notify(path and ("Disimpan: " .. path) or tostring(err), 6)
	return path
end

local function packetDefText(e)
	return "-- DECLARED\n" .. declaredText(e) .. "\n\n-- TEBAKAN dari data observed\n" .. guessText(e)
end

local function logLua()
	local list = filteredLog()
	if #list == 0 then notify("Tidak ada log yang cocok filter.", 3) return nil end
	return logToLua(list, "Packet log (filter aktif)")
end

local function chatLua()
	if #Store.chat == 0 then notify("Belum ada chat terdeteksi.", 3) return nil end
	return chatToLua()
end

local function needSelected()
	if not state.selected then notify("Pilih packet dulu di tab Viewer.", 3) return nil end
	return state.selected
end

local function jumpView(key)
	state.view = key
	local m = MODE_BY_KEY[key]
	if m and modeDD then pcall(function() modeDD:SetValue(m.label) end) end
	state.view = key
	showView()
end

------------------------------------------------------------------
-- TAB UTAMA
------------------------------------------------------------------
local GBControl = Tabs.Main:AddLeftGroupbox("Kontrol")
local recToggle = GBControl:AddToggle("SS_Rec", {
	Text = "Rekam Packet (pasif)",
	Default = false,
	Tooltip = "Scan packet, pasang listener IN, hook OUT, dan pantau RemoteEvent. Hanya merekam.",
	Callback = function(v)
		if v then startSpy() else stopSpy() notify("Rekam dihentikan (data tetap tersimpan).", 3) end
	end,
})
GBControl:AddButton({
	Text = "Scan Ulang Packet",
	Func = function()
		task.spawn(function()
			local n = scanPackets()
			if state.active then
				for _, e in ipairs(entries) do attach(e) end
			end
			refreshLists()
			notify(("Scan selesai: %d packet baru, total %d."):format(n, #entries), 4)
		end)
	end,
})
GBControl:AddButton({ Text = "Buka Viewer", Func = showView })
GBControl:AddButton({ Text = "Kecilkan / Perbesar Menu", Func = function() WinCtl.toggle() end })
GBControl:AddButton({
	Text = "Clear Semua Data",
	Func = function() clearAll() notify("Data packet dibersihkan.", 2) end,
})
statusLabel = GBControl:AddLabel("Status: belum aktif", true)

local GBStat = Tabs.Main:AddRightGroupbox("Statistik Channel")
statLabel = GBStat:AddLabel("Belum ada data", true)
GBStat:AddButton({ Text = "Lihat Statistik di Viewer", Func = function() jumpView("stats") end })

local GBWin = Tabs.Main:AddRightGroupbox("Jendela")
GBWin:AddButton({ Text = "Tutup Semua (Unload)", Func = function() WinCtl.unload() end })

------------------------------------------------------------------
-- TAB VIEWER (kontrol)
------------------------------------------------------------------
local GBPick = Tabs.View:AddRightGroupbox("Lihat Struct")
GBPick:AddInput("SS_Filter", {
	Default = "",
	Numeric = false,
	Finished = false,
	Text = "Filter nama / ID",
	Placeholder = "contoh: act atau 12",
	Callback = function(t)
		state.filter = (t or ""):lower()
		refreshLists()
	end,
})
ddPacket = GBPick:AddDropdown("SS_Packet", {
	Values = { "(scan dulu)" },
	Default = 1,
	Multi = false,
	Text = "Packet",
	Callback = function(v)
		local e = labelMap[v]
		if e then
			state.selected = e
			state.dirty = true
		end
	end,
})
modeDD = GBPick:AddDropdown("SS_Mode", {
	Values = MODE_LABELS,
	Default = 1,
	Multi = false,
	Text = "Tampilan",
	Callback = function(v)
		local m = MODE_BY_LABEL[v]
		if m then state.view = m.key end
		state.dirty = true
	end,
})
GBPick:AddToggle("SS_Auto", {
	Text = "Auto-refresh viewer",
	Default = true,
	Callback = function(v) state.auto = v end,
})
GBPick:AddButton({ Text = "Tampilkan / Refresh", Func = showView })
GBPick:AddButton({
	Text = "Copy Isi Viewer",
	Func = function()
		if Viewer.full == "" then return notify("Viewer kosong.", 2) end
		notify(clip(Viewer.full) and "Teks disalin." or "setclipboard tidak didukung.", 2)
	end,
})
GBPick:AddButton({
	Text = "Simpan Isi Viewer",
	Func = function()
		if Viewer.full == "" then return notify("Viewer kosong.", 2) end
		local path, err = writeOut(safeName(Viewer.title), Viewer.full)
		notify(path and ("Disimpan: " .. path) or tostring(err), 6)
	end,
})

------------------------------------------------------------------
-- TAB LOG
------------------------------------------------------------------
local GBFilter = Tabs.Log:AddLeftGroupbox("Filter Log")
GBFilter:AddDropdown("SS_LogDir", {
	Values = { "Semua", "IN", "OUT" },
	Default = 1,
	Multi = false,
	Text = "Arah (IN server ke client)",
	Callback = function(v) logCfg.dir = v state.dirty = true end,
})
GBFilter:AddDropdown("SS_LogChan", {
	Values = { "Semua", "reliable", "unreliable", "?" },
	Default = 1,
	Multi = false,
	Text = "Channel",
	Callback = function(v) logCfg.chan = v state.dirty = true end,
})
GBFilter:AddDropdown("SS_LogCat", {
	Values = { "Semua", "chat", "movement", "other" },
	Default = 1,
	Multi = false,
	Text = "Kategori",
	Callback = function(v) logCfg.cat = v state.dirty = true end,
})
GBFilter:AddInput("SS_LogName", {
	Default = "",
	Numeric = false,
	Finished = false,
	Text = "Filter nama / ID packet",
	Placeholder = "contoh: chat atau note",
	Callback = function(t) logCfg.name = (t or ""):lower() state.dirty = true end,
})
GBFilter:AddSlider("SS_LogLines", {
	Text = "Baris tampil di viewer",
	Default = state.logLines,
	Min = 10,
	Max = 70,
	Rounding = 0,
	Compact = false,
	Callback = function(v) state.logLines = v state.dirty = true end,
})
GBFilter:AddButton({ Text = "Lihat Log Packet di Viewer", Func = function() jumpView("log") end })
GBFilter:AddButton({ Text = "Lihat Chat Log di Viewer", Func = function() jumpView("chat") end })
GBFilter:AddButton({ Text = "Lihat Live Feed di Viewer", Func = function() jumpView("feed") end })

local GBRec = Tabs.Log:AddRightGroupbox("Rekaman")
GBRec:AddSlider("SS_MoveCap", {
	Text = "Movement maks /detik (0 = semua)",
	Default = CFG.MoveCap,
	Min = 0,
	Max = 30,
	Rounding = 0,
	Compact = false,
	Callback = function(v) CFG.MoveCap = v end,
})
GBRec:AddSlider("SS_MaxSamples", {
	Text = "Maks sampel per packet",
	Default = CFG.MaxSamples,
	Min = 3,
	Max = 40,
	Rounding = 0,
	Compact = false,
	Callback = function(v) CFG.MaxSamples = v end,
})
ddMute = GBRec:AddDropdown("SS_Mute", {
	Values = { "(scan dulu)" },
	Multi = true,
	AllowNull = true,
	Text = "Mute packet spam",
	Tooltip = "Packet yang dipilih tetap dihitung tapi tidak dicatat / dipelajari.",
	Callback = function(v)
		table.clear(muted)
		if type(v) == "table" then
			for name, on in pairs(v) do
				if on then muted[name] = true end
			end
		end
	end,
})
GBRec:AddToggle("SS_Ascii", {
	Text = "ASCII-safe (cegah huruf kotak)",
	Default = CFG.Ascii,
	Callback = function(v) CFG.Ascii = v state.dirty = true end,
})
GBRec:AddToggle("SS_AutoScan", {
	Text = "Auto-scan packet baru (20 detik)",
	Default = false,
	Tooltip = "getgc cukup berat. Nyalakan hanya jika packet baru sering didefinisikan.",
	Callback = function(v) state.autoScan = v end,
})
GBRec:AddButton({
	Text = "Hapus Log dan Chat Saja",
	Func = function()
		table.clear(Store.log)
		table.clear(Store.chat)
		logCfg.seq, logCfg.dropped = 0, 0
		state.dirty = true
		notify("Log dan chat dibersihkan.", 2)
	end,
})

------------------------------------------------------------------
-- TAB COPY
------------------------------------------------------------------
local GBCopy = Tabs.Copy:AddLeftGroupbox("Copy ke Clipboard")
GBCopy:AddButton({ Text = "Copy Tampilan Saat Ini", Func = function() doCopy(currentText(), "Tampilan") end })
GBCopy:AddButton({
	Text = "Copy Table Log (Lua)",
	Tooltip = "Semua log packet sesuai filter di tab Log",
	Func = function() local s = logLua() if s then doCopy(s, "Table log") end end,
})
GBCopy:AddButton({
	Text = "Copy Table Chat (Lua)",
	Func = function() local s = chatLua() if s then doCopy(s, "Table chat") end end,
})
GBCopy:AddButton({
	Text = "Copy Tabel Packet (Lua)",
	Tooltip = "Daftar semua packet: id, nama, channel, jumlah, struct",
	Func = function() doCopy(registryLua(), "Tabel packet") end,
})
GBCopy:AddButton({
	Text = "Copy Definisi ByteNet (terpilih)",
	Func = function()
		local e = needSelected()
		if e then doCopy(packetDefText(e), "Definisi") end
	end,
})
GBCopy:AddButton({ Text = "Copy Statistik Channel", Func = function() doCopy(channelStatsText(), "Statistik") end })
GBCopy:AddButton({ Text = "Copy Laporan SEMUA Packet", Func = function() doCopy(allReport(), "Laporan") end })

local GBSave = Tabs.Copy:AddRightGroupbox("Simpan ke File")
GBSave:AddButton({
	Text = "Simpan Tampilan",
	Func = function()
		local text, title = currentText()
		doSave(safeName(title), text, "txt")
	end,
})
GBSave:AddButton({
	Text = "Simpan Table Log (.lua)",
	Func = function() local s = logLua() if s then doSave("packet_log", s, "lua") end end,
})
GBSave:AddButton({
	Text = "Simpan Table Chat (.lua)",
	Func = function() local s = chatLua() if s then doSave("chat_log", s, "lua") end end,
})
GBSave:AddButton({ Text = "Simpan Tabel Packet (.lua)", Func = function() doSave("packet_table", registryLua(), "lua") end })
GBSave:AddButton({
	Text = "Simpan Laporan SEMUA",
	Func = function() doSave("struct_report_" .. tostring(game.PlaceId), allReport(), "txt") end,
})

------------------------------------------------------------------
-- TAB FRAMEWORK
------------------------------------------------------------------
local GBGen = Tabs.Frame:AddLeftGroupbox("Generate")
GBGen:AddLabel("Hasilkan modul dan dokumentasi dari packet yang sudah dikenali.", true)
GBGen:AddButton({ Text = "Lihat Packets.lua di Viewer", Func = function() jumpView("framework") end })
GBGen:AddButton({ Text = "Lihat Dokumentasi di Viewer", Func = function() jumpView("docs") end })
GBGen:AddButton({
	Text = "Lihat Template Script (terpilih)",
	Func = function() if needSelected() then jumpView("template") end end,
})
GBGen:AddButton({ Text = "Copy Packets.lua (ByteNet)", Func = function() doCopy(frameworkModule(), "Packets.lua") end })
GBGen:AddButton({ Text = "Copy Dokumentasi Markdown", Func = function() doCopy(docsMarkdown(), "Dokumentasi") end })
GBGen:AddButton({
	Text = "Copy Template Script (terpilih)",
	Func = function()
		local e = needSelected()
		if e then doCopy(templateText(e), "Template") end
	end,
})

local GBFSave = Tabs.Frame:AddRightGroupbox("Simpan")
GBFSave:AddButton({ Text = "Simpan Packets.lua", Func = function() doSave("Packets", frameworkModule(), "lua") end })
GBFSave:AddButton({ Text = "Simpan Dokumentasi (.md)", Func = function() doSave("DOKUMENTASI_" .. tostring(game.PlaceId), docsMarkdown(), "md") end })
GBFSave:AddButton({
	Text = "Simpan Template Script (terpilih)",
	Func = function()
		local e = needSelected()
		if e then doSave("template_" .. safeName(e.short), templateText(e), "lua") end
	end,
})
GBFSave:AddButton({
	Text = "Export SEMUA ke satu folder",
	Tooltip = "Packets.lua, dokumentasi, laporan, tabel packet, log, chat",
	Func = function()
		if #entries == 0 then return notify("Belum ada packet. Scan / rekam dulu.", 3) end
		local sub = ("export_%s_%d"):format(tostring(game.PlaceId), os.time())
		local files = {
			{ "Packets", frameworkModule(), "lua" },
			{ "DOKUMENTASI", docsMarkdown(), "md" },
			{ "laporan", allReport(), "txt" },
			{ "tabel_packet", registryLua(), "lua" },
			{ "log", logToLua(Store.log, "Packet log (semua)"), "lua" },
			{ "chat", chatToLua(), "lua" },
		}
		local okN = 0
		for _, f in ipairs(files) do
			local txt = CFG.Ascii and ascii(f[2]) or f[2]
			if writeOut(f[1], txt, f[3], sub) then okN += 1 end
		end
		notify(okN > 0 and ("Export: %d file di workspace/StructScope/%s"):format(okN, sub) or "Export gagal (writefile?).", 6)
	end,
})

------------------------------------------------------------------
-- TEMA
------------------------------------------------------------------
local THEME_ORDER = { "Teal Gelap", "Midnight Biru", "Ungu Neon", "Hijau Terminal", "Abu Terang" }
local THEMES = {
	["Teal Gelap"] = {
		Main = Color3.fromRGB(24, 28, 34), Background = Color3.fromRGB(16, 19, 24), Accent = Color3.fromRGB(0, 170, 160),
		Outline = Color3.fromRGB(45, 52, 62), Font = Color3.fromRGB(230, 236, 240), View = Color3.fromRGB(12, 15, 20),
	},
	["Midnight Biru"] = {
		Main = Color3.fromRGB(22, 26, 40), Background = Color3.fromRGB(14, 17, 28), Accent = Color3.fromRGB(70, 130, 255),
		Outline = Color3.fromRGB(42, 50, 78), Font = Color3.fromRGB(225, 232, 250), View = Color3.fromRGB(10, 12, 22),
	},
	["Ungu Neon"] = {
		Main = Color3.fromRGB(30, 22, 40), Background = Color3.fromRGB(20, 14, 28), Accent = Color3.fromRGB(180, 90, 255),
		Outline = Color3.fromRGB(62, 46, 80), Font = Color3.fromRGB(238, 228, 250), View = Color3.fromRGB(14, 10, 20),
	},
	["Hijau Terminal"] = {
		Main = Color3.fromRGB(16, 24, 18), Background = Color3.fromRGB(10, 16, 12), Accent = Color3.fromRGB(60, 220, 110),
		Outline = Color3.fromRGB(34, 58, 40), Font = Color3.fromRGB(200, 245, 210), View = Color3.fromRGB(6, 12, 8),
	},
	["Abu Terang"] = {
		Main = Color3.fromRGB(235, 238, 242), Background = Color3.fromRGB(246, 248, 250), Accent = Color3.fromRGB(0, 120, 200),
		Outline = Color3.fromRGB(190, 196, 204), Font = Color3.fromRGB(30, 34, 40), View = Color3.fromRGB(255, 255, 255),
	},
}

local function applyTheme(name)
	local t = THEMES[name]
	if not t then return end
	Library.MainColor = t.Main
	Library.BackgroundColor = t.Background
	Library.AccentColor = t.Accent
	Library.OutlineColor = t.Outline
	Library.FontColor = t.Font
	pcall(function() Library.AccentColorDark = Library:GetDarkerColor(t.Accent) end)
	pcall(function() Library:UpdateColorsUsingRegistry() end)
	pcall(Viewer.applyTheme, t)
	pcall(WinCtl.applyTheme, t)
end

local GBTheme = Tabs.Theme:AddLeftGroupbox("Tema")
GBTheme:AddDropdown("SS_Theme", {
	Values = THEME_ORDER,
	Default = 1,
	Multi = false,
	Text = "Pilih tema",
	Callback = function(v) applyTheme(v) end,
})
GBTheme:AddLabel("Tema berlaku untuk menu dan viewer.", true)

local GBMenu = Tabs.Theme:AddRightGroupbox("Menu")
GBMenu:AddButton({ Text = "Tutup Semua (Unload)", Func = function() WinCtl.unload() end })
pcall(function()
	local lbl = GBMenu:AddLabel("Tombol buka/tutup menu")
	lbl:AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, Mode = "Toggle", NoUI = true, Text = "Menu keybind" })
	local opts = (getgenv and getgenv().Options) or Library.Options
	if opts and opts.MenuKeybind then Library.ToggleKeybind = opts.MenuKeybind end
end)

------------------------------------------------------------------
-- TAB INFO
------------------------------------------------------------------
local GBInfo = Tabs.Info:AddLeftGroupbox("Cara Pakai")
GBInfo:AddLabel(
	"1. Nyalakan Rekam Packet (tab Utama).\n" ..
	"2. Lakukan aksi di game: jalan, pukul, chat, dll.\n" ..
	"3. Tab Viewer: pilih packet dan Tampilan.\n" ..
	"4. Tab Log: filter arah / channel / kategori.\n" ..
	"5. Tab Copy: copy atau simpan log, chat, tabel packet.\n" ..
	"6. Tab Framework: Packets.lua, dokumentasi, template.\n" ..
	"7. Title bar menu: - (kecilkan), X (tutup, klik 2x).",
	true
)
local GBNote = Tabs.Info:AddRightGroupbox("Catatan")
GBNote:AddLabel(
	"Channel OUT pasti dari hook sendReliable/sendUnreliable. " ..
	"Channel IN dibaca dari definisi packet; bila tidak ada, ditebak dari RemoteEvent (tanda ~). " ..
	"Data yang dilihat adalah hasil decode ByteNet (table), bukan buffer mentah. " ..
	"Declared butuh getupvalues dan debug.info. " ..
	"Script lain bisa memakai getgenv().StructScope (lihat Dokumentasi).",
	true
)

applyTheme("Teal Gelap")

------------------------------------------------------------------
-- UNLOAD
------------------------------------------------------------------
local function cleanup()
	if not running then return end
	running = false
	state.active = false
	for _, e in ipairs(entries) do pcall(detach, e) end
	disconnectRemotes()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	for _, b in ipairs(WinCtl.btns) do pcall(function() b:Destroy() end) end
	if chatConn then pcall(function() chatConn:Disconnect() end) chatConn = nil end
	table.clear(Subs)
	if getgenv then
		pcall(function()
			getgenv().__SS_out = nil
			getgenv().__StructScopeUnload = nil
			getgenv().StructScope = nil
		end)
	end
end
pcall(function() Library:OnUnload(cleanup) end)
if getgenv then
	getgenv().__StructScopeUnload = function()
		cleanup()
		pcall(function() Library:Unload() end)
	end
	getgenv().StructScope = API
end

------------------------------------------------------------------
-- LOOP
------------------------------------------------------------------
task.spawn(function()
	local lastStatus = 0
	while running do
		local now = os.clock()
		if state.listDirty then pcall(refreshLists) end
		if state.autoScan and state.active and not starting and now - state.lastScan >= CFG.AutoScanEvery then
			state.lastScan = now
			task.spawn(function()
				local n = scanPackets()
				if n > 0 then
					for _, e in ipairs(entries) do attach(e) end
					refreshLists()
				end
			end)
		end
		if state.auto and state.dirty and Viewer.isOpen() then
			state.dirty = false
			pcall(function()
				local text, title = render()
				Viewer.set(text, title)
			end)
		end
		if now - lastStatus >= 1 then
			lastStatus = now
			local s = sumCounts()
			pcall(function()
				statusLabel:SetText(("Status: %s | packet %d\nIN %d | OUT %d"):format(
					state.active and "REKAM" or "BERHENTI", #entries,
					s.inR + s.inU + s.inX, s.outR + s.outU + s.outX))
			end)
			pcall(function()
				statLabel:SetText(("Reliable   IN %d | OUT %d\nUnreliable IN %d | OUT %d\nBelum jelas IN %d | OUT %d\nRaw byte R %d | U %d"):format(
					s.inR, s.outR, s.inU, s.outU, s.inX, s.outX, Raw.reliable.bytes, Raw.unreliable.bytes))
			end)
		end
		task.wait(0.3)
	end
end)

notify("StructScope siap. Nyalakan 'Rekam Packet' untuk mulai.", 4)
