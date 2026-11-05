--[[
    GrowBloxKit (GB)  v1.0.0
    Framework scripting untuk game ByteNet (struktur packet.packet).
    Dokumentasi lengkap: GrowBloxKit_Docs.md

    QUICK START
        local GB = loadstring(readfile("GrowBloxKit.lua"))()   -- atau paste file ini
        GB.Init()                                              -- scan packet (bisa yield beberapa detik)
        GB.Chat.SendMessage("Halo!")
        GB.On("note", function(data) print(GB.ParseNote(data)) end)
        GB.Punch(54, 37)
        print(GB.Docs("act"))                                  -- dokumentasi otomatis dari data nyata

    Prinsip:
      * Semua pengiriman memakai fungsi send() milik game sendiri (bukan injeksi mentah).
      * Ada batas laju (PacketRate / ChatInterval) dan mode DryRun untuk uji tanpa kirim.
      * Struct dipelajari otomatis dari trafik nyata (Learn) + diisi dari log awal (SEED).
]]

local GB = { Version = "1.0.0" }

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService   = game:GetService("TextChatService")
local HttpService       = game:GetService("HttpService")
local LocalPlayer       = Players.LocalPlayer

------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------
GB.Config = {
	DryRun       = false,      -- true = Send() hanya mencetak, tidak mengirim
	Debug        = false,      -- true = log internal
	Validate     = "warn",     -- "warn" | "error" | false (cek data vs struct hasil learn)
	PacketRate   = 15,         -- maks packet GB.Send per detik
	ChatInterval = 1.2,        -- jeda minimal antar pesan chat (detik)
	ChatChannel  = "RBXGeneral",
	ChatBuilder  = nil,        -- function(text) -> packetName, data   (jika chat lewat packet)
	PunchKind    = 6,          -- nilai "kind" packet act untuk pukul (DUGAAN dari log, verifikasi!)
	PunchBuilder = nil,        -- function(tx, ty) -> packetName, data (jika ada packet "punch" sendiri)
	Aliases = {                -- alias -> daftar kandidat nama packet asli (huruf kecil)
		chat  = { "chat", "say", "msg", "message", "sendmessage" },
		enter = { "enter", "join", "worldenter" },
		quit  = { "quit", "leave", "exit" },
		punch = { "punch", "hit", "attack" },
	},
}

local function log(...)
	if GB.Config.Debug then print("[GB]", ...) end
end
local function warnf(fmt, ...)
	warn("[GB] " .. string.format(fmt, ...))
end

------------------------------------------------------------------
-- STATE
------------------------------------------------------------------
local byName, byId, byObj, list = {}, {}, {}, {}
local pending = {}
local chatHandlers, chatHistory = {}, {}
local chatConn
local inited, outHooked = false, false

------------------------------------------------------------------
-- UTIL: snapshot, literal, schema (learn / check / flatten)
------------------------------------------------------------------
local function snap(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "table" then
		if depth >= 5 then return nil end
		local out, n = {}, 0
		for k, val in next, v do
			n += 1
			if n > 100 then break end
			out[type(k) == "table" and tostring(k) or k] = snap(val, depth + 1)
		end
		return out
	elseif t == "buffer" or t == "function" or t == "thread" then
		return nil
	end
	return v
end

local function isArray(v)
	local n = #v
	if n == 0 then return false end
	for k in pairs(v) do
		if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then return false end
	end
	return true
end

local IDENT = "^[%a_][%w_]*$"
local function lit(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "nil" then return "nil"
	elseif t == "boolean" then return tostring(v)
	elseif t == "number" then
		if v ~= v then return "0/0" end
		if v % 1 == 0 and math.abs(v) < 1e15 then return string.format("%d", v) end
		return string.format("%.6g", v)
	elseif t == "string" then return string.format("%q", v)
	elseif t == "Vector3" then return ("Vector3.new(%g, %g, %g)"):format(v.X, v.Y, v.Z)
	elseif t == "Vector2" then return ("Vector2.new(%g, %g)"):format(v.X, v.Y)
	elseif t == "Instance" then return string.format("%q", "@" .. v:GetFullName())
	elseif t == "table" then
		if depth >= 4 then return "{...}" end
		local parts = {}
		if isArray(v) then
			for i = 1, math.min(#v, 6) do parts[#parts + 1] = lit(v[i], depth + 1) end
			if #v > 6 then parts[#parts + 1] = "..." end
		else
			local keys = {}
			for k in pairs(v) do keys[#keys + 1] = k end
			table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
			for _, k in ipairs(keys) do
				local ks = (type(k) == "string" and k:match(IDENT)) and k or ("[" .. lit(k, depth + 1) .. "]")
				parts[#parts + 1] = ks .. " = " .. lit(v[k], depth + 1)
			end
		end
		if #parts == 0 then return "{}" end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	return "nil --[[" .. t .. "]]"
end

-- node = { types = {tipe=true}, n = jumlah_sampel, fields = {k=node}, objN, item = node }
local function learn(node, v, depth)
	depth = depth or 0
	node = node or { types = {}, n = 0 }
	node.n += 1
	local t = typeof(v)
	if t == "table" then
		if depth >= 6 then node.types.object = true return node end
		if isArray(v) then
			node.types.array = true
			for i = 1, math.min(#v, 20) do node.item = learn(node.item, v[i], depth + 1) end
		else
			node.types.object = true
			node.objN = (node.objN or 0) + 1
			node.fields = node.fields or {}
			for k, val in next, v do
				local key = tostring(k)
				node.fields[key] = learn(node.fields[key], val, depth + 1)
			end
		end
	else
		node.types[t] = true
	end
	return node
end

local function typeStr(node)
	local ks = {}
	for k in pairs(node.types) do ks[#ks + 1] = k end
	table.sort(ks)
	return #ks > 0 and table.concat(ks, "|") or "any"
end

local function check(node, v, path, out)
	if not node or #out >= 8 then return end
	local t = typeof(v)
	if t == "table" then
		if isArray(v) then
			if not node.types.array then
				out[#out + 1] = path .. ": array, seharusnya " .. typeStr(node)
			elseif node.item then
				for i = 1, math.min(#v, 20) do check(node.item, v[i], path .. "[" .. i .. "]", out) end
			end
		else
			if not node.types.object then
				out[#out + 1] = path .. ": object, seharusnya " .. typeStr(node)
				return
			end
			for k, val in next, v do
				local key = tostring(k)
				local f = node.fields and node.fields[key]
				if f == nil then
					out[#out + 1] = path .. "." .. key .. ": field tidak dikenal"
				else
					check(f, val, path .. "." .. key, out)
				end
			end
			if node.fields and (node.objN or 0) >= 2 then
				for key, f in pairs(node.fields) do
					if f.n == node.objN and rawget(v, key) == nil then
						out[#out + 1] = path .. "." .. key .. ": field wajib hilang"
					end
				end
			end
		end
	elseif next(node.types) and not node.types[t] then
		out[#out + 1] = ("%s: tipe %s, seharusnya %s"):format(path, t, typeStr(node))
	end
end

local function flatten(node, path, rows, required)
	rows[#rows + 1] = { path = path, type = typeStr(node), req = required }
	if node.fields then
		local keys = {}
		for k in pairs(node.fields) do keys[#keys + 1] = k end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local f = node.fields[k]
			flatten(f, path == "" and k or (path .. "." .. k), rows, f.n == (node.objN or f.n))
		end
	end
	if node.item then flatten(node.item, path .. "[]", rows, true) end
end

------------------------------------------------------------------
-- SEED: struct yang sudah diketahui dari log Growblox
-- (dipakai sebagai skema awal; diperbarui otomatis oleh Learn)
------------------------------------------------------------------
local SEED = {
	move = {
		{ flags = 3, t = 15565, vx = 0, vy = 0, x = 59.79495, y = 36.999 },
		{ flags = 3, t = 3367, vx = 1.259081, vy = 0, x = 53.07366, y = 36.999 },
		{ flags = 3, t = 4374, vx = 7.2, vy = 0, x = 57.40022, y = 36.999 },
	},
	act = {
		{ kind = 6, x = 54.5, y = 37.5 },
		{ kind = 1, x = 54.5783, y = 37.88235 },
	},
	busy = { 0, 1 },
	note = {
		{ e = 5, w = 0, a = {
			{ s = { "donatesay" } },
			{ j = true, s = { '{"t":["kind","donatesay","total",100,"name","JEEX","n",100]}' } },
		} },
	},
}

------------------------------------------------------------------
-- REGISTRY
------------------------------------------------------------------
local function indexEntry(entry)
	local short = entry.name:match("([^%.]+)$") or entry.name
	entry.short = short
	local k1, k2 = short:lower(), entry.name:lower()
	if not byName[k1] then byName[k1] = entry end
	byName[k2] = entry
	if entry.id then byId[entry.id] = entry end
end

local function applySeed(entry)
	if entry.seeded then return end
	local seed = SEED[entry.short:lower()]
	if seed then
		for _, sample in ipairs(seed) do entry.schema = learn(entry.schema, sample) end
		entry.seeded = true
	end
end

local function resolve(key)
	if type(key) == "number" then return byId[key] end
	if type(key) ~= "string" then return nil end
	local lk = key:lower()
	if byName[lk] then return byName[lk] end
	local al = GB.Config.Aliases[lk]
	if al then
		for _, cand in ipairs(al) do
			local e = byName[cand:lower()]
			if e then return e end
		end
	end
	return nil
end

local function observe(entry, dir, data)
	entry.dirs[dir] = (entry.dirs[dir] or 0) + 1
	if (entry.learned or 0) < 200 then
		entry.learned = (entry.learned or 0) + 1
		entry.schema = learn(entry.schema, data)
	end
	local s = entry.samples
	s[#s + 1] = { dir = dir, data = snap(data) }
	if #s > 3 then table.remove(s, 1) end
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

local function findPacketId(obj)
	local fn = getupvalues or (debug and debug.getupvalues)
	if not fn then return nil end
	for _, key in ipairs({ "send", "sendTo", "sendToAll" }) do
		local f = rawget(obj, key)
		if type(f) == "function" then
			local ok, ups = pcall(fn, f)
			if ok and type(ups) == "table" then
				for _, v in pairs(ups) do
					if type(v) == "number" and v % 1 == 0 and v >= 0 and v < 65536 then return v end
				end
			end
		end
	end
	return nil
end

local function register(obj, name)
	local entry = byObj[obj]
	if entry then
		if name and entry.auto then
			entry.name, entry.auto = name, false
			indexEntry(entry)
			applySeed(entry)
		end
		return entry
	end
	local id = findPacketId(obj)
	entry = {
		obj = obj, id = id, auto = name == nil, dirs = {}, samples = {}, handlers = {},
		sent = 0, received = 0,
		name = name or (id and ("pkt_" .. id)) or ("pkt_" .. (#list + 1)),
	}
	byObj[obj] = entry
	list[#list + 1] = entry
	indexEntry(entry)

	applySeed(entry)

	local okL, listeners = pcall(function() return rawget(obj, "getListeners")() end)
	if okL and type(listeners) == "table" then
		entry.listeners = listeners
		entry.master = function(data, ...)
			entry.received += 1
			pcall(observe, entry, "IN", data)
			for _, h in ipairs(table.clone(entry.handlers)) do
				if not h.dead then task.spawn(h.fn, data, ...) end
			end
		end
		table.insert(listeners, entry.master)
	end
	return entry
end

local function scanPackets()
	local before = #list
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
	return #list - before
end

local function flushPending()
	local rest = {}
	for _, h in ipairs(pending) do
		if not h.dead then
			local e = resolve(h.name)
			if e then
				h.entry = e
				e.handlers[#e.handlers + 1] = h
			else
				rest[#rest + 1] = h
			end
		end
	end
	pending = rest
end

-- Pengamat OUT: mempelajari struct dari packet yang dikirim game sendiri
local function installOutObserver()
	if not hookfunction then return false end
	local genv = getgenv and getgenv() or nil
	local function observeOut(id, data)
		local e = byId[id]
		if e then observe(e, "OUT", data) end
	end
	if genv then genv.__GB_observeOut = observeOut end
	if genv and genv.__GB_outHooked then outHooked = true return true end

	local bn = ReplicatedStorage:FindFirstChild("ByteNet")
	local proc = bn and bn:FindFirstChild("process")
	local m = proc and proc:FindFirstChild("client")
	if not m then return false end
	local okR, client = pcall(require, m)
	if not okR or type(client) ~= "table" then return false end

	local hooked = 0
	for _, fname in ipairs({ "sendReliable", "sendUnreliable" }) do
		local f = rawget(client, fname)
		if type(f) == "function" then
			local orig
			local ok = pcall(function()
				orig = hookfunction(f, function(id, writer, data, ...)
					local cb = (getgenv and getgenv().__GB_observeOut) or observeOut
					pcall(cb, id, data)
					return orig(id, writer, data, ...)
				end)
			end)
			if ok and orig then hooked += 1 end
		end
	end
	outHooked = hooked > 0
	if genv and outHooked then genv.__GB_outHooked = true end
	return outHooked
end

------------------------------------------------------------------
-- RATE LIMIT
------------------------------------------------------------------
local bucket = { tokens = 15, t = os.clock() }
local function take()
	local now = os.clock()
	local cap = GB.Config.PacketRate
	bucket.tokens = math.min(cap, bucket.tokens + (now - bucket.t) * cap)
	bucket.t = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

------------------------------------------------------------------
-- CHAT (TextChatService)
------------------------------------------------------------------
local Chat = {}
GB.Chat = Chat

local function connectChat()
	if chatConn then return end
	local ok, conn = pcall(function()
		return TextChatService.MessageReceived:Connect(function(msg)
			local src = msg.TextSource
			local name = src and src.Name or "?"
			local text = tostring(msg.Text)
			chatHistory[#chatHistory + 1] = { name = name, userId = src and src.UserId, text = text, time = os.time() }
			if #chatHistory > 200 then table.remove(chatHistory, 1) end
			for _, h in ipairs(table.clone(chatHandlers)) do
				if not h.dead then task.spawn(h.fn, name, text, msg) end
			end
		end)
	end)
	if ok then chatConn = conn end
end

local function sendChatNow(text)
	if GB.Config.DryRun then
		print("[GB][DryRun] chat:", text)
		return true
	end
	local builder = GB.Config.ChatBuilder
	if builder then
		local name, data = builder(text)
		return GB.Send(name, data)
	end
	local okV, isNew = pcall(function() return TextChatService.ChatVersion == Enum.ChatVersion.TextChatService end)
	if okV and isNew then
		local channels = TextChatService:FindFirstChild("TextChannels")
		local ch = channels and (channels:FindFirstChild(GB.Config.ChatChannel) or channels:FindFirstChildWhichIsA("TextChannel"))
		if ch then
			local ok, err = pcall(function() ch:SendAsync(text) end)
			return ok, (not ok) and tostring(err) or nil
		end
	end
	local ev = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
	local say = ev and ev:FindFirstChild("SayMessageRequest")
	if say then
		say:FireServer(text, "All")
		return true
	end
	return false, "tidak ada jalur chat (TextChannel / SayMessageRequest); set GB.Config.ChatBuilder"
end

local chatQueue, chatRunning, lastChat = {}, false, 0
local function chatWorker()
	if chatRunning then return end
	chatRunning = true
	task.spawn(function()
		while #chatQueue > 0 do
			local wait = GB.Config.ChatInterval - (os.clock() - lastChat)
			if wait > 0 then task.wait(wait) end
			local text = table.remove(chatQueue, 1)
			lastChat = os.clock()
			local ok, err = sendChatNow(text)
			if not ok then warnf("chat gagal: %s", tostring(err)) end
		end
		chatRunning = false
	end)
end

--- Kirim pesan chat (antre + jeda otomatis). Mengembalikan true jika masuk antrean.
function Chat.SendMessage(text)
	assert(type(text) == "string", "Chat.SendMessage(text): text harus string")
	text = (text:gsub("^%s+", ""))
	text = (text:gsub("%s+$", ""))
	if text == "" then return false, "pesan kosong" end
	if #text > 200 then
		text = text:sub(1, 200)
		warnf("pesan dipotong menjadi 200 karakter")
	end
	if #chatQueue >= 20 then return false, "antrean chat penuh (maks 20)" end
	chatQueue[#chatQueue + 1] = text
	chatWorker()
	return true
end

--- Dengar semua pesan chat. fn(namaPemain, teks, messageObj). Return handle (:Disconnect()).
function Chat.OnMessage(fn)
	assert(type(fn) == "function", "Chat.OnMessage(fn): fn harus function")
	connectChat()
	local h = { fn = fn, dead = false }
	function h.Disconnect()
		h.dead = true
		local i = table.find(chatHandlers, h)
		if i then table.remove(chatHandlers, i) end
	end
	chatHandlers[#chatHandlers + 1] = h
	return h
end

function Chat.History()
	return table.clone(chatHistory)
end

------------------------------------------------------------------
-- API INTI
------------------------------------------------------------------
--- Scan packet + pasang pengamat. Mengembalikan jumlah packet terdaftar.
--- opts: { Scan = true, Learn = true }
function GB.Init(opts)
	opts = opts or {}
	if opts.Scan ~= false then scanPackets() end
	flushPending()
	if opts.Learn ~= false then installOutObserver() end
	connectChat()
	inited = true
	return #list
end

function GB.Ready() return inited and #list > 0 end

--- Daftar packet terdaftar: { {name, id, sent, received}, ... }
function GB.List()
	local out = {}
	for _, e in ipairs(list) do
		out[#out + 1] = { name = e.short or e.name, id = e.id, sent = e.sent, received = e.received }
	end
	table.sort(out, function(a, b) return (a.id or 1e9) < (b.id or 1e9) end)
	return out
end

function GB.Has(name) return resolve(name) ~= nil end

--- Buat alias: GB.Alias("punch", "act")
function GB.Alias(alias, real)
	GB.Config.Aliases[alias:lower()] = { real }
end

--- Seed/definisikan struct dari contoh data: GB.Define("enter", { world = "ABC" })
function GB.Define(name, sample)
	local e = resolve(name)
	if not e then return false, "packet tidak ditemukan" end
	e.schema = learn(e.schema, sample)
	return true
end

--- Kirim packet via send() milik game. Return ok, err.
function GB.Send(name, data)
	if not inited then GB.Init() end
	local entry = resolve(name)
	if not entry then
		return false, ("packet '%s' tidak ditemukan (lihat GB.List())"):format(tostring(name))
	end
	local send = rawget(entry.obj, "send")
	if type(send) ~= "function" then
		return false, "packet '" .. entry.name .. "' tidak punya send() di client"
	end

	local mode = GB.Config.Validate
	if mode and entry.schema and entry.schema.n >= 2 then
		local problems = {}
		check(entry.schema, data, "data", problems)
		if #problems > 0 then
			local msg = entry.short .. ": " .. table.concat(problems, "; ")
			if mode == "error" then return false, "validasi gagal: " .. msg end
			warnf("validasi %s", msg)
		end
	end

	if not take() then return false, "rate limit (GB.Config.PacketRate)" end
	if GB.Config.DryRun then
		print(("[GB][DryRun] Send(%s, %s)"):format(entry.short, lit(data)))
		return true, "dryrun"
	end
	local ok, err = pcall(send, data)
	if not ok then return false, tostring(err) end
	entry.sent += 1
	if not outHooked then pcall(observe, entry, "OUT", data) end
	return true
end

--- Dengar packet masuk. fn(data, ...). Return handle (:Disconnect()).
function GB.On(name, fn)
	assert(type(fn) == "function", "GB.On(name, fn): fn harus function")
	local h = { fn = fn, name = name, dead = false }
	function h.Disconnect()
		h.dead = true
		if h.entry then
			local i = table.find(h.entry.handlers, h)
			if i then table.remove(h.entry.handlers, i) end
		end
	end
	local e = resolve(name)
	if e then
		h.entry = e
		e.handlers[#e.handlers + 1] = h
	else
		pending[#pending + 1] = h
	end
	return h
end

function GB.Once(name, fn)
	local h
	h = GB.On(name, function(...)
		h.Disconnect()
		fn(...)
	end)
	return h
end

--- Tunggu satu packet. Return data, atau nil + "timeout".
function GB.Wait(name, timeout)
	local co, done = coroutine.running(), false
	local h
	h = GB.On(name, function(data)
		if done then return end
		done = true
		h.Disconnect()
		task.spawn(co, data)
	end)
	task.delay(timeout or 10, function()
		if done then return end
		done = true
		h.Disconnect()
		task.spawn(co, nil, "timeout")
	end)
	return coroutine.yield()
end

--- Jalankan langkah berurutan: { {"act", data, jedaDetik}, function() ... end, ... }
function GB.Sequence(steps)
	local handle = { cancelled = false }
	function handle.Cancel() handle.cancelled = true end
	task.spawn(function()
		for _, step in ipairs(steps) do
			if handle.cancelled then return end
			if type(step) == "function" then
				step()
			else
				local ok, err = GB.Send(step[1], step[2])
				if not ok then warnf("Sequence berhenti: %s", tostring(err)) return end
				if step[3] then task.wait(step[3]) end
			end
		end
	end)
	return handle
end

------------------------------------------------------------------
-- HELPER BERBASIS STRUCT YANG SUDAH DIDOKUMENTASIKAN
------------------------------------------------------------------
--- Packet act: { kind, x, y }
function GB.Act(kind, x, y)
	return GB.Send("act", { kind = kind, x = x, y = y })
end

--- Pukul tile (koordinat tile bilangan bulat). Mengirim act(kind=PunchKind) di tengah tile.
--- Jika GB.Config.PunchBuilder diisi, builder itulah yang dipakai.
function GB.Punch(tx, ty)
	assert(type(tx) == "number" and type(ty) == "number", "GB.Punch(tx, ty): angka")
	local b = GB.Config.PunchBuilder
	if b then
		local name, data = b(tx, ty)
		return GB.Send(name, data)
	end
	return GB.Act(GB.Config.PunchKind, math.floor(tx) + 0.5, math.floor(ty) + 0.5)
end

--- Packet busy: 1 / 0
function GB.SetBusy(v)
	return GB.Send("busy", v and 1 or 0)
end

--- Masuk / keluar world: struct belum dipetakan -> kirim data milikmu sendiri.
--- Lihat docs bagian "Mencari struct packet baru".
function GB.Enter(data) return GB.Send("enter", data) end
function GB.Quit(data) return GB.Send("quit", data) end

--- Listener bawaan
function GB.OnMove(fn) return GB.On("move", fn) end
function GB.OnEnter(fn) return GB.On("enter", fn) end
function GB.OnQuit(fn) return GB.On("quit", fn) end
function GB.OnNote(fn)
	return GB.On("note", function(data)
		fn(GB.ParseNote(data), data)
	end)
end

--- Uraikan packet "note" menjadi daftar { strings, isJson, json, fields }.
--- Contoh: fields.kind == "donatesay", fields.name, fields.total
function GB.ParseNote(data)
	local out = {}
	if type(data) ~= "table" or type(data.a) ~= "table" then return out end
	for _, item in ipairs(data.a) do
		local entry = { strings = item.s, isJson = item.j == true }
		if entry.isJson and type(item.s) == "table" and type(item.s[1]) == "string" then
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, item.s[1])
			if ok and type(decoded) == "table" then
				entry.json = decoded
				if type(decoded.t) == "table" then
					local d = {}
					for i = 1, #decoded.t - 1, 2 do d[tostring(decoded.t[i])] = decoded.t[i + 1] end
					entry.fields = d
				end
			end
		end
		out[#out + 1] = entry
	end
	return out
end

------------------------------------------------------------------
-- DOKUMENTASI OTOMATIS
------------------------------------------------------------------
local function packetDoc(e)
	local o = {}
	o[#o + 1] = ("## %s (id %s)\n"):format(e.short, tostring(e.id or "?"))
	o[#o + 1] = ("- Nama lengkap: `%s`"):format(e.name)
	o[#o + 1] = ("- Teramati: IN x%d, OUT x%d | dikirim via GB.Send: %d%s"):format(
		e.dirs.IN or 0, e.dirs.OUT or 0, e.sent, e.seeded and " | skema awal dari log" or "")
	if e.schema then
		o[#o + 1] = "\n| Field | Tipe | Wajib |\n|---|---|---|"
		local rows = {}
		flatten(e.schema, "", rows, true)
		for _, r in ipairs(rows) do
			o[#o + 1] = ("| `%s` | %s | %s |"):format(r.path == "" and "(data)" or r.path, r.type, r.req and "ya" or "tidak")
		end
	else
		o[#o + 1] = "\n_Belum ada sampel. Lakukan aksinya di game lalu panggil GB.Docs lagi._"
	end
	local last = e.samples[#e.samples]
	if last then
		o[#o + 1] = "\nContoh data terakhir (" .. last.dir .. "):\n```lua\n" .. lit(last.data) .. "\n```"
		o[#o + 1] = "Contoh kirim:\n```lua\nGB.Send(\"" .. e.short .. "\", " .. lit(last.data) .. ")\n```"
	end
	return table.concat(o, "\n") .. "\n"
end

--- Markdown dokumentasi packet. GB.Docs() = semua, GB.Docs("move") = satu.
function GB.Docs(name)
	if name ~= nil then
		local e = resolve(name)
		if not e then return "packet tidak ditemukan: " .. tostring(name) end
		return packetDoc(e)
	end
	local sorted = table.clone(list)
	table.sort(sorted, function(a, b) return (a.id or 1e9) < (b.id or 1e9) end)
	local out = {
		"# GrowBlox Packet Reference (auto)",
		("_PlaceId: %s | dibuat: %s | packet: %d_\n"):format(tostring(game.PlaceId), os.date("%Y-%m-%d %H:%M:%S"), #sorted),
	}
	for _, e in ipairs(sorted) do out[#out + 1] = packetDoc(e) end
	return table.concat(out, "\n")
end

--- Simpan dokumentasi ke file (writefile). Return path atau nil, err.
function GB.ExportDocs(filename)
	if not writefile then return nil, "writefile tidak didukung executor" end
	filename = filename or ("GB_Docs_" .. tostring(game.PlaceId) .. ".md")
	local ok, err = pcall(writefile, filename, GB.Docs())
	if not ok then return nil, tostring(err) end
	return filename
end

------------------------------------------------------------------
-- UNLOAD
------------------------------------------------------------------
function GB.Unload()
	for _, e in ipairs(list) do
		if e.listeners and e.master then
			local i = table.find(e.listeners, e.master)
			if i then table.remove(e.listeners, i) end
		end
		table.clear(e.handlers)
	end
	if chatConn then chatConn:Disconnect() chatConn = nil end
	table.clear(chatHandlers)
	table.clear(chatQueue)
	table.clear(byName)
	table.clear(byId)
	table.clear(byObj)
	table.clear(list)
	table.clear(pending)
	inited = false
	if getgenv then
		pcall(function()
			getgenv().GB = nil
			getgenv().__GB_observeOut = nil
		end)
	end
end

if getgenv then getgenv().GB = GB end
return GB
