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
-- EXPORT ALL SCRIPTS
------------------------------------------------------------------
TabBrowse:CreateSection("Export Semua Script")

TabBrowse:CreateButton({
	Name = "📦  Export ALL Scripts (JSON)",
	Callback = function()
		notify("Export", "Memulai scan & export semua script...", 4)
		task.spawn(function()
			-- Kumpulkan SEMUA service yang mungkin punya script
			local allServices = {}
			pcall(function()
				for _, svc in ipairs(game:GetChildren()) do
					table.insert(allServices, svc)
				end
			end)

			-- Tambahkan service tersembunyi yang mungkin tidak muncul di GetChildren
			local extraServiceNames = {
				"Workspace", "Players", "Lighting", "ReplicatedFirst",
				"ReplicatedStorage", "ServerScriptService", "ServerStorage",
				"StarterGui", "StarterPack", "StarterPlayer", "SoundService",
				"Chat", "LocalizationService", "TestService", "CoreGui",
				"CorePackages", "HttpService", "InsertService",
				"JointsService", "KeyframeSequenceProvider", "MaterialService",
				"NetworkClient", "PermissionsService", "PhysicsService",
				"PointsService", "PolicyService", "ProximityPromptService",
				"RbxAnalyticsService", "RunService", "ScriptService",
				"Selection", "SocialService", "SpawnerService",
				"StudioService", "Teams", "TeleportService",
				"TextChatService", "TextService", "TweenService",
				"UserInputService", "VRService", "VirtualInputManager",
				"MarketplaceService", "GamePassService", "BadgeService",
				"CollectionService", "ContentProvider", "ContextActionService",
				"DataStoreService", "Debris", "GuiService", "HapticService",
				"PathfindingService", "AvatarEditorService",
			}
			local serviceSet = {}
			for _, svc in ipairs(allServices) do
				serviceSet[svc] = true
			end
			for _, name in ipairs(extraServiceNames) do
				pcall(function()
					local svc = game:GetService(name)
					if svc and not serviceSet[svc] then
						table.insert(allServices, svc)
						serviceSet[svc] = true
					end
				end)
			end

			-- Juga scan PlayerGui, PlayerScripts, Backpack, Character dari LocalPlayer
			pcall(function()
				if LocalPlayer then
					local pg = LocalPlayer:FindFirstChild("PlayerGui")
					if pg and not serviceSet[pg] then
						table.insert(allServices, pg)
						serviceSet[pg] = true
					end
					local ps = LocalPlayer:FindFirstChild("PlayerScripts")
					if ps and not serviceSet[ps] then
						table.insert(allServices, ps)
						serviceSet[ps] = true
					end
					local bp = LocalPlayer:FindFirstChild("Backpack")
					if bp and not serviceSet[bp] then
						table.insert(allServices, bp)
						serviceSet[bp] = true
					end
					local ch = LocalPlayer.Character
					if ch and not serviceSet[ch] then
						table.insert(allServices, ch)
						serviceSet[ch] = true
					end
				end
			end)

			-- Scan semua script dari semua service
			local scriptData = {}
			local totalFound = 0
			local totalSourced = 0
			local visited = {}

			for _, root in ipairs(allServices) do
				pcall(function()
					local descendants = root:GetDescendants()
					for _, obj in ipairs(descendants) do
						if obj:IsA("LuaSourceContainer") and not visited[obj] then
							visited[obj] = true
							totalFound = totalFound + 1
							local fullName = ""
							pcall(function() fullName = obj:GetFullName() end)
							local className = ""
							pcall(function() className = obj.ClassName end)

							local source = nil
							local sourceStatus = "unavailable"

							-- Coba ambil source langsung
							pcall(function()
								local s = obj.Source
								if type(s) == "string" and s ~= "" then
									source = s
									sourceStatus = "raw"
								end
							end)

							-- Coba decompile jika source kosong
							if not source and decompile then
								pcall(function()
									local s = decompile(obj)
									if type(s) == "string" and s ~= "" then
										source = s
										sourceStatus = "decompiled"
									end
								end)
							end

							-- Coba getscriptbytecode jika ada
							if not source and getscriptbytecode then
								pcall(function()
									local s = getscriptbytecode(obj)
									if type(s) == "string" and s ~= "" then
										source = s
										sourceStatus = "bytecode"
									end
								end)
							end

							if source then
								totalSourced = totalSourced + 1
							end

							table.insert(scriptData, {
								path = fullName,
								class = className,
								sourceType = sourceStatus,
								source = source or ("-- [Source tidak bisa dibaca untuk: " .. fullName .. "]"),
								lineCount = source and (select(2, source:gsub("\n", "\n")) + 1) or 0,
								byteSize = source and #source or 0,
							})
						end
					end
				end)
			end

			-- Sortir berdasarkan path
			table.sort(scriptData, function(a, b) return a.path < b.path end)

			-- Build JSON secara manual (tanpa library)
			local function jsonEscape(s)
				s = s:gsub("\\", "\\\\")
				s = s:gsub('"', '\\"')
				s = s:gsub("\n", "\\n")
				s = s:gsub("\r", "\\r")
				s = s:gsub("\t", "\\t")
				s = s:gsub("\b", "\\b")
				s = s:gsub("\f", "\\f")
				-- Hapus karakter kontrol lainnya
				s = s:gsub("[\0-\31]", function(c)
					return string.format("\\u%04x", string.byte(c))
				end)
				return s
			end

			local jsonParts = {}
			table.insert(jsonParts, "{\n")
			table.insert(jsonParts, '  "exportInfo": {\n')
			table.insert(jsonParts, ('    "gameId": %s,\n'):format(tostring(game.PlaceId)))
			table.insert(jsonParts, ('    "jobId": "%s",\n'):format(jsonEscape(tostring(game.JobId))))
			local pName = "Unknown"
			pcall(function() pName = LocalPlayer.Name end)
			table.insert(jsonParts, ('    "player": "%s",\n'):format(jsonEscape(pName)))
			table.insert(jsonParts, ('    "exportDate": "%s",\n'):format(jsonEscape(os.date("%Y-%m-%d %H:%M:%S"))))
			table.insert(jsonParts, ('    "totalScriptsFound": %d,\n'):format(totalFound))
			table.insert(jsonParts, ('    "totalWithSource": %d\n'):format(totalSourced))
			table.insert(jsonParts, "  },\n")
			table.insert(jsonParts, '  "scripts": [\n')

			for i, entry in ipairs(scriptData) do
				table.insert(jsonParts, "    {\n")
				table.insert(jsonParts, ('      "path": "%s",\n'):format(jsonEscape(entry.path)))
				table.insert(jsonParts, ('      "class": "%s",\n'):format(jsonEscape(entry.class)))
				table.insert(jsonParts, ('      "sourceType": "%s",\n'):format(jsonEscape(entry.sourceType)))
				table.insert(jsonParts, ('      "lineCount": %d,\n'):format(entry.lineCount))
				table.insert(jsonParts, ('      "byteSize": %d,\n'):format(entry.byteSize))
				table.insert(jsonParts, ('      "source": "%s"\n'):format(jsonEscape(entry.source)))
				if i < #scriptData then
					table.insert(jsonParts, "    },\n")
				else
					table.insert(jsonParts, "    }\n")
				end
			end

			table.insert(jsonParts, "  ]\n")
			table.insert(jsonParts, "}")

			local jsonStr = table.concat(jsonParts)

			-- Simpan file
			local fileName = ("ScriptExport_%s_%s.json"):format(
				tostring(game.PlaceId),
				os.date("%Y%m%d_%H%M%S")
			)
			local saved = false
			local savePath = fileName

			-- Coba writefile (executor workspace)
			if writefile then
				local ok, err = pcall(writefile, fileName, jsonStr)
				if ok then
					saved = true
					savePath = "workspace/" .. fileName
				end
			end

			-- Juga copy ke clipboard sebagai backup
			local clipped = clip(jsonStr)

			if saved then
				addLog("info", ("✓ Export selesai! %d/%d script berhasil. Tersimpan di: %s"):format(totalSourced, totalFound, savePath))
				notify("Export Berhasil ✓",
					("📁 %d/%d script diekspor.\n📂 Lokasi: %s\nFormat: JSON"):format(totalSourced, totalFound, savePath),
					8)
			elseif clipped then
				addLog("info", ("✓ Export selesai! %d/%d script. JSON disalin ke clipboard (writefile tidak tersedia)."):format(totalSourced, totalFound))
				notify("Export ke Clipboard ✓",
					("📋 %d/%d script. JSON disalin ke clipboard.\n(writefile tidak tersedia, gunakan paste ke file manual)"):format(totalSourced, totalFound),
					8)
			else
				addLog("warn", ("Export: %d/%d script dikumpulkan tapi tidak bisa menyimpan file (writefile & setclipboard tidak tersedia)."):format(totalSourced, totalFound))
				notify("Export",
					("⚠ %d script ditemukan tapi tidak bisa menyimpan.\nExecutor tidak mendukung writefile/setclipboard."):format(totalFound),
					8)
			end
		end)
	end,
})

TabBrowse:CreateParagraph({
	Title = "📁 Info Export",
	Content = "Tekan tombol Export di atas untuk scan & export SEMUA script dalam game.\n\n📂 File tersimpan di: workspace/ (folder executor)\n📄 Format: JSON dengan source code lengkap\n🔍 Termasuk: Script, LocalScript, ModuleScript dari SEMUA service",
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
