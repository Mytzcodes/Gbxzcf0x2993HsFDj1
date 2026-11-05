--[[
    ╔══════════════════════════════════════════════╗
    ║        DEBUG MENU  -  Rayfield Edition       ║
    ╠══════════════════════════════════════════════╣
    ║ • Live Log (Info / Warn / Error) + filter    ║
    ║ • Editor kode multi-line (panel terpisah)    ║
    ║ • Auto Compile (cek syntax saat mengetik)    ║
    ║ • Run / Copy / Clear Log / Clear Editor      ║
    ║ • Script Browser (lihat source ke editor)    ║
    ║ • Export ALL Scripts (JSON ke workspace)      ║
    ║ • Eval expression, Inspect path, ByteNet     ║
    ║ • Statistik FPS / Ping / Memory              ║
    ║ • Minimize & Close bawaan Rayfield           ║
    ╚══════════════════════════════════════════════╝

    Tombol toggle UI : K  (bisa diganti di tab Settings / variabel TOGGLE_KEY)
    Catatan          : butuh executor dengan loadstring + HttpGet, atau Studio
                       dengan LoadStringEnabled = true (HttpGet tidak ada di Studio).
]]

------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------
local TOGGLE_KEY    = "K"
local MAX_LOGS      = 300   -- maksimal log disimpan
local VIEW_LINES    = 30    -- baris log yang tampil di menu
local AUTO_DELAY    = 0.6   -- jeda auto compile (detik)
local MAX_SCAN      = 300   -- maksimal script di dropdown

------------------------------------------------------------------
-- SERVICES
------------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local LogService        = game:GetService("LogService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats             = game:GetService("Stats")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Bersihkan instance lama jika script dijalankan 2x
if getgenv and getgenv().__DebugMenuUnload then
	pcall(getgenv().__DebugMenuUnload)
end

------------------------------------------------------------------
-- LOAD RAYFIELD
------------------------------------------------------------------
local okRF, Rayfield = pcall(function()
	return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not okRF or not Rayfield then
	warn("[DebugMenu] Gagal memuat Rayfield: " .. tostring(Rayfield))
	return
end

------------------------------------------------------------------
-- UTIL
------------------------------------------------------------------
local connections = {}
local function track(conn) table.insert(connections, conn) return conn end

local running = true
local function notify(title, content, duration)
	pcall(function()
		Rayfield:Notify({
			Title = title,
			Content = content,
			Duration = duration or 3,
			Image = 4483362458,
		})
	end)
end

local function clip(text)
	local fn = setclipboard or toclipboard or (Clipboard and Clipboard.set)
	if fn then
		local ok = pcall(fn, text)
		return ok
	end
	return false
end

-- Serialize value jadi string (dengan batas kedalaman, anti-siklik)
local function serialize(v, depth, seen)
	depth = depth or 0
	seen = seen or {}
	local t = typeof(v)
	if t == "string" then
		return string.format("%q", v)
	elseif t == "table" then
		if seen[v] then return "<cyclic>" end
		if depth >= 3 then return "{...}" end
		seen[v] = true
		local parts, n = {}, 0
		for k, val in pairs(v) do
			n += 1
			if n > 25 then table.insert(parts, "...") break end
			table.insert(parts, "[" .. serialize(k, depth + 1, seen) .. "] = " .. serialize(val, depth + 1, seen))
		end
		seen[v] = nil
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif t == "Instance" then
		return "<" .. v.ClassName .. "> " .. v:GetFullName()
	else
		return tostring(v) .. (t ~= "number" and t ~= "boolean" and t ~= "nil" and (" (" .. t .. ")") or "")
	end
end

-- Resolve "ReplicatedStorage.ByteNet.process" -> Instance
local function resolvePath(path)
	path = (path or ""):gsub("^%s+", ""):gsub("%s+$", "")
	path = path:gsub("^game%.?", "")
	if path == "" then return game end
	local current = game
	local first = true
	for part in path:gmatch("[^%.]+") do
		local nxt
		if first then
			local ok, svc = pcall(game.GetService, game, part)
			nxt = ok and svc or game:FindFirstChild(part)
			first = false
		else
			nxt = current:FindFirstChild(part)
		end
		if not nxt then return nil, "Tidak ditemukan: " .. part end
		current = nxt
	end
	return current
end

local function getSource(inst)
	if not inst or not inst:IsA("LuaSourceContainer") then
		return nil, "Bukan script/modulescript"
	end
	local ok, res = pcall(function() return inst.Source end)
	if ok and type(res) == "string" and res ~= "" then return res end
	if decompile then
		local ok2, res2 = pcall(decompile, inst)
		if ok2 and type(res2) == "string" and res2 ~= "" then return res2 end
	end
	return nil, "Source tidak bisa dibaca (butuh executor dengan decompile / izin Studio)"
end

------------------------------------------------------------------
-- LOG SYSTEM
------------------------------------------------------------------
local logs = {}
local filters = { info = true, warn = true, error = true }
local logDirty = true
local tag = { info = "INFO", warn = "WARN", error = "ERROR" }

local function addLog(level, text)
	text = tostring(text)
	table.insert(logs, {
		level = level,
		text = text,
		time = os.date("%H:%M:%S"),
	})
	if #logs > MAX_LOGS then table.remove(logs, 1) end
	logDirty = true
end

local function buildLogText(limit)
	local out = {}
	for i = #logs, 1, -1 do
		local e = logs[i]
		if filters[e.level] then
			local line = string.format("[%s][%s] %s", e.time, tag[e.level], e.text)
			if #line > 220 then line = line:sub(1, 217) .. "..." end
			table.insert(out, 1, line)
			if limit and #out >= limit then break end
		end
	end
	return #out > 0 and table.concat(out, "\n") or "(log kosong)"
end

-- Tangkap semua output game (print / warn / error)
track(LogService.MessageOut:Connect(function(message, msgType)
	local level = "info"
	if msgType == Enum.MessageType.MessageWarning then
		level = "warn"
	elseif msgType == Enum.MessageType.MessageError then
		level = "error"
	end
	addLog(level, message)
end))

------------------------------------------------------------------
-- EDITOR PANEL (multi-line, draggable)
------------------------------------------------------------------
local Editor = {}
do
	local parent
	if gethui then
		local ok, h = pcall(gethui)
		if ok then parent = h end
	end
	parent = parent or (pcall(function() return CoreGui.Name end) and CoreGui) or LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugEditorPanel"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 999
	gui.Enabled = false
	gui.Parent = parent
	Editor.Gui = gui

	local function corner(o, r)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r or 6)
		c.Parent = o
	end

	local main = Instance.new("Frame")
	main.Size = UDim2.fromOffset(540, 350)
	main.Position = UDim2.new(0.5, -270, 0.5, -175)
	main.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	main.BorderSizePixel = 0
	main.Parent = gui
	corner(main, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 75)
	stroke.Thickness = 1
	stroke.Parent = main

	-- Title bar
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 32)
	bar.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
	bar.BorderSizePixel = 0
	bar.Parent = main
	corner(bar, 10)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -80, 1, 0)
	title.Position = UDim2.fromOffset(12, 0)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(235, 235, 245)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "📝  Code Editor"
	title.Parent = bar

	local function barBtn(text, x, color, cb)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(26, 22)
		b.Position = UDim2.new(1, x, 0.5, -11)
		b.BackgroundColor3 = color
		b.Text = text
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.TextColor3 = Color3.new(1, 1, 1)
		b.AutoButtonColor = true
		b.Parent = bar
		corner(b, 5)
		b.MouseButton1Click:Connect(cb)
		return b
	end

	-- Body (bisa di-minimize)
	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, 0, 1, -32)
	body.Position = UDim2.fromOffset(0, 32)
	body.BackgroundTransparency = 1
	body.Parent = main

	local minimized = false
	barBtn("–", -62, Color3.fromRGB(90, 90, 110), function()
		minimized = not minimized
		body.Visible = not minimized
		main.Size = minimized and UDim2.fromOffset(540, 32) or UDim2.fromOffset(540, 350)
	end)
	barBtn("✕", -32, Color3.fromRGB(190, 60, 60), function() gui.Enabled = false end)

	-- Drag
	local dragging, dragStart, startPos
	track(bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, main.Position
		end
	end))
	track(UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	-- Editor area
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 0, 236)
	scroll.Position = UDim2.fromOffset(8, 8)
	scroll.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
	scroll.Parent = body
	corner(scroll, 6)

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -8, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.Position = UDim2.fromOffset(4, 4)
	box.BackgroundTransparency = 1
	box.MultiLine = true
	box.ClearTextOnFocus = false
	box.TextEditable = true
	box.TextWrapped = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.Font = Enum.Font.Code
	box.TextSize = 14
	box.TextColor3 = Color3.fromRGB(220, 225, 240)
	box.PlaceholderText = "-- Tulis / paste kode Lua di sini..."
	box.PlaceholderColor3 = Color3.fromRGB(100, 105, 125)
	box.Text = ""
	box.Parent = scroll
	local minH = Instance.new("UISizeConstraint")
	minH.MinSize = Vector2.new(0, 226)
	minH.Parent = box

	-- Status
	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -16, 0, 20)
	status.Position = UDim2.new(0, 8, 1, -26)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.TextSize = 12
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Color3.fromRGB(160, 165, 185)
	status.Text = "Siap."
	status.TextTruncate = Enum.TextTruncate.AtEnd
	status.Parent = body

	-- Buttons row
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -16, 0, 30)
	row.Position = UDim2.fromOffset(8, 252)
	row.BackgroundTransparency = 1
	row.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row

	Editor.Buttons = {}
	function Editor.addButton(name, text, color, cb)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(82, 30)
		b.BackgroundColor3 = color
		b.Text = text
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Parent = row
		corner(b, 6)
		b.MouseButton1Click:Connect(cb)
		Editor.Buttons[name] = b
		return b
	end

	function Editor.getText() return box.Text end
	function Editor.setText(t) box.Text = t or "" end
	function Editor.setStatus(msg, ok)
		status.Text = msg
		status.TextColor3 = ok == true and Color3.fromRGB(110, 220, 140)
			or ok == false and Color3.fromRGB(240, 100, 100)
			or Color3.fromRGB(160, 165, 185)
	end
	function Editor.show(v) gui.Enabled = v end
	function Editor.toggle() gui.Enabled = not gui.Enabled end
	Editor.Box = box
end

------------------------------------------------------------------
-- COMPILE / RUN
------------------------------------------------------------------
local autoCompile = true
local lastCompiled

local function compileCode(silent)
	local code = Editor.getText()
	if code:match("^%s*$") then
		Editor.setStatus("Editor kosong.", nil)
		lastCompiled = nil
		return nil
	end
	if not loadstring then
		Editor.setStatus("✗ loadstring tidak tersedia di environment ini.", false)
		return nil
	end
	local fn, err = loadstring(code, "=DebugEditor")
	if fn then
		local _, lines = code:gsub("\n", "\n")
		Editor.setStatus(("✓ Compile OK  •  %d baris  •  %d byte"):format(lines + 1, #code), true)
		lastCompiled = fn
		return fn
	else
		Editor.setStatus("✗ " .. tostring(err), false)
		if not silent then addLog("error", "[Compile] " .. tostring(err)) end
		lastCompiled = nil
		return nil
	end
end

local function runCode()
	local fn = compileCode(false)
	if not fn then
		notify("Compile Gagal", "Cek status di editor / log.", 3)
		return
	end
	addLog("info", "▶ Menjalankan kode editor...")
	task.spawn(function()
		local t0 = os.clock()
		local ok, err = xpcall(fn, function(e) return debug.traceback(tostring(e), 2) end)
		local ms = (os.clock() - t0) * 1000
		if ok then
			addLog("info", ("✓ Selesai (%.2f ms)"):format(ms))
			Editor.setStatus(("✓ Dijalankan (%.2f ms)"):format(ms), true)
		else
			addLog("error", "[Runtime] " .. tostring(err))
			Editor.setStatus("✗ Runtime error — lihat log", false)
		end
	end)
end

-- Auto compile (debounce)
local autoToken = 0
track(Editor.Box:GetPropertyChangedSignal("Text"):Connect(function()
	if not autoCompile then return end
	autoToken += 1
	local my = autoToken
	task.delay(AUTO_DELAY, function()
		if my == autoToken and running then compileCode(true) end
	end)
end))

-- Tombol di panel editor
Editor.addButton("compile", "⚙ Compile", Color3.fromRGB(60, 110, 200), function()
	if compileCode(false) then notify("Compile", "Syntax OK ✓", 2) end
end)
Editor.addButton("run", "▶ Run", Color3.fromRGB(45, 150, 80), runCode)
Editor.addButton("copy", "📋 Copy", Color3.fromRGB(120, 90, 190), function()
	local t = Editor.getText()
	if t == "" then return notify("Copy", "Editor kosong.", 2) end
	notify("Copy", clip(t) and "Kode disalin ke clipboard." or "setclipboard tidak didukung.", 2)
end)
Editor.addButton("clearEditor", "🧹 Editor", Color3.fromRGB(200, 130, 40), function()
	Editor.setText("")
	Editor.setStatus("Editor dikosongkan.", nil)
end)
Editor.addButton("clearLog", "🗑 Log", Color3.fromRGB(190, 60, 60), function()
	table.clear(logs)
	logDirty = true
	notify("Log", "Log dibersihkan.", 2)
end)

-- Helper global untuk dipakai di kode editor: dump(x)
if getgenv then
	pcall(function()
		getgenv().dump = function(...)
			local t = table.pack(...)
			local parts = {}
			for i = 1, t.n do parts[i] = serialize(t[i]) end
			print(table.concat(parts, "  "))
		end
	end)
end

------------------------------------------------------------------
-- RAYFIELD WINDOW
------------------------------------------------------------------
local Window = Rayfield:CreateWindow({
	Name = "🐞 Debug Menu",
	LoadingTitle = "Debug Menu",
	LoadingSubtitle = "Log • Editor • Compile • Run • Export",
	Theme = "Default",
	ToggleUIKeybind = TOGGLE_KEY,
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = { Enabled = false },
	KeySystem = false,
})

------------------------------------------------------------------
-- TAB 1 : LOG
------------------------------------------------------------------
local TabLog = Window:CreateTab("Log", 4483362458)
TabLog:CreateSection("Live Log")

local logPara = TabLog:CreateParagraph({ Title = "Log (0)", Content = "(log kosong)" })

TabLog:CreateSection("Kontrol")

TabLog:CreateButton({
	Name = "🗑  Clear Log",
	Callback = function()
		table.clear(logs)
		logDirty = true
		notify("Log", "Log dibersihkan.", 2)
	end,
})

TabLog:CreateButton({
	Name = "📋  Copy Semua Log",
	Callback = function()
		local out = {}
		for _, e in ipairs(logs) do
			if filters[e.level] then
				table.insert(out, string.format("[%s][%s] %s", e.time, tag[e.level], e.text))
			end
		end
		local text = table.concat(out, "\n")
		notify("Copy Log", clip(text) and ("Disalin %d baris."):format(#out) or "setclipboard tidak didukung.", 2)
	end,
})

TabLog:CreateSection("Filter")
TabLog:CreateToggle({ Name = "Tampilkan INFO",  CurrentValue = true, Callback = function(v) filters.info = v;  logDirty = true end })
TabLog:CreateToggle({ Name = "Tampilkan WARN",  CurrentValue = true, Callback = function(v) filters.warn = v;  logDirty = true end })
TabLog:CreateToggle({ Name = "Tampilkan ERROR", CurrentValue = true, Callback = function(v) filters.error = v; logDirty = true end })

------------------------------------------------------------------
-- TAB 2 : EDITOR
------------------------------------------------------------------
local TabEditor = Window:CreateTab("Editor", 4483362458)
TabEditor:CreateSection("Panel Editor Multi-line")

TabEditor:CreateButton({
	Name = "📝  Buka / Tutup Panel Editor",
	Callback = function() Editor.toggle() end,
})

TabEditor:CreateToggle({
	Name = "⚙  Auto Compile (cek syntax saat mengetik)",
	CurrentValue = true,
	Callback = function(v)
		autoCompile = v
		if v then compileCode(true) end
	end,
})

TabEditor:CreateSection("Aksi Cepat")
TabEditor:CreateButton({ Name = "⚙  Compile",           Callback = function() if compileCode(false) then notify("Compile", "Syntax OK ✓", 2) end end })
TabEditor:CreateButton({ Name = "▶  Run Kode Editor",   Callback = runCode })
TabEditor:CreateButton({
	Name = "📋  Copy Kode Editor",
	Callback = function()
		local t = Editor.getText()
		if t == "" then return notify("Copy", "Editor kosong.", 2) end
		notify("Copy", clip(t) and "Kode disalin." or "setclipboard tidak didukung.", 2)
	end,
})
TabEditor:CreateButton({ Name = "🧹  Kosongkan Editor", Callback = function() Editor.setText("") Editor.setStatus("Editor dikosongkan.", nil) end })

TabEditor:CreateSection("Quick Run (1 baris)")
TabEditor:CreateInput({
	Name = "Jalankan 1 baris kode",
	PlaceholderText = "print('halo')",
	RemoveTextAfterFocusLost = true,
	Callback = function(text)
		if text == "" then return end
		local fn, err = loadstring(text, "=QuickRun")
		if not fn then return addLog("error", "[Compile] " .. tostring(err)) end
		task.spawn(function()
			local ok, e = xpcall(fn, function(x) return debug.traceback(tostring(x), 2) end)
			if not ok then addLog("error", "[Runtime] " .. tostring(e)) end
		end)
	end,
})

TabEditor:CreateInput({
	Name = "Eval expression (tampilkan hasil)",
	PlaceholderText = "game.Players.LocalPlayer.Name",
	RemoveTextAfterFocusLost = true,
	Callback = function(text)
		if text == "" then return end
		local fn = loadstring("return " .. text, "=Eval") or loadstring(text, "=Eval")
		if not fn then return addLog("error", "[Eval] Syntax tidak valid: " .. text) end
		task.spawn(function()
			local res = table.pack(xpcall(fn, function(x) return tostring(x) end))
			if res[1] then
				local parts = {}
				for i = 2, res.n do parts[#parts + 1] = serialize(res[i]) end
				addLog("info", "= " .. (#parts > 0 and table.concat(parts, ", ") or "(nil)"))
			else
				addLog("error", "[Eval] " .. tostring(res[2]))
			end
		end)
	end,
})

------------------------------------------------------------------
-- TAB 3 : SCRIPT BROWSER
------------------------------------------------------------------
local TabBrowse = Window:CreateTab("Scripts", 4483362458)
TabBrowse:CreateSection("Cari & Lihat Source")

local scanMap, scanFilter = {}, ""

local scriptDropdown = TabBrowse:CreateDropdown({
	Name = "Daftar Script",
	Options = { "(klik Scan dulu)" },
	CurrentOption = {},
	MultipleOptions = false,
	Callback = function(opt)
		local name = type(opt) == "table" and opt[1] or opt
		local inst = scanMap[name]
		if not inst then return end
		local src, err = getSource(inst)
		if src then
			Editor.setText(src)
			Editor.show(true)
			addLog("info", "Source dimuat ke editor: " .. name)
			notify("Source Dimuat", inst.Name .. " → editor", 3)
		else
			addLog("warn", "[Source] " .. name .. " — " .. tostring(err))
			notify("Gagal", tostring(err), 4)
		end
	end,
})

TabBrowse:CreateInput({
	Name = "Filter nama (opsional)",
	PlaceholderText = "contoh: ByteNet",
	RemoveTextAfterFocusLost = false,
	Callback = function(t) scanFilter = (t or ""):lower() end,
})

TabBrowse:CreateButton({
	Name = "🔍  Scan Scripts",
	Callback = function()
		local roots = {
			ReplicatedStorage,
			game:GetService("ReplicatedFirst"),
			game:GetService("StarterPlayer"),
			game:GetService("StarterGui"),
			LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui"),
			LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts"),
			workspace,
		}
		table.clear(scanMap)
		local options = {}
		for _, root in ipairs(roots) do
			if root then
				for _, d in ipairs(root:GetDescendants()) do
					if d:IsA("LuaSourceContainer") then
						local full = d:GetFullName()
						if scanFilter == "" or full:lower():find(scanFilter, 1, true) then
							if not scanMap[full] then
								scanMap[full] = d
								table.insert(options, full)
								if #options >= MAX_SCAN then break end
							end
						end
					end
				end
			end
			if #options >= MAX_SCAN then break end
		end
		table.sort(options)
		if #options == 0 then options = { "(tidak ada hasil)" } end
		scriptDropdown:Refresh(options)
		notify("Scan", ("%d script ditemukan."):format(#scanMap and #options or 0), 3)
	end,
})

------------------------------------------------------------------
-- EXPORT ALL SCRIPTS (Structured Folders + Progress Bar)
------------------------------------------------------------------
TabBrowse:CreateSection("Export Semua Script")

local exportProgressPara = TabBrowse:CreateParagraph({
	Title = "📦 Export Status",
	Content = "Tekan tombol Export untuk mulai.\n\n📂 Hasil: workspace/ScriptExport_[PlaceId]/\n├── Decompiled/  → source .lua berhasil di-decompile\n├── Raw/         → bytecode/encrypted gagal decompile\n└── _index.json  → daftar lengkap semua script",
})

local exportRunning = false

-- Helper: buat progress bar text ██░░
local function makeProgressBar(current, total, width)
	width = width or 20
	local ratio = total > 0 and (current / total) or 0
	local filled = math.floor(ratio * width + 0.5)
	local empty = width - filled
	local pct = math.floor(ratio * 100 + 0.5)
	return string.rep("█", filled) .. string.rep("░", empty) .. (" %d%%"):format(pct)
end

-- Helper: sanitize nama file (hapus karakter ilegal)
local function sanitizeName(name)
	name = name:gsub("[<>:\"/\\|%?%*]", "_")
	name = name:gsub("%.+$", "")
	if name == "" then name = "_unnamed" end
	return name
end

-- Helper: konversi full path Instance → folder path relatif
local function instanceToFolderPath(fullName, baseName)
	-- "game.Workspace.Folder.Script" → "Workspace/Folder"
	local parts = {}
	for seg in fullName:gmatch("[^%.]+") do
		table.insert(parts, sanitizeName(seg))
	end
	-- Hapus "game" di awal jika ada
	if parts[1] and parts[1]:lower() == "game" then
		table.remove(parts, 1)
	end
	-- Hapus nama script sendiri (elemen terakhir) supaya jadi folder path
	if #parts > 0 then
		table.remove(parts, #parts)
	end
	local folder = table.concat(parts, "/")
	return folder ~= "" and (baseName .. "/" .. folder) or baseName
end

-- Helper: buat folder rekursif (jika executor support)
local function ensureFolder(path)
	if not makefolder then return end
	local parts = {}
	for seg in path:gmatch("[^/\\]+") do
		table.insert(parts, seg)
		local p = table.concat(parts, "/")
		pcall(function()
			if not isfolder(p) then
				makefolder(p)
			end
		end)
	end
end

-- JSON escape
local function jsonEscape(s)
	if type(s) ~= "string" then s = tostring(s) end
	s = s:gsub("\\", "\\\\")
	s = s:gsub('"', '\\"')
	s = s:gsub("\n", "\\n")
	s = s:gsub("\r", "\\r")
	s = s:gsub("\t", "\\t")
	s = s:gsub("\b", "\\b")
	s = s:gsub("\f", "\\f")
	s = s:gsub("[\0-\31]", function(c)
		return string.format("\\u%04x", string.byte(c))
	end)
	return s
end

TabBrowse:CreateButton({
	Name = "📦  Export ALL Scripts (Folder + JSON)",
	Callback = function()
		if exportRunning then
			notify("Export", "Export sedang berjalan, tunggu selesai.", 3)
			return
		end
		exportRunning = true
		notify("Export", "Memulai export script...\nGame TIDAK akan freeze.", 4)

		task.spawn(function()
			local t0 = os.clock()

			-- Update progress
			local function setProgress(msg)
				pcall(function()
					exportProgressPara:Set({
						Title = "📦 Export — Sedang Berjalan...",
						Content = msg,
					})
				end)
			end

			setProgress("⏳ Mengumpulkan daftar service...")
			task.wait()

			-------------------------------------------------------
			-- FASE 1: Kumpulkan service yang PENTING saja
			-------------------------------------------------------
			local serviceTargets = {
				{ name = "Workspace",          svc = nil },
				{ name = "ReplicatedStorage",  svc = nil },
				{ name = "ReplicatedFirst",    svc = nil },
				{ name = "StarterGui",         svc = nil },
				{ name = "StarterPack",        svc = nil },
				{ name = "StarterPlayer",      svc = nil },
				{ name = "Lighting",           svc = nil },
				{ name = "SoundService",       svc = nil },
				{ name = "Chat",               svc = nil },
				{ name = "TextChatService",    svc = nil },
				{ name = "Teams",              svc = nil },
				{ name = "CoreGui",            svc = nil },
				{ name = "CorePackages",       svc = nil },
				{ name = "Players",            svc = nil },
			}
			for i, entry in ipairs(serviceTargets) do
				pcall(function()
					entry.svc = game:GetService(entry.name)
				end)
			end
			-- Tambahkan PlayerGui, PlayerScripts, Backpack
			pcall(function()
				if LocalPlayer then
					local pg = LocalPlayer:FindFirstChild("PlayerGui")
					if pg then table.insert(serviceTargets, { name = "PlayerGui", svc = pg }) end
					local ps = LocalPlayer:FindFirstChild("PlayerScripts")
					if ps then table.insert(serviceTargets, { name = "PlayerScripts", svc = ps }) end
					local bp = LocalPlayer:FindFirstChild("Backpack")
					if bp then table.insert(serviceTargets, { name = "Backpack", svc = bp }) end
				end
			end)
			-- Filter yang valid
			local validServices = {}
			for _, entry in ipairs(serviceTargets) do
				if entry.svc then
					table.insert(validServices, entry)
				end
			end

			setProgress(("✅ %d service ditemukan.\n⏳ Menghitung total script..."):format(#validServices))
			task.wait()

			-------------------------------------------------------
			-- FASE 2: Hitung total script dulu (untuk progress bar)
			-------------------------------------------------------
			local allScriptInstances = {}
			local visited = {}
			local totalCount = 0

			for si, entry in ipairs(validServices) do
				pcall(function()
					local descs = entry.svc:GetDescendants()
					for _, obj in ipairs(descs) do
						if obj:IsA("LuaSourceContainer") and not visited[obj] then
							visited[obj] = true
							totalCount = totalCount + 1
							table.insert(allScriptInstances, obj)
						end
					end
				end)
				-- Yield setiap service supaya tidak freeze
				if si % 3 == 0 then
					setProgress(("⏳ Scanning service %d/%d...\n🔍 %d script ditemukan sejauh ini"):format(si, #validServices, totalCount))
					task.wait()
				end
			end

			setProgress(("✅ Scan selesai: %d script ditemukan.\n⏳ Memulai decompile & export..."):format(totalCount))
			task.wait()

			if totalCount == 0 then
				setProgress("⚠ Tidak ada script ditemukan di game ini.")
				exportRunning = false
				notify("Export", "Tidak ada script ditemukan.", 4)
				return
			end

			-------------------------------------------------------
			-- FASE 3: Decompile buffer + export per-file
			-------------------------------------------------------
			local baseFolder = ("ScriptExport_%s"):format(tostring(game.PlaceId))
			local decompFolder = baseFolder .. "/Decompiled"
			local rawFolder = baseFolder .. "/Raw"

			local hasWritefile = writefile ~= nil
			if hasWritefile then
				pcall(function() ensureFolder(baseFolder) end)
				pcall(function() ensureFolder(decompFolder) end)
				pcall(function() ensureFolder(rawFolder) end)
			end

			local indexData = {}
			local totalDecompiled = 0
			local totalRaw = 0
			local totalFailed = 0
			local BATCH_SIZE = 5  -- yield setiap 5 script (anti-freeze)
			local filesSaved = 0

			for idx, obj in ipairs(allScriptInstances) do
				local fullName = ""
				pcall(function() fullName = obj:GetFullName() end)
				local className = ""
				pcall(function() className = obj.ClassName end)
				local scriptName = ""
				pcall(function() scriptName = obj.Name end)

				local source = nil
				local sourceType = "failed"
				local rawBytes = nil

				-- 1) Coba .Source langsung
				pcall(function()
					local s = obj.Source
					if type(s) == "string" and s ~= "" then
						source = s
						sourceType = "source"
					end
				end)

				-- 2) Coba decompile
				if not source and decompile then
					pcall(function()
						local s = decompile(obj)
						if type(s) == "string" and s ~= "" then
							source = s
							sourceType = "decompiled"
						end
					end)
				end

				-- 3) Coba getscriptbytecode (simpan di Raw/)
				if getscriptbytecode then
					pcall(function()
						local b = getscriptbytecode(obj)
						if type(b) == "string" and b ~= "" then
							rawBytes = b
							if not source then
								sourceType = "bytecode_only"
							end
						end
					end)
				end

				-- 4) Coba dumpstring sebagai fallback
				if not source and not rawBytes and dumpstring then
					pcall(function()
						local s = dumpstring(obj)
						if type(s) == "string" and s ~= "" then
							rawBytes = s
							sourceType = "dumpstring"
						end
					end)
				end

				-- Tentukan file path relatif
				local safeName = sanitizeName(scriptName)
				local relPath = fullName:gsub("^game%.?", ""):gsub("%.", "/")
				local safeRelPath = ""
				for seg in relPath:gmatch("[^/]+") do
					if safeRelPath ~= "" then safeRelPath = safeRelPath .. "/" end
					safeRelPath = safeRelPath .. sanitizeName(seg)
				end
				if safeRelPath == "" then safeRelPath = safeName end

				-- Simpan file
				local decompPath = nil
				local rawPath = nil

				if hasWritefile then
					-- Simpan decompiled/source ke Decompiled/
					if source then
						local fp = decompFolder .. "/" .. safeRelPath .. ".lua"
						local folderPart = fp:match("(.+)/[^/]+$")
						if folderPart then pcall(function() ensureFolder(folderPart) end) end
						local ok = pcall(writefile, fp, source)
						if ok then
							decompPath = fp
							totalDecompiled = totalDecompiled + 1
							filesSaved = filesSaved + 1
						end
					end

					-- Simpan raw/bytecode ke Raw/ (selalu, sebagai backup)
					if rawBytes then
						local fp = rawFolder .. "/" .. safeRelPath .. ".bin"
						local folderPart = fp:match("(.+)/[^/]+$")
						if folderPart then pcall(function() ensureFolder(folderPart) end) end
						local ok = pcall(writefile, fp, rawBytes)
						if ok then
							rawPath = fp
							totalRaw = totalRaw + 1
							filesSaved = filesSaved + 1
						end
					elseif source then
						-- Jika tidak ada bytecode, simpan source juga di Raw/ sebagai .lua
						local fp = rawFolder .. "/" .. safeRelPath .. ".lua"
						local folderPart = fp:match("(.+)/[^/]+$")
						if folderPart then pcall(function() ensureFolder(folderPart) end) end
						local ok = pcall(writefile, fp, source)
						if ok then
							rawPath = fp
							totalRaw = totalRaw + 1
							filesSaved = filesSaved + 1
						end
					end

					if not source and not rawBytes then
						totalFailed = totalFailed + 1
					end
				else
					-- Tidak ada writefile, hanya kumpulkan data
					if source then
						totalDecompiled = totalDecompiled + 1
					elseif rawBytes then
						totalRaw = totalRaw + 1
					else
						totalFailed = totalFailed + 1
					end
				end

				-- Kumpulkan untuk index JSON
				local lines = 0
				local bytes = 0
				if source then
					lines = select(2, source:gsub("\n", "\n")) + 1
					bytes = #source
				elseif rawBytes then
					bytes = #rawBytes
				end

				table.insert(indexData, {
					path = fullName,
					class = className,
					sourceType = sourceType,
					decompFile = decompPath,
					rawFile = rawPath,
					lineCount = lines,
					byteSize = bytes,
					source = source or nil,
				})

				-- Update progress bar setiap BATCH_SIZE script
				if idx % BATCH_SIZE == 0 or idx == totalCount then
					local bar = makeProgressBar(idx, totalCount)
					local elapsed = os.clock() - t0
					local eta = totalCount > 0 and (elapsed / idx * (totalCount - idx)) or 0
					setProgress(
						("[%s]\n\n📊 %d / %d script diproses\n✅ Decompiled: %d  |  📁 Raw: %d  |  ❌ Gagal: %d\n⏱ Elapsed: %.1fs  |  ETA: %.1fs"):format(
							bar, idx, totalCount,
							totalDecompiled, totalRaw, totalFailed,
							elapsed, eta
						)
					)
					task.wait()
				end
			end

			-------------------------------------------------------
			-- FASE 4: Buat _index.json
			-------------------------------------------------------
			setProgress(("⏳ Membuat _index.json... (%d script)"):format(#indexData))
			task.wait()

			local jsonParts = {}
			table.insert(jsonParts, "{\n")
			table.insert(jsonParts, '  "exportInfo": {\n')
			table.insert(jsonParts, ('    "gameId": %s,\n'):format(tostring(game.PlaceId)))
			table.insert(jsonParts, ('    "jobId": "%s",\n'):format(jsonEscape(tostring(game.JobId))))
			local pName = "Unknown"
			pcall(function() pName = LocalPlayer.Name end)
			table.insert(jsonParts, ('    "player": "%s",\n'):format(jsonEscape(pName)))
			table.insert(jsonParts, ('    "exportDate": "%s",\n'):format(jsonEscape(os.date("%Y-%m-%d %H:%M:%S"))))
			table.insert(jsonParts, ('    "totalScripts": %d,\n'):format(totalCount))
			table.insert(jsonParts, ('    "totalDecompiled": %d,\n'):format(totalDecompiled))
			table.insert(jsonParts, ('    "totalRaw": %d,\n'):format(totalRaw))
			table.insert(jsonParts, ('    "totalFailed": %d\n'):format(totalFailed))
			table.insert(jsonParts, "  },\n")
			table.insert(jsonParts, '  "scripts": [\n')

			for i, entry in ipairs(indexData) do
				table.insert(jsonParts, "    {\n")
				table.insert(jsonParts, ('      "path": "%s",\n'):format(jsonEscape(entry.path)))
				table.insert(jsonParts, ('      "class": "%s",\n'):format(jsonEscape(entry.class)))
				table.insert(jsonParts, ('      "sourceType": "%s",\n'):format(jsonEscape(entry.sourceType)))
				if entry.decompFile then
					table.insert(jsonParts, ('      "decompFile": "%s",\n'):format(jsonEscape(entry.decompFile)))
				end
				if entry.rawFile then
					table.insert(jsonParts, ('      "rawFile": "%s",\n'):format(jsonEscape(entry.rawFile)))
				end
				table.insert(jsonParts, ('      "lineCount": %d,\n'):format(entry.lineCount))
				table.insert(jsonParts, ('      "byteSize": %d\n'):format(entry.byteSize))
				if i < #indexData then
					table.insert(jsonParts, "    },\n")
				else
					table.insert(jsonParts, "    }\n")
				end

				-- Yield setiap 50 entri saat build JSON
				if i % 50 == 0 then task.wait() end
			end

			table.insert(jsonParts, "  ]\n")
			table.insert(jsonParts, "}")

			local jsonStr = table.concat(jsonParts)
			task.wait()

			-- Simpan index
			local indexSaved = false
			if hasWritefile then
				local ok = pcall(writefile, baseFolder .. "/_index.json", jsonStr)
				indexSaved = ok
			end

			-- Jika tidak bisa writefile, coba clipboard
			if not hasWritefile then
				clip(jsonStr)
			end

			local elapsed = os.clock() - t0

			-------------------------------------------------------
			-- FASE 5: Tampilkan hasil akhir
			-------------------------------------------------------
			local resultMsg
			if hasWritefile then
				resultMsg = (
					"✅ EXPORT SELESAI! (%.1f detik)\n\n" ..
					"📂 Lokasi: workspace/%s/\n" ..
					"├── Decompiled/  → %d file .lua\n" ..
					"├── Raw/         → %d file (bytecode/backup)\n" ..
					"└── _index.json  → daftar %d script\n\n" ..
					"❌ Gagal decompile: %d script\n" ..
					"💾 Total file tersimpan: %d"
				):format(
					elapsed,
					baseFolder,
					totalDecompiled,
					totalRaw,
					totalCount,
					totalFailed,
					filesSaved + (indexSaved and 1 or 0)
				)
			else
				resultMsg = (
					"✅ EXPORT SELESAI! (%.1f detik)\n\n" ..
					"⚠ writefile tidak tersedia!\n" ..
					"📋 _index.json disalin ke clipboard.\n" ..
					"📊 %d script | ✅ %d decompiled | ❌ %d gagal"
				):format(elapsed, totalCount, totalDecompiled, totalFailed)
			end

			pcall(function()
				exportProgressPara:Set({
					Title = "📦 Export — Selesai ✅",
					Content = resultMsg,
				})
			end)

			addLog("info", ("✓ Export selesai! %d script, %d decompiled, %d raw, %d gagal (%.1fs)"):format(
				totalCount, totalDecompiled, totalRaw, totalFailed, elapsed
			))
			notify("Export Berhasil ✓",
				("📁 %d script diekspor ke workspace/%s/\n✅ %d decompiled | 📁 %d raw | ❌ %d gagal"):format(
					totalCount, baseFolder, totalDecompiled, totalRaw, totalFailed
				), 10)

			exportRunning = false
		end)
	end,
})

TabBrowse:CreateButton({
	Name = "🔄  Reset Progress",
	Callback = function()
		if exportRunning then
			notify("Export", "Tunggu export selesai dulu.", 2)
			return
		end
		pcall(function()
			exportProgressPara:Set({
				Title = "📦 Export Status",
				Content = "Tekan tombol Export untuk mulai.\n\n📂 Hasil: workspace/ScriptExport_[PlaceId]/\n├── Decompiled/  → source .lua berhasil di-decompile\n├── Raw/         → bytecode/encrypted gagal decompile\n└── _index.json  → daftar lengkap semua script",
			})
		end)
	end,
})

------------------------------------------------------------------
-- LOAD DARI PATH
------------------------------------------------------------------
TabBrowse:CreateSection("Load dari Path")
TabBrowse:CreateInput({
	Name = "Path script → Editor",
	PlaceholderText = "ReplicatedStorage.ByteNet.process.client",
	RemoveTextAfterFocusLost = false,
	Callback = function(path)
		if path == "" then return end
		local inst, err = resolvePath(path)
		if not inst then return notify("Gagal", tostring(err), 3) end
		local src, e2 = getSource(inst)
		if src then
			Editor.setText(src)
			Editor.show(true)
			addLog("info", "Source dimuat: " .. inst:GetFullName())
			notify("Source Dimuat", inst.Name .. " → editor", 3)
		else
			addLog("warn", "[Source] " .. tostring(e2))
			notify("Gagal", tostring(e2), 4)
		end
	end,
})

------------------------------------------------------------------
-- TAB 4 : TOOLS
------------------------------------------------------------------
local TabTools = Window:CreateTab("Tools", 4483362458)
TabTools:CreateSection("Statistik Realtime")
local statsPara = TabTools:CreateParagraph({ Title = "Performa", Content = "Memuat..." })

TabTools:CreateSection("Inspect Instance")
TabTools:CreateInput({
	Name = "Path instance → tampilkan children",
	PlaceholderText = "ReplicatedStorage.ByteNet",
	RemoveTextAfterFocusLost = false,
	Callback = function(path)
		local inst, err = resolvePath(path)
		if not inst then return addLog("error", "[Inspect] " .. tostring(err)) end
		local kids = inst:GetChildren()
		addLog("info", ("[Inspect] %s <%s> — %d children"):format(inst:GetFullName(), inst.ClassName, #kids))
		for i, k in ipairs(kids) do
			if i > 40 then addLog("info", "  ... dan " .. (#kids - 40) .. " lainnya") break end
			addLog("info", ("  • %s <%s>"):format(k.Name, k.ClassName))
		end
	end,
})

TabTools:CreateSection("ByteNet")
TabTools:CreateButton({
	Name = "🔎  Cek Library ByteNet",
	Callback = function()
		local bn = ReplicatedStorage:FindFirstChild("ByteNet")
		if not bn then
			addLog("warn", "[ByteNet] Tidak ditemukan di ReplicatedStorage.")
			return notify("ByteNet", "Tidak ditemukan.", 3)
		end
		local ok, lib = pcall(require, bn)
		if not ok then
			addLog("error", "[ByteNet] require gagal: " .. tostring(lib))
			return
		end
		local keys = {}
		for k, v in pairs(lib) do table.insert(keys, tostring(k) .. " <" .. typeof(v) .. ">") end
		table.sort(keys)
		addLog("info", "[ByteNet] Export (" .. #keys .. "): " .. table.concat(keys, ", "))
		notify("ByteNet", "Terdeteksi " .. #keys .. " export. Lihat log.", 3)
	end,
})

TabTools:CreateSection("Utilitas")
TabTools:CreateButton({
	Name = "📸  Info Game ke Log",
	Callback = function()
		addLog("info", ("PlaceId: %s | JobId: %s"):format(tostring(game.PlaceId), tostring(game.JobId)))
		addLog("info", ("Player: %s (%d) | Pemain: %d"):format(LocalPlayer.Name, LocalPlayer.UserId, #Players:GetPlayers()))
	end,
})

------------------------------------------------------------------
-- TAB 5 : SETTINGS
------------------------------------------------------------------
local TabSet = Window:CreateTab("Settings", 4483362458)
TabSet:CreateSection("Menu")
TabSet:CreateParagraph({
	Title = "Tips",
	Content = "• Tombol – / ✕ pada window Rayfield untuk minimize / tutup.\n• Tekan [" .. TOGGLE_KEY .. "] untuk sembunyi/tampil menu.\n• Panel Editor punya tombol – dan ✕ sendiri, dan bisa digeser.\n• Di kode editor tersedia fungsi dump(...) untuk print tabel.",
})

local function unload()
	if not running then return end
	running = false
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	pcall(function() Editor.Gui:Destroy() end)
	pcall(function() Rayfield:Destroy() end)
	if getgenv then
		pcall(function()
			getgenv().__DebugMenuUnload = nil
			getgenv().dump = nil
		end)
	end
end
if getgenv then getgenv().__DebugMenuUnload = unload end

TabSet:CreateButton({ Name = "❌  Unload Debug Menu (tutup semua)", Callback = unload })

------------------------------------------------------------------
-- BACKGROUND LOOP (update log, stats, deteksi close Rayfield)
------------------------------------------------------------------
local frames, fps = 0, 0
track(RunService.RenderStepped:Connect(function() frames += 1 end))

local function findRayfieldGui()
	local roots = {}
	if gethui then
		local ok, h = pcall(gethui)
		if ok and h then table.insert(roots, h) end
	end
	table.insert(roots, CoreGui)
	for _, r in ipairs(roots) do
		local ok, g = pcall(function() return r:FindFirstChild("Rayfield") end)
		if ok and g then return g end
	end
end
local rfGui = findRayfieldGui()

task.spawn(function()
	local lastFpsT = os.clock()
	local lastStats = 0
	while running do
		-- hitung FPS
		local now = os.clock()
		if now - lastFpsT >= 1 then
			fps = math.floor(frames / (now - lastFpsT) + 0.5)
			frames, lastFpsT = 0, now
		end

		-- refresh log
		if logDirty then
			logDirty = false
			pcall(function()
				logPara:Set({
					Title = ("Log (%d)"):format(#logs),
					Content = buildLogText(VIEW_LINES),
				})
			end)
		end

		-- refresh statistik tiap 1 detik
		if now - lastStats >= 1 then
			lastStats = now
			local ping, mem = "N/A", "N/A"
			pcall(function() ping = ("%d ms"):format(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
			pcall(function() mem = ("%.0f MB"):format(Stats:GetTotalMemoryUsageMb()) end)
			pcall(function()
				statsPara:Set({
					Title = "Performa",
					Content = ("FPS: %d\nPing: %s\nMemory: %s\nLog: %d entri"):format(fps, ping, mem, #logs),
				})
			end)
		end

		-- jika Rayfield ditutup lewat tombol ✕, bersihkan panel editor juga
		if rfGui and not rfGui.Parent then
			unload()
			break
		end

		task.wait(0.4)
	end
end)

addLog("info", "Debug Menu aktif. Tekan [" .. TOGGLE_KEY .. "] untuk sembunyi/tampil.")
notify("Debug Menu", "Siap dipakai! Buka tab Editor untuk mulai.", 4)
