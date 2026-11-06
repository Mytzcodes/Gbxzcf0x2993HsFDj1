--[[
    XnS_Load.lua  —  NXroENinD_DPcKage | UI Layer (Rayfield)  v2.0.0
    Pair : LX&80.lua (backend v2.0.0)
    Load : loadstring(game:HttpGet("RAW_URL"))()

    TAB: MISC · SPAM · AUTO FARM · TELEPORT · MODS LOG · ITEM LIST
         ROULETTE · PROFILE · TROLL · ANTI-DETECT
]]

-- ══════════════════════════════════════════════════════════════
--  BOOTSTRAP
-- ══════════════════════════════════════════════════════════════
local RAW_LX80 = "https://raw.githubusercontent.com/Mytzcodes/Gbxzcf0x2993HsFDj1/refs/heads/main/LX%2680.lua"
local RAW_RF   = "https://sirius.menu/rayfield"

local Rayfield
do
    local ok, err = pcall(function()
        Rayfield = loadstring(game:HttpGet(RAW_RF, true))()
    end)
    if not ok or not Rayfield then
        warn("[XnS] Rayfield gagal: " .. tostring(err))
        return
    end
end

local LX
do
    local ok, err = pcall(function()
        LX = loadstring(game:HttpGet(RAW_LX80, true))()
    end)
    if not ok or type(LX) ~= "table" then
        warn("[XnS] LX&80 gagal: " .. tostring(err))
        local noop = function() end
        LX = {
            State = {
                godmode=false, antiCheckpoint=false, fly=false, flySpeed=24,
                zoom=1, zoomUnlock=false, zoomMin=0.2, zoomMax=5,
                performance=false, renderScale=0.75, loadingScale=0.5,
                spamRunning=false, spamMsg="", spamDelay=1.5, spamRandom=false, spamColor="w",
                pnbRunning=false, pnbGrid={}, pnbSeedId=nil, pnbDelay=0.35, pnbAutoCollect=true,
                dfRunning=false, dfDelay=0.4, clearRunning=false, clearDelay=0.5, clearBg=true,
                tpMethod=1, modWatchOn=false, modAction="SLEEP", modLog={}, modCount=0,
                antiDetect=false, unlockAll=false, voiceAll=false, nametag=nil,
                namedStyle="default", namedColor="w", instantSpin=true, autoSpin=false,
                spinDelay=2.5, spinX=nil, spinY=nil, loaded=false,
            },
            Pos = { x=0, y=0, tx=0, ty=0, hp=5, maxHp=5, dead=false, loaded=false },
            ChatStats = { sent=0, failed=0, last="" },
            COLORS = {
                White="w", Red="4", Green="2", Yellow="9", Cyan="e", Aqua="c",
                Orange="8", Pink="#", Purple="m", Blue="q", Black="b", Gray="s",
            },
            Init=noop, IsReady=function() return false end,
            GetGameTable=function() return nil end, GetPlayerList=function() return {} end,
            SendChat=function() return false end, Spam_Start=noop, Spam_Stop=noop,
            Godmode_On=noop, Godmode_Off=noop,
            AntiCheckpoint_On=noop, AntiCheckpoint_Off=noop,
            Fly_On=noop, Fly_Off=noop, SetFlySpeed=noop,
            SetZoom=noop, ZoomIn=noop, ZoomOut=noop, SetZoomLimits=noop,
            ZoomUnlock_On=noop, ZoomUnlock_Off=noop,
            Performance_On=noop, Performance_Off=noop,
            SetRenderScale=noop, SetLoadingScale=noop,
            PNB_SetBase=function() return { x = 0, y = 0 } end,
            PNB_Start=noop, PNB_Stop=noop, DF_Start=noop, DF_Stop=noop,
            Clear_Start=noop, Clear_Stop=noop,
            Teleport=function() return false end,
            TeleportWorld=function() return false end,
            TeleportToPlayer=function() return false end,
            FastSpin_SetInstant=noop, FindSpin=function() return nil end,
            FastSpin_Once=function() return false end,
            FastSpin_HookResults=function() return noop end,
            AutoSpin_Start=noop, AutoSpin_Stop=noop,
            ModWatch_On=noop, ModWatch_Off=noop,
            SetNametag=function() return false end, RemoveNametag=noop, WearVisual=noop,
            VoiceAll_On=noop, VoiceAll_Off=noop,
            AnnounceAll=function() return false end,
            AntiDetect_On=noop, AntiDetect_Off=noop,
            UnlockAll_On=noop, UnlockAll_Off=noop,
            TryDrop=function() return false, "backend tidak termuat" end,
            GetItemDB=function() return {} end,
            GetItemInfo=function() return nil end,
            SearchItems=function() return {} end,
            MakeItemIcon=function() return nil end,
            SetItemIcon=function() return false end,
        }
    end
    pcall(function() LX.Init() end)
end

-- ── Services ─────────────────────────────────────────────────
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local LP           = Players.LocalPlayer
local PG           = LP:WaitForChild("PlayerGui")

local STATE  = LX.State
local COLORS = LX.COLORS or { White = "w" }

local COLOR_NAMES = { "White", "Red", "Green", "Yellow", "Cyan", "Aqua", "Orange", "Pink", "Purple", "Blue", "Black", "Gray" }
local function colorCode(name)
    return COLORS[name] or "w"
end

-- ══════════════════════════════════════════════════════════════
--  RAYFIELD WINDOW
-- ══════════════════════════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name              = "NXroENinD  |  v2.0",
    LoadingTitle      = "NX Hub",
    LoadingSubtitle   = "GrowBlox Suite · Deep Sky",
    ConfigurationSaving = {
        Enabled    = false,
        FolderName = "NX_Config",
        FileName   = "XnS_Profile_v2",
    },
    Discord = { Enabled = false },
    KeySystem = false,
})

pcall(function()
    Rayfield:SetCustomWindowTheme({
        TextColor          = Color3.fromRGB(240, 248, 255),
        Background         = Color3.fromRGB(8, 18, 32),
        Topbar             = Color3.fromRGB(0, 80, 140),
        Shadow             = Color3.fromRGB(0, 40, 80),
        NotificationBackground = Color3.fromRGB(0, 60, 110),
        NotificationActionsBackground = Color3.fromRGB(0, 80, 140),
        TabBackground      = Color3.fromRGB(5, 14, 26),
        TabStroke          = Color3.fromRGB(0, 110, 200),
        TabBackgroundSelected = Color3.fromRGB(0, 100, 180),
        TabTextColor       = Color3.fromRGB(180, 220, 255),
        SelectedTabTextColor = Color3.fromRGB(240, 248, 255),
        ElementBackground  = Color3.fromRGB(10, 25, 48),
        ElementBackgroundHover = Color3.fromRGB(0, 60, 110),
        SecondaryElementBackground = Color3.fromRGB(8, 20, 40),
        ElementStroke      = Color3.fromRGB(0, 100, 180),
        SecondaryElementStroke = Color3.fromRGB(0, 70, 130),
        SliderBackground   = Color3.fromRGB(0, 40, 80),
        SliderProgress     = Color3.fromRGB(0, 150, 255),
        SliderStroke       = Color3.fromRGB(0, 110, 200),
        ToggleBackground   = Color3.fromRGB(0, 40, 80),
        ToggleEnabled      = Color3.fromRGB(0, 150, 255),
        ToggleDisabled     = Color3.fromRGB(40, 60, 90),
        ToggleEnabledStroke = Color3.fromRGB(0, 180, 255),
        ToggleDisabledStroke = Color3.fromRGB(50, 80, 120),
        ToggleEnabledInner  = Color3.fromRGB(240, 248, 255),
        ToggleDisabledInner = Color3.fromRGB(100, 130, 160),
        InputBackground    = Color3.fromRGB(5, 18, 36),
        InputStroke        = Color3.fromRGB(0, 100, 180),
        PlaceholderColor   = Color3.fromRGB(80, 130, 180),
    })
end)

local function note(title, content, dur)
    pcall(function()
        Rayfield:Notify({ Title = title, Content = content, Duration = dur or 3 })
    end)
end

local function setLabel(lbl, txt)
    if lbl then pcall(function() lbl:Set(txt) end) end
end

local function setPara(para, txt)
    if para then pcall(function() para:Set(txt) end) end
end

local function setOptions(dd, opts)
    if not dd then return end
    pcall(function() dd:Refresh(opts) end)
    pcall(function() dd:Set(opts) end)
end

local function copyText(txt)
    txt = tostring(txt or "")
    if type(setclipboard) == "function" then
        local ok = pcall(setclipboard, txt)
        if ok then return true end
    end
    if type(toClipboard) == "function" then
        local ok = pcall(toClipboard, txt)
        if ok then return true end
    end
    return false
end

-- ══════════════════════════════════════════════════════════════
--  TAB · MISC
-- ══════════════════════════════════════════════════════════════
local TabMisc = Window:CreateTab("⚙  MISC", nil)

TabMisc:CreateSection("Nyawa")
TabMisc:CreateToggle({
    Name         = "No Death (Godmode)",
    CurrentValue = false,
    Flag         = "v2_godmode",
    Callback     = function(v)
        if v then LX.Godmode_On() else LX.Godmode_Off() end
        note("GODMODE", v and "ON — lava/spike/laser tidak mengurangi HP" or "OFF", 2)
    end,
})

TabMisc:CreateToggle({
    Name         = "Anti Checkpoint",
    CurrentValue = false,
    Flag         = "v2_anticp",
    Callback     = function(v)
        if v then LX.AntiCheckpoint_On() else LX.AntiCheckpoint_Off() end
    end,
})

TabMisc:CreateSection("Terbang")
TabMisc:CreateToggle({
    Name         = "Fly (WASD / Space / Shift)",
    CurrentValue = false,
    Flag         = "v2_fly",
    Callback     = function(v)
        if v then LX.Fly_On(STATE.flySpeed) else LX.Fly_Off() end
        note("FLY", v and "ON — WASD terbang, Space naik, Shift turun" or "OFF — gravitasi aktif lagi", 2)
    end,
})

TabMisc:CreateSlider({
    Name         = "Fly Speed",
    Range        = { 4, 120 },
    Increment    = 1,
    Suffix       = " stud/s",
    CurrentValue = 24,
    Flag         = "v2_flyspeed",
    Callback     = function(v)
        STATE.flySpeed = v
        LX.SetFlySpeed(v)
    end,
})

TabMisc:CreateSection("Zoom")
local zoomMinVal, zoomMaxVal = 0.2, 5
local zoomStatus = TabMisc:CreateLabel("Zoom: —  |  Unlock: OFF")

TabMisc:CreateToggle({
    Name         = "Zoom Unlock (buka batas)",
    CurrentValue = false,
    Flag         = "v2_zoomunlock",
    Callback     = function(v)
        if v then
            LX.ZoomUnlock_On()
            LX.SetZoomLimits(zoomMinVal, zoomMaxVal)
        else
            LX.ZoomUnlock_Off()
        end
        note("ZOOM", v and "Unlock ON — batas zoom dibuka" or "Unlock OFF — batas normal", 2)
    end,
})

TabMisc:CreateSlider({
    Name         = "Batas Zoom Out (min scale)",
    Range        = { 0.10, 1.50 },
    Increment    = 0.05,
    Suffix       = "x",
    CurrentValue = 0.2,
    Flag         = "v2_zoommin",
    Callback     = function(v)
        zoomMinVal = v
        STATE.zoomMin = v
        LX.SetZoomLimits(zoomMinVal, zoomMaxVal)
    end,
})

TabMisc:CreateSlider({
    Name         = "Batas Zoom In (max scale)",
    Range        = { 1.6, 100 },
    Increment    = 0.5,
    Suffix       = "x",
    CurrentValue = 5,
    Flag         = "v2_zoommax",
    Callback     = function(v)
        zoomMaxVal = v
        STATE.zoomMax = v
        LX.SetZoomLimits(zoomMinVal, zoomMaxVal)
    end,
})

local function zoomStep(dir)
    if dir < 0 then LX.ZoomOut(1.2) else LX.ZoomIn(1.2) end
end

TabMisc:CreateButton({ Name = "Zoom Out  (−)", Callback = function() zoomStep(-1) end })
TabMisc:CreateButton({ Name = "Zoom In  (+)", Callback = function() zoomStep(1) end })
TabMisc:CreateButton({
    Name = "Reset Zoom (1.0)",
    Callback = function()
        LX.SetZoom(1)
        note("ZOOM", "Reset ke 1.0x", 1.5)
    end,
})

TabMisc:CreateSection("Performance / Render")
TabMisc:CreateToggle({
    Name         = "Performance Mode (low quality)",
    CurrentValue = false,
    Flag         = "v2_performance",
    Callback     = function(v)
        if v then LX.Performance_On() else LX.Performance_Off() end
        note("PERFORMANCE", v and "ON — render diperkecil" or "OFF — kualitas normal", 2)
    end,
})

TabMisc:CreateSlider({
    Name         = "Render Scale In-Game",
    Range        = { 0.25, 2.00 },
    Increment    = 0.05,
    Suffix       = "x",
    CurrentValue = 0.75,
    Flag         = "v2_renderscale",
    Callback     = function(v)
        STATE.renderScale = v
        LX.SetRenderScale(v)
    end,
})

TabMisc:CreateSlider({
    Name         = "Render Scale Saat Loading",
    Range        = { 0.20, 1.50 },
    Increment    = 0.05,
    Suffix       = "x",
    CurrentValue = 0.50,
    Flag         = "v2_loadingscale",
    Callback     = function(v)
        STATE.loadingScale = v
        LX.SetLoadingScale(v)
    end,
})

TabMisc:CreateParagraph({
    Title   = "Cara kerja",
    Content = "Saat loading (world belum siap) skala render dipakai versi loading. Setelah world siap, skala in-game dipakai terus. Performance Mode juga menurunkan lowGfx + LOW_RANGE game.",
})

-- ══════════════════════════════════════════════════════════════
--  TAB · SPAM CHAT
-- ══════════════════════════════════════════════════════════════
local TabSpam = Window:CreateTab("💬  SPAM CHAT", nil)

local spamMsgVal      = ""
local spamColorName   = "White"
local spamStatusLabel = TabSpam:CreateLabel("Status: idle")

TabSpam:CreateSection("Pesan")
TabSpam:CreateInput({
    Name        = "Chat Message",
    PlaceholderText = "Teks yang akan dikirim…",
    RemoveTextAfterFocusLost = false,
    Flag        = "v2_spam_msg",
    Callback    = function(v)
        spamMsgVal = v
        STATE.spamMsg = v
    end,
})

TabSpam:CreateDropdown({
    Name    = "Warna Chat",
    Options = COLOR_NAMES,
    CurrentOption = { "White" },
    Flag    = "v2_spam_color",
    Callback = function(v)
        local s = type(v) == "table" and v[1] or v
        spamColorName = tostring(s or "White")
        STATE.spamColor = colorCode(spamColorName)
    end,
})

TabSpam:CreateSlider({
    Name         = "Delay antar pesan",
    Range        = { 0.8, 10 },
    Increment    = 0.1,
    Suffix       = " detik",
    CurrentValue = 1.5,
    Flag         = "v2_spam_delay",
    Callback     = function(v)
        STATE.spamDelay = v
    end,
})

TabSpam:CreateToggle({
    Name         = "Random Prefix",
    CurrentValue = false,
    Flag         = "v2_spam_random",
    Callback     = function(v)
        STATE.spamRandom = v
    end,
})

TabSpam:CreateSection("Kontrol")
TabSpam:CreateButton({
    Name     = "▶  START SPAM",
    Callback = function()
        if spamMsgVal == "" then
            note("SPAM", "Isi pesan dulu!", 2)
            return
        end
        LX.Spam_Start(spamMsgVal, STATE.spamDelay, STATE.spamRandom, colorCode(spamColorName))
        note("SPAM", "Mulai — cek chat world, pesan harus muncul", 2)
    end,
})

TabSpam:CreateButton({
    Name     = "■  STOP SPAM",
    Callback = function()
        LX.Spam_Stop()
        note("SPAM", "Berhenti", 1.5)
    end,
})

TabSpam:CreateParagraph({
    Title   = "Catatan",
    Content = "Pesan dikirim ke TextChannel world (WorldChannels). Warna memakai kode BitmapText game. Delay minimal 0.8s karena Floodcheck Roblox.",
})

-- ══════════════════════════════════════════════════════════════
--  TAB · AUTO FARM
-- ══════════════════════════════════════════════════════════════
local TabFarm = Window:CreateTab("🌱  AUTO FARM", nil)

local function ensureGrid()
    STATE.pnbGrid = STATE.pnbGrid or {}
    for r = 1, 5 do
        STATE.pnbGrid[r] = STATE.pnbGrid[r] or {}
        for c = 1, 5 do
            if STATE.pnbGrid[r][c] == nil then
                STATE.pnbGrid[r][c] = not (r == 3 and c == 3)
            end
        end
    end
    STATE.pnbGrid[3][3] = false
end
ensureGrid()

local function gridCount()
    local n = 0
    for r = 1, 5 do
        for c = 1, 5 do
            if STATE.pnbGrid[r] and STATE.pnbGrid[r][c] then n = n + 1 end
        end
    end
    return n
end

local farmPosLabel = TabFarm:CreateLabel("Posisi: —")
local gridSummary  = TabFarm:CreateLabel("Grid: —")
local farmStatus   = TabFarm:CreateLabel("PNB: OFF  |  DF: OFF  |  CLEAR: OFF")

local function updateGridSummary()
    setLabel(gridSummary, string.format("Grid: %d/24 kotak aktif (tengah = kamu)", gridCount()))
end
updateGridSummary()

local gridGui = nil

local function openGridSelector()
    if gridGui and gridGui.Parent then gridGui:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LX_GridSelector"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 60
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PG
    gridGui = gui

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.fromScale(0.5, 0.5)
    main.Size = UDim2.fromOffset(420, 572)
    main.BackgroundColor3 = Color3.fromRGB(10, 18, 32)
    main.BorderSizePixel = 0
    main.Parent = gui
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = main
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(0, 120, 200)
    mainStroke.Thickness = 1.5
    mainStroke.Parent = main

    local drag = Instance.new("TextButton")
    drag.Text = ""
    drag.BackgroundTransparency = 1
    drag.Size = UDim2.new(1, 0, 0, 44)
    drag.Parent = main
    local dragging, dragStart, startPos = false, nil, nil
    drag.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(16, 10)
    title.Size = UDim2.fromOffset(320, 26)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(240, 248, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "PILIH GRID FARM 5×5"
    title.Parent = main

    local close = Instance.new("TextButton")
    close.AnchorPoint = Vector2.new(1, 0)
    close.Position = UDim2.new(1, -12, 0, 10)
    close.Size = UDim2.fromOffset(26, 26)
    close.BackgroundColor3 = Color3.fromRGB(30, 44, 66)
    close.BorderSizePixel = 0
    close.Font = Enum.Font.GothamBold
    close.TextSize = 16
    close.TextColor3 = Color3.fromRGB(240, 248, 255)
    close.Text = "×"
    close.Parent = main
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = close
    close.MouseButton1Click:Connect(function()
        gui:Destroy()
        if gridGui == gui then gridGui = nil end
    end)

    local sub = Instance.new("TextLabel")
    sub.BackgroundTransparency = 1
    sub.Position = UDim2.fromOffset(16, 42)
    sub.Size = UDim2.fromOffset(388, 34)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 13
    sub.TextWrapped = true
    sub.TextColor3 = Color3.fromRGB(150, 190, 225)
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Text = "Kotak biru = area yang akan di-farm. Klik kotak untuk ON/OFF. Tengah = posisi kamu."
    sub.Parent = main

    local presetNames = { "ALL", "CROSS", "RING", "CLEAR" }
    local presets = {
        ALL   = function(r, c) return not (r == 3 and c == 3) end,
        CROSS = function(r, c) return (r == 3 or c == 3) and not (r == 3 and c == 3) end,
        RING  = function(r, c) return (r == 1 or r == 5 or c == 1 or c == 5) end,
        CLEAR = function() return false end,
    }

    local cells, strokes = {}, {}
    local refreshCells

    local function applyPreset(name)
        for r = 1, 5 do
            for c = 1, 5 do
                STATE.pnbGrid[r][c] = presets[name](r, c) and true or false
            end
        end
        STATE.pnbGrid[3][3] = false
        refreshCells()
    end

    refreshCells = function()
        for r = 1, 5 do
            for c = 1, 5 do
                local active = STATE.pnbGrid[r] and STATE.pnbGrid[r][c] == true
                local cell = cells[r] and cells[r][c]
                local stroke = strokes[r] and strokes[r][c]
                if cell and not (r == 3 and c == 3) then
                    cell.BackgroundColor3 = active and Color3.fromRGB(0, 130, 220) or Color3.fromRGB(24, 34, 52)
                    if stroke then
                        stroke.Color = active and Color3.fromRGB(0, 190, 255) or Color3.fromRGB(48, 70, 100)
                    end
                end
            end
        end
        updateGridSummary()
    end

    for i, name in ipairs(presetNames) do
        local b = Instance.new("TextButton")
        b.Position = UDim2.fromOffset(29 + (i - 1) * 92, 86)
        b.Size = UDim2.fromOffset(86, 30)
        b.BackgroundColor3 = Color3.fromRGB(0, 70, 120)
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.TextColor3 = Color3.fromRGB(220, 240, 255)
        b.Text = name
        b.Parent = main
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 6)
        bc.Parent = b
        b.MouseButton1Click:Connect(function()
            applyPreset(name)
        end)
    end

    local gridFrame = Instance.new("Frame")
    gridFrame.Position = UDim2.fromOffset(28, 128)
    gridFrame.Size = UDim2.fromOffset(364, 364)
    gridFrame.BackgroundTransparency = 1
    gridFrame.Parent = main

    local layout = Instance.new("UIGridLayout")
    layout.CellSize = UDim2.fromOffset(68, 68)
    layout.CellPadding = UDim2.fromOffset(6, 6)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.FillDirectionMaxElements = 5
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = gridFrame

    for r = 1, 5 do
        cells[r] = {}
        strokes[r] = {}
        for c = 1, 5 do
            local cell = Instance.new("TextButton")
            cell.LayoutOrder = (r - 1) * 5 + c
            cell.BackgroundColor3 = Color3.fromRGB(24, 34, 52)
            cell.BorderSizePixel = 0
            cell.AutoButtonColor = false
            cell.Font = Enum.Font.GothamBold
            cell.TextSize = 12
            cell.TextColor3 = Color3.fromRGB(150, 200, 240)
            cell.Text = ""
            cell.Parent = gridFrame
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = cell
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(48, 70, 100)
            stroke.Thickness = 1
            stroke.Parent = cell
            cells[r][c] = cell
            strokes[r][c] = stroke

            if r == 3 and c == 3 then
                cell.BackgroundColor3 = Color3.fromRGB(40, 48, 64)
                cell.Text = "YOU"
                stroke.Color = Color3.fromRGB(80, 95, 120)
            else
                cell.MouseButton1Click:Connect(function()
                    STATE.pnbGrid[r][c] = not STATE.pnbGrid[r][c]
                    refreshCells()
                end)
            end
        end
    end

    refreshCells()

    local save = Instance.new("TextButton")
    save.Position = UDim2.fromOffset(28, 506)
    save.Size = UDim2.fromOffset(364, 38)
    save.BackgroundColor3 = Color3.fromRGB(0, 140, 230)
    save.BorderSizePixel = 0
    save.Font = Enum.Font.GothamBold
    save.TextSize = 15
    save.TextColor3 = Color3.fromRGB(255, 255, 255)
    save.Text = "SIMPAN & SELESAI"
    save.Parent = main
    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 8)
    saveCorner.Parent = save
    save.MouseButton1Click:Connect(function()
        gui:Destroy()
        if gridGui == gui then gridGui = nil end
        updateGridSummary()
        note("GRID", string.format("%d kotak dipilih", gridCount()), 2)
    end)
end

TabFarm:CreateSection("Plant N Break (PNB)")
TabFarm:CreateButton({
    Name     = "🗺  BUKA GRID 5×5",
    Callback = function()
        openGridSelector()
    end,
})

TabFarm:CreateButton({
    Name     = "📍  SET BASE (posisi sekarang)",
    Callback = function()
        local base = LX.PNB_SetBase()
        if base then
            note("PNB", string.format("Base: %d, %d", base.x, base.y), 2)
        else
            note("PNB", "Posisi belum terbaca", 2)
        end
    end,
})

local seedResults = {}
local selectedSeedId = nil
local seedDropdown

TabFarm:CreateInput({
    Name        = "Cari Seed (nama / ID)",
    PlaceholderText = "contoh: seed, carrot, 12",
    RemoveTextAfterFocusLost = false,
    Flag        = "v2_seed_search",
    Callback    = function(v)
        local q = tostring(v or "")
        if #q < 2 then return end
        seedResults = LX.SearchItems(q, 80) or {}
        local opts = {}
        for _, r in ipairs(seedResults) do
            opts[#opts + 1] = r.name .. " | " .. tostring(r.id)
        end
        if #opts == 0 then opts = { "(tidak ditemukan)" } end
        setOptions(seedDropdown, opts)
    end,
})

seedDropdown = TabFarm:CreateDropdown({
    Name    = "Pilih Seed",
    Options = { "(cari dulu)" },
    CurrentOption = { "(cari dulu)" },
    Flag    = "v2_seed_select",
    Callback = function(v)
        local s = type(v) == "table" and v[1] or v
        s = tostring(s or "")
        for _, r in ipairs(seedResults) do
            if (r.name .. " | " .. tostring(r.id)) == s then
                selectedSeedId = r.id
                STATE.pnbSeedId = r.id
                note("SEED", r.name .. " (ID " .. tostring(r.id) .. ")", 2)
                return
            end
        end
    end,
})

TabFarm:CreateInput({
    Name        = "Seed ID Manual",
    PlaceholderText = "angka ID item",
    RemoveTextAfterFocusLost = false,
    Flag        = "v2_seed_manual",
    Callback    = function(v)
        local id = tonumber(v)
        if id then
            selectedSeedId = id
            STATE.pnbSeedId = id
        end
    end,
})

local pnbDelayVal = 0.35
TabFarm:CreateSlider({
    Name         = "PNB Delay",
    Range        = { 0.12, 2 },
    Increment    = 0.02,
    Suffix       = "s",
    CurrentValue = 0.35,
    Flag         = "v2_pnb_delay",
    Callback     = function(v)
        pnbDelayVal = v
        STATE.pnbDelay = v
    end,
})

TabFarm:CreateToggle({
    Name         = "Auto Collect Drop",
    CurrentValue = true,
    Flag         = "v2_pnb_collect",
    Callback     = function(v)
        STATE.pnbAutoCollect = v
    end,
})

TabFarm:CreateButton({
    Name     = "▶  START PNB",
    Callback = function()
        if not STATE.pnbBase then LX.PNB_SetBase() end
        LX.PNB_Start(selectedSeedId or STATE.pnbSeedId, pnbDelayVal)
        note("PNB", "Berjalan di grid terpilih", 2)
    end,
})

TabFarm:CreateButton({
    Name     = "■  STOP PNB",
    Callback = function()
        LX.PNB_Stop()
        note("PNB", "Dihentikan", 1.5)
    end,
})

TabFarm:CreateSection("Drop Farm (DF)")
local dfDelayVal = 0.4
TabFarm:CreateSlider({
    Name         = "DF Delay",
    Range        = { 0.15, 2 },
    Increment    = 0.05,
    Suffix       = "s",
    CurrentValue = 0.4,
    Flag         = "v2_df_delay",
    Callback     = function(v)
        dfDelayVal = v
        STATE.dfDelay = v
    end,
})
TabFarm:CreateButton({ Name = "▶  START DF", Callback = function() LX.DF_Start(dfDelayVal); note("DF", "ON", 1.5) end })
TabFarm:CreateButton({ Name = "■  STOP DF", Callback = function() LX.DF_Stop(); note("DF", "OFF", 1.5) end })

TabFarm:CreateSection("Clear World")
local clearConfirm = false
local clearDelayVal = 0.5
TabFarm:CreateToggle({
    Name         = "KONFIRMASI CLEAR (wajib)",
    CurrentValue = false,
    Flag         = "v2_clear_confirm",
    Callback     = function(v)
        clearConfirm = v
    end,
})
TabFarm:CreateToggle({
    Name         = "Ikut hapus Background",
    CurrentValue = true,
    Flag         = "v2_clear_bg",
    Callback     = function(v)
        STATE.clearBg = v
    end,
})
TabFarm:CreateSlider({
    Name         = "Clear Delay",
    Range        = { 0.08, 2 },
    Increment    = 0.02,
    Suffix       = "s",
    CurrentValue = 0.5,
    Flag         = "v2_clear_delay",
    Callback     = function(v)
        clearDelayVal = v
        STATE.clearDelay = v
    end,
})
TabFarm:CreateButton({
    Name     = "☢  START CLEAR WORLD",
    Callback = function()
        if not clearConfirm then
            note("CLEAR", "Aktifkan KONFIRMASI dulu!", 2)
            return
        end
        LX.Clear_Start(clearDelayVal)
        note("CLEAR", "Mulai menghancurkan world (kecuali block terkunci)", 3)
    end,
})
TabFarm:CreateButton({ Name = "■  STOP CLEAR", Callback = function() LX.Clear_Stop(); note("CLEAR", "Stop", 1.5) end })

-- ══════════════════════════════════════════════════════════════
--  TAB · TELEPORT
-- ══════════════════════════════════════════════════════════════
local TabTP = Window:CreateTab("🚀  TELEPORT", nil)

local tpPosLabel = TabTP:CreateLabel("Posisi: —")
local tpX, tpY = 0, 0

TabTP:CreateSection("Teleport Tile")
TabTP:CreateInput({
    Name        = "Tile X",
    PlaceholderText = "contoh: 25",
    RemoveTextAfterFocusLost = false,
    Flag        = "v2_tp_x",
    Callback    = function(v)
        tpX = tonumber(v) or tpX
    end,
})
TabTP:CreateInput({
    Name        = "Tile Y",
    PlaceholderText = "contoh: 40",
    RemoveTextAfterFocusLost = false,
    Flag        = "v2_tp_y",
    Callback    = function(v)
        tpY = tonumber(v) or tpY
    end,
})
TabTP:CreateDropdown({
    Name    = "Metode",
    Options = { "Instant Snap", "Walk Approach (3 step)" },
    CurrentOption = { "Instant Snap" },
    Flag    = "v2_tp_method",
    Callback = function(v)
        local s = tostring(type(v) == "table" and v[1] or v or "")
        STATE.tpMethod = s:find("Walk") and 2 or 1
    end,
})
TabTP:CreateButton({
    Name     = "🚀  TELEPORT KE TILE",
    Callback = function()
        local ok = LX.Teleport(tpX, tpY, STATE.tpMethod)
        if ok then
            note("TELEPORT", string.format("Pindah ke tile %d, %d", tpX, tpY), 2)
        else
            note("TELEPORT", "Koordinat tidak valid", 2)
        end
    end,
})

TabTP:CreateSection("Teleport ke Player")
local playerMap = {}
local selectedPlayerId = nil
local playerDd

local function displayName(p)
    local gn = p:GetAttribute("GameName")
    local nick = p:GetAttribute("Nick")
    if type(gn) == "string" and gn ~= "" then return gn end
    if type(nick) == "string" and nick ~= "" then return nick end
    return p.Name
end

local function refreshPlayerList()
    playerMap = {}
    local seen = {}
    local ok, list = pcall(LX.GetPlayerList)
    if ok and type(list) == "table" then
        for _, e in ipairs(list) do seen[e.userId] = e end
    end
    local opts = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local e = seen[p.UserId]
            local suffix = ""
            if e and e.seen then
                suffix = string.format("  @%.0f,%.0f", e.x or 0, e.y or 0)
            end
            local label = displayName(p) .. suffix
            opts[#opts + 1] = label
            playerMap[label] = p.UserId
        end
    end
    if #opts == 0 then opts = { "(tidak ada player lain)" } end
    setOptions(playerDd, opts)
end

playerDd = TabTP:CreateDropdown({
    Name    = "Pilih Player",
    Options = { "(refresh dulu)" },
    CurrentOption = { "(refresh dulu)" },
    Flag    = "v2_tp_player",
    Callback = function(v)
        local s = type(v) == "table" and v[1] or v
        selectedPlayerId = playerMap[tostring(s or "")]
    end,
})
TabTP:CreateButton({ Name = "🔄  REFRESH PLAYER", Callback = function() refreshPlayerList(); note("TELEPORT", "List player di-refresh", 1.5) end })
TabTP:CreateButton({
    Name     = "🎯  TELEPORT KE PLAYER",
    Callback = function()
        if not selectedPlayerId then
            note("TELEPORT", "Pilih player dulu / refresh", 2)
            return
        end
        local ok = LX.TeleportToPlayer(selectedPlayerId)
        if ok then
            note("TELEPORT", "Pindah ke player", 2)
        else
            note("TELEPORT", "Posisi player belum terkirim", 2)
        end
    end,
})

TabTP:CreateParagraph({
    Title   = "Catatan",
    Content = "Posisi dibaca langsung dari state render game (bukan 0,0). Teleport menulis posisi asli player pada frame berikutnya.",
})

-- ══════════════════════════════════════════════════════════════
--  TAB · MODS LOG
-- ══════════════════════════════════════════════════════════════
local TabMods = Window:CreateTab("🛰  MODS LOG", nil)

local modCountLabel = TabMods:CreateLabel("Deteksi: 0x  |  Status: OFF")
local modLogPara = TabMods:CreateParagraph({
    Title   = "Log",
    Content = "(belum ada deteksi)",
})

TabMods:CreateDropdown({
    Name    = "Aksi saat Staff terdeteksi",
    Options = { "SLEEP (stop semua bot)", "LEAVE (keluar world)", "FLY_OFF (matikan fly)" },
    CurrentOption = { "SLEEP (stop semua bot)" },
    Flag    = "v2_mod_action",
    Callback = function(v)
        local s = tostring(type(v) == "table" and v[1] or v or "")
        if s:find("SLEEP") then STATE.modAction = "SLEEP"
        elseif s:find("LEAVE") then STATE.modAction = "LEAVE"
        else STATE.modAction = "FLY_OFF" end
    end,
})

TabMods:CreateToggle({
    Name         = "Watch Staff (Tag attribute)",
    CurrentValue = false,
    Flag         = "v2_mod_watch",
    Callback     = function(v)
        if v then
            LX.ModWatch_On(STATE.modAction)
            note("MODS", "Watch ON — memantau Tag staff", 2)
        else
            LX.ModWatch_Off()
            note("MODS", "Watch OFF", 1.5)
        end
    end,
})

-- ══════════════════════════════════════════════════════════════
--  TAB · ITEM LIST
-- ══════════════════════════════════════════════════════════════
local TabItems = Window:CreateTab("📦  ITEM LIST", nil)

local itemTabStatus = TabItems:CreateLabel("Database: menunggu…")

TabItems:CreateParagraph({
    Title   = "Item Database",
    Content = "Buka browser item: scroll + search, gambar asli dari atlas game, format NAME | ID. Klik kartu untuk melihat info + tombol Copy.",
})

local itemBrowserGui = nil
local buildItemBrowser

TabItems:CreateButton({
    Name     = "📦  BUKA ITEM DATABASE",
    Callback = function()
        if buildItemBrowser then buildItemBrowser() end
    end,
})

buildItemBrowser = function()
    if itemBrowserGui and itemBrowserGui.Parent then
        itemBrowserGui.Enabled = true
        return
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LX_ItemBrowser"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 55
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PG
    itemBrowserGui = gui

    local main = Instance.new("Frame")
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.fromScale(0.5, 0.5)
    main.Size = UDim2.fromOffset(820, 600)
    main.BackgroundColor3 = Color3.fromRGB(8, 15, 27)
    main.BorderSizePixel = 0
    main.Parent = gui
    local mc = Instance.new("UICorner")
    mc.CornerRadius = UDim.new(0, 10)
    mc.Parent = main
    local ms = Instance.new("UIStroke")
    ms.Color = Color3.fromRGB(0, 110, 190)
    ms.Thickness = 1.5
    ms.Parent = main

    local dragBar = Instance.new("TextButton")
    dragBar.Text = ""
    dragBar.BackgroundTransparency = 1
    dragBar.Size = UDim2.new(1, 0, 0, 58)
    dragBar.Parent = main
    local dragging, dragStart, startPos = false, nil, nil
    dragBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(16, 10)
    title.Size = UDim2.fromOffset(560, 28)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 19
    title.TextColor3 = Color3.fromRGB(240, 248, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "ITEM DATABASE · GrowBlox"
    title.Parent = main

    local countLabel = Instance.new("TextLabel")
    countLabel.BackgroundTransparency = 1
    countLabel.AnchorPoint = Vector2.new(1, 0)
    countLabel.Position = UDim2.new(1, -56, 0, 14)
    countLabel.Size = UDim2.fromOffset(180, 20)
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextSize = 13
    countLabel.TextColor3 = Color3.fromRGB(120, 190, 240)
    countLabel.TextXAlignment = Enum.TextXAlignment.Right
    countLabel.Text = "0 item"
    countLabel.Parent = main

    local close = Instance.new("TextButton")
    close.AnchorPoint = Vector2.new(1, 0)
    close.Position = UDim2.new(1, -12, 0, 12)
    close.Size = UDim2.fromOffset(30, 30)
    close.BackgroundColor3 = Color3.fromRGB(28, 42, 64)
    close.BorderSizePixel = 0
    close.Font = Enum.Font.GothamBold
    close.TextSize = 18
    close.TextColor3 = Color3.fromRGB(240, 248, 255)
    close.Text = "×"
    close.Parent = main
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 7)
    cc.Parent = close
    close.MouseButton1Click:Connect(function()
        gui:Destroy()
        if itemBrowserGui == gui then itemBrowserGui = nil end
    end)

    local searchFrame = Instance.new("Frame")
    searchFrame.Position = UDim2.fromOffset(16, 76)
    searchFrame.Size = UDim2.fromOffset(788, 36)
    searchFrame.BackgroundColor3 = Color3.fromRGB(5, 18, 36)
    searchFrame.BorderSizePixel = 0
    searchFrame.Parent = main
    local sf = Instance.new("UICorner")
    sf.CornerRadius = UDim.new(0, 8)
    sf.Parent = searchFrame
    local ss = Instance.new("UIStroke")
    ss.Color = Color3.fromRGB(0, 100, 180)
    ss.Thickness = 1
    ss.Parent = searchFrame

    local searchBox = Instance.new("TextBox")
    searchBox.BackgroundTransparency = 1
    searchBox.Position = UDim2.fromOffset(12, 0)
    searchBox.Size = UDim2.new(1, -24, 1, 0)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 15
    searchBox.TextColor3 = Color3.fromRGB(235, 245, 255)
    searchBox.PlaceholderText = "Cari nama item atau ID…"
    searchBox.PlaceholderColor3 = Color3.fromRGB(80, 130, 180)
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.ClearTextOnFocus = false
    searchBox.Text = ""
    searchBox.Parent = searchFrame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Position = UDim2.fromOffset(16, 126)
    scroll.Size = UDim2.fromOffset(464, 440)
    scroll.BackgroundColor3 = Color3.fromRGB(6, 13, 24)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 130, 210)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = main
    local scr = Instance.new("UICorner")
    scr.CornerRadius = UDim.new(0, 8)
    scr.Parent = scroll

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(222, 56)
    grid.CellPadding = UDim2.fromOffset(6, 6)
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.FillDirectionMaxElements = 2
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = scroll

    local panel = Instance.new("Frame")
    panel.Position = UDim2.fromOffset(492, 126)
    panel.Size = UDim2.fromOffset(312, 440)
    panel.BackgroundColor3 = Color3.fromRGB(10, 21, 38)
    panel.BorderSizePixel = 0
    panel.Parent = main
    local pc = Instance.new("UICorner")
    pc.CornerRadius = UDim.new(0, 8)
    pc.Parent = panel
    local ps = Instance.new("UIStroke")
    ps.Color = Color3.fromRGB(0, 90, 160)
    ps.Thickness = 1
    ps.Parent = panel

    local previewHolder = Instance.new("Frame")
    previewHolder.Position = UDim2.fromOffset(108, 14)
    previewHolder.Size = UDim2.fromOffset(96, 96)
    previewHolder.BackgroundColor3 = Color3.fromRGB(6, 14, 26)
    previewHolder.BorderSizePixel = 0
    previewHolder.Parent = panel
    local phc = Instance.new("UICorner")
    phc.CornerRadius = UDim.new(0, 8)
    phc.Parent = previewHolder
    local phs = Instance.new("UIStroke")
    phs.Color = Color3.fromRGB(0, 80, 140)
    phs.Thickness = 1
    phs.Parent = previewHolder

    local previewIcon = nil
    local okIcon, made = pcall(function() return LX.MakeItemIcon(previewHolder, 90, 4) end)
    if okIcon and made then
        previewIcon = made
        pcall(function()
            previewIcon.frame.Position = UDim2.fromOffset(3, 3)
        end)
    else
        local q = Instance.new("TextLabel")
        q.BackgroundTransparency = 1
        q.Size = UDim2.fromScale(1, 1)
        q.Font = Enum.Font.GothamBold
        q.TextSize = 32
        q.TextColor3 = Color3.fromRGB(80, 120, 160)
        q.Text = "?"
        q.Parent = previewHolder
    end

    local infoName = Instance.new("TextLabel")
    infoName.BackgroundTransparency = 1
    infoName.Position = UDim2.fromOffset(16, 118)
    infoName.Size = UDim2.fromOffset(280, 40)
    infoName.Font = Enum.Font.GothamBold
    infoName.TextSize = 17
    infoName.TextWrapped = true
    infoName.TextColor3 = Color3.fromRGB(240, 248, 255)
    infoName.TextXAlignment = Enum.TextXAlignment.Left
    infoName.TextYAlignment = Enum.TextYAlignment.Top
    infoName.Text = "Pilih item"
    infoName.Parent = panel

    local infoId = Instance.new("TextLabel")
    infoId.BackgroundTransparency = 1
    infoId.Position = UDim2.fromOffset(16, 160)
    infoId.Size = UDim2.fromOffset(280, 18)
    infoId.Font = Enum.Font.Gotham
    infoId.TextSize = 13
    infoId.TextColor3 = Color3.fromRGB(120, 200, 255)
    infoId.TextXAlignment = Enum.TextXAlignment.Left
    infoId.Text = "ID: —"
    infoId.Parent = panel

    local infoMeta = Instance.new("TextLabel")
    infoMeta.BackgroundTransparency = 1
    infoMeta.Position = UDim2.fromOffset(16, 180)
    infoMeta.Size = UDim2.fromOffset(280, 18)
    infoMeta.Font = Enum.Font.Gotham
    infoMeta.TextSize = 13
    infoMeta.TextColor3 = Color3.fromRGB(160, 200, 230)
    infoMeta.TextXAlignment = Enum.TextXAlignment.Left
    infoMeta.Text = "Kind: —   Rarity: —"
    infoMeta.Parent = panel

    local descFrame = Instance.new("ScrollingFrame")
    descFrame.Position = UDim2.fromOffset(16, 204)
    descFrame.Size = UDim2.fromOffset(280, 124)
    descFrame.BackgroundTransparency = 1
    descFrame.BorderSizePixel = 0
    descFrame.ScrollBarThickness = 4
    descFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    descFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    descFrame.Parent = panel

    local infoDesc = Instance.new("TextLabel")
    infoDesc.BackgroundTransparency = 1
    infoDesc.Size = UDim2.fromOffset(268, 0)
    infoDesc.AutomaticSize = Enum.AutomaticSize.Y
    infoDesc.Font = Enum.Font.Gotham
    infoDesc.TextSize = 13
    infoDesc.TextWrapped = true
    infoDesc.TextColor3 = Color3.fromRGB(190, 215, 235)
    infoDesc.TextXAlignment = Enum.TextXAlignment.Left
    infoDesc.TextYAlignment = Enum.TextYAlignment.Top
    infoDesc.Text = "Pilih item untuk melihat keterangan."
    infoDesc.Parent = descFrame

    local function makeBtn(y, text, color)
        local b = Instance.new("TextButton")
        b.Position = UDim2.fromOffset(16, y)
        b.Size = UDim2.fromOffset(280, 30)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Text = text
        b.Parent = panel
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = b
        return b
    end

    local copyStatus = Instance.new("TextLabel")
    copyStatus.BackgroundTransparency = 1
    copyStatus.Position = UDim2.fromOffset(16, 408)
    copyStatus.Size = UDim2.fromOffset(280, 22)
    copyStatus.Font = Enum.Font.Gotham
    copyStatus.TextSize = 12
    copyStatus.TextColor3 = Color3.fromRGB(130, 200, 150)
    copyStatus.TextXAlignment = Enum.TextXAlignment.Left
    copyStatus.Text = ""
    copyStatus.Parent = panel

    local currentItem = nil
    local selectedCard = nil

    local function fillInfo(item)
        currentItem = item
        local info = LX.GetItemInfo(item.id) or {}
        infoName.Text = info.name or item.name or ("Item " .. tostring(item.id))
        infoId.Text = "ID: " .. tostring(item.id)
        infoMeta.Text = "Kind: " .. tostring(info.kind or item.kind or "-")
            .. "   Rarity: " .. tostring(info.rarity or item.rarity or "-")
        local d = info.desc or item.desc or ""
        if d == "" then d = "Tidak ada keterangan." end
        infoDesc.Text = d
        pcall(function() LX.SetItemIcon(previewIcon, item.id) end)
        copyStatus.Text = ""
    end

    local copyIdBtn = makeBtn(336, "📋  COPY ID", Color3.fromRGB(0, 110, 190))
    local copyBothBtn = makeBtn(372, "📋  COPY NAME | ID", Color3.fromRGB(0, 140, 120))

    copyIdBtn.MouseButton1Click:Connect(function()
        if not currentItem then copyStatus.Text = "Pilih item dulu"; return end
        local ok = copyText(currentItem.id)
        copyStatus.Text = ok and ("Copied: " .. tostring(currentItem.id)) or "Clipboard tidak tersedia"
        if ok then note("COPY", tostring(currentItem.id), 1.5) end
    end)

    copyBothBtn.MouseButton1Click:Connect(function()
        if not currentItem then copyStatus.Text = "Pilih item dulu"; return end
        local txt = tostring(currentItem.name) .. " | " .. tostring(currentItem.id)
        local ok = copyText(txt)
        copyStatus.Text = ok and ("Copied: " .. txt) or "Clipboard tidak tersedia"
        if ok then note("COPY", txt, 1.5) end
    end)

    local function makeCard(item, order)
        local card = Instance.new("TextButton")
        card.LayoutOrder = order
        card.BackgroundColor3 = Color3.fromRGB(14, 27, 46)
        card.BorderSizePixel = 0
        card.AutoButtonColor = false
        card.Text = ""
        card.Parent = scroll
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 7)
        corner.Parent = card
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 70, 125)
        stroke.Thickness = 1
        stroke.Parent = card

        local ok, got = pcall(function() return LX.MakeItemIcon(card, 44, 4) end)
        if ok and got then
            pcall(function()
                got.frame.Position = UDim2.fromOffset(6, 6)
                LX.SetItemIcon(got, item.id)
            end)
        else
            local q = Instance.new("TextLabel")
            q.BackgroundTransparency = 1
            q.Position = UDim2.fromOffset(6, 6)
            q.Size = UDim2.fromOffset(44, 44)
            q.Font = Enum.Font.GothamBold
            q.TextSize = 18
            q.TextColor3 = Color3.fromRGB(90, 130, 170)
            q.Text = "?"
            q.Parent = card
        end

        local nl = Instance.new("TextLabel")
        nl.BackgroundTransparency = 1
        nl.Position = UDim2.fromOffset(58, 8)
        nl.Size = UDim2.fromOffset(156, 20)
        nl.Font = Enum.Font.GothamBold
        nl.TextSize = 13
        nl.TextColor3 = Color3.fromRGB(235, 245, 255)
        nl.TextXAlignment = Enum.TextXAlignment.Left
        nl.TextTruncate = Enum.TextTruncate.AtEnd
        nl.Text = tostring(item.name)
        nl.Parent = card

        local il = Instance.new("TextLabel")
        il.BackgroundTransparency = 1
        il.Position = UDim2.fromOffset(58, 29)
        il.Size = UDim2.fromOffset(156, 18)
        il.Font = Enum.Font.Gotham
        il.TextSize = 12
        il.TextColor3 = Color3.fromRGB(120, 200, 255)
        il.TextXAlignment = Enum.TextXAlignment.Left
        il.Text = "ID " .. tostring(item.id)
        il.Parent = card

        card.MouseButton1Click:Connect(function()
            if selectedCard and selectedCard ~= card then
                local old = selectedCard:FindFirstChildOfClass("UIStroke")
                if old then
                    old.Color = Color3.fromRGB(0, 70, 125)
                    old.Thickness = 1
                end
            end
            selectedCard = card
            stroke.Color = Color3.fromRGB(0, 190, 255)
            stroke.Thickness = 2
            fillInfo(item)
        end)
    end

    local populating = false
    local pendingQuery = nil

    local function populate(query)
        if query == nil then query = searchBox.Text end
        if populating then
            pendingQuery = query
            return
        end
        populating = true
        task.spawn(function()
            local q = query
            while q ~= nil do
                pendingQuery = nil
                if itemBrowserGui ~= gui or not gui.Parent then
                    populating = false
                    return
                end
                local results = {}
                local ok, res = pcall(LX.SearchItems, q, 800)
                if ok and type(res) == "table" then results = res end
                for _, ch in ipairs(scroll:GetChildren()) do
                    if not ch:IsA("UIGridLayout") then ch:Destroy() end
                end
                selectedCard = nil
                for i, item in ipairs(results) do
                    makeCard(item, i)
                end
                countLabel.Text = string.format("%d item", #results)
                if #results == 0 then
                    copyStatus.Text = "Database belum siap / kosong"
                end
                q = pendingQuery
            end
            populating = false
        end)
    end

    local searchToken = 0
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchToken = searchToken + 1
        local my = searchToken
        task.delay(0.15, function()
            if my ~= searchToken then return end
            if itemBrowserGui ~= gui or not gui.Parent then return end
            populate(searchBox.Text)
        end)
    end)

    populate("")
    task.spawn(function()
        for _ = 1, 20 do
            task.wait(0.5)
            if itemBrowserGui ~= gui or not gui.Parent then break end
            local db = LX.GetItemDB and LX.GetItemDB() or {}
            local n = 0
            for _ in pairs(db) do n = n + 1 end
            if n > 0 then
                populate(searchBox.Text)
                break
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
--  TAB · ROULETTE
-- ══════════════════════════════════════════════════════════════
local TabSpin = Window:CreateTab("🎰  ROULETTE", nil)

local spinLastLabel = TabSpin:CreateLabel("Hasil terakhir: —")
local spinXVal, spinYVal = nil, nil

TabSpin:CreateToggle({
    Name         = "Instant Spin (skip animasi)",
    CurrentValue = true,
    Flag         = "v2_spin_instant",
    Callback     = function(v)
        STATE.instantSpin = v
        LX.FastSpin_SetInstant(v)
        note("ROULETTE", v and "Instant ON — rollTime = 0" or "Instant OFF", 2)
    end,
})

TabSpin:CreateInput({
    Name        = "Wheel X (opsional)",
    PlaceholderText = "kosongkan = cari otomatis",
    RemoveTextAfterFocusLost = false,
    Flag        = "v2_spin_x",
    Callback    = function(v)
        spinXVal = tonumber(v)
    end,
})
TabSpin:CreateInput({
    Name        = "Wheel Y (opsional)",
    PlaceholderText = "kosongkan = cari otomatis",
    RemoveTextAfterFocusLost = false,
    Flag        = "v2_spin_y",
    Callback    = function(v)
        spinYVal = tonumber(v)
    end,
})

TabSpin:CreateButton({
    Name     = "🎯  FIND NEAREST & SPIN",
    Callback = function()
        local w = LX.FindSpin()
        if not w then
            note("ROULETTE", "Tidak ada roulette/dice di world ini", 2)
            return
        end
        local ok = LX.FastSpin_Once(w.x, w.y)
        if ok then
            note("ROULETTE", string.format("Spin %s di %d,%d", tostring(w.name or "?"), w.x, w.y), 2)
        else
            note("ROULETTE", "Paket spin gagal", 2)
        end
    end,
})

TabSpin:CreateButton({
    Name     = "▶  SPIN SEKARANG",
    Callback = function()
        local ok, x, y = LX.FastSpin_Once(spinXVal, spinYVal)
        if ok then
            note("ROULETTE", string.format("Spin dikirim ke %s,%s", tostring(x), tostring(y)), 1.5)
        else
            note("ROULETTE", tostring(x or "gagal"), 2)
        end
    end,
})

local autoSpinDelay = 2.5
TabSpin:CreateSlider({
    Name         = "Auto Spin Delay",
    Range        = { 1, 20 },
    Increment    = 0.1,
    Suffix       = "s",
    CurrentValue = 2.5,
    Flag         = "v2_spin_delay",
    Callback     = function(v)
        autoSpinDelay = v
        STATE.spinDelay = v
    end,
})

TabSpin:CreateToggle({
    Name         = "Auto Spin (loop)",
    CurrentValue = false,
    Flag         = "v2_spin_auto",
    Callback     = function(v)
        if v then
            LX.AutoSpin_Start(spinXVal, spinYVal)
            note("ROULETTE", "Auto spin ON", 2)
        else
            LX.AutoSpin_Stop()
            note("ROULETTE", "Auto spin OFF", 1.5)
        end
    end,
})

local spinGui, spinNumber, spinName, spinScale = nil, nil, nil, nil
local spinHideToken = 0

local function showSpinResult(n, name)
    if not (spinGui and spinGui.Parent) then
        local gui = Instance.new("ScreenGui")
        gui.Name = "LX_SpinResult"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 75
        gui.IgnoreGuiInset = true
        gui.Parent = PG
        spinGui = gui

        local frame = Instance.new("Frame")
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Position = UDim2.fromScale(0.5, 0.32)
        frame.Size = UDim2.fromOffset(320, 210)
        frame.BackgroundColor3 = Color3.fromRGB(8, 18, 32)
        frame.BorderSizePixel = 0
        frame.Parent = gui
        local fc = Instance.new("UICorner")
        fc.CornerRadius = UDim.new(0, 12)
        fc.Parent = frame
        local fs = Instance.new("UIStroke")
        fs.Color = Color3.fromRGB(0, 180, 255)
        fs.Thickness = 2
        fs.Parent = frame

        spinScale = Instance.new("UIScale")
        spinScale.Scale = 1
        spinScale.Parent = frame

        local t = Instance.new("TextLabel")
        t.BackgroundTransparency = 1
        t.Position = UDim2.fromOffset(0, 14)
        t.Size = UDim2.new(1, 0, 0, 24)
        t.Font = Enum.Font.GothamBold
        t.TextSize = 16
        t.TextColor3 = Color3.fromRGB(120, 210, 255)
        t.Text = "🎰  SPIN RESULT"
        t.Parent = frame

        spinNumber = Instance.new("TextLabel")
        spinNumber.BackgroundTransparency = 1
        spinNumber.Position = UDim2.fromOffset(0, 42)
        spinNumber.Size = UDim2.new(1, 0, 0, 80)
        spinNumber.Font = Enum.Font.GothamBold
        spinNumber.TextSize = 64
        spinNumber.TextColor3 = Color3.fromRGB(255, 255, 255)
        spinNumber.Text = "?"
        spinNumber.Parent = frame

        spinName = Instance.new("TextLabel")
        spinName.BackgroundTransparency = 1
        spinName.Position = UDim2.fromOffset(10, 128)
        spinName.Size = UDim2.new(1, -20, 0, 40)
        spinName.Font = Enum.Font.Gotham
        spinName.TextSize = 16
        spinName.TextWrapped = true
        spinName.TextColor3 = Color3.fromRGB(170, 215, 245)
        spinName.Text = ""
        spinName.Parent = frame

        local x = Instance.new("TextButton")
        x.AnchorPoint = Vector2.new(1, 0)
        x.Position = UDim2.new(1, -8, 0, 8)
        x.Size = UDim2.fromOffset(24, 24)
        x.BackgroundTransparency = 1
        x.Font = Enum.Font.GothamBold
        x.TextSize = 16
        x.TextColor3 = Color3.fromRGB(160, 190, 220)
        x.Text = "×"
        x.Parent = frame
        x.MouseButton1Click:Connect(function()
            gui.Enabled = false
        end)
    end

    spinGui.Enabled = true
    spinNumber.Text = tostring(n ~= nil and n or "?")
    local nameText = tostring(name or "")
    spinName.Text = nameText ~= "" and nameText or "—"

    if spinScale then
        spinScale.Scale = 0.55
        TweenService:Create(spinScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    end

    spinHideToken = spinHideToken + 1
    local my = spinHideToken
    task.delay(4.5, function()
        if my == spinHideToken and spinGui and spinGui.Parent then
            spinGui.Enabled = false
        end
    end)
end

pcall(function()
    LX.FastSpin_HookResults(function(x, y, n, name, userId)
        setLabel(spinLastLabel, string.format("Hasil terakhir: %s  (%s)  @ %s,%s",
            tostring(name or "?"), tostring(n or "?"), tostring(x or "?"), tostring(y or "?")))
        showSpinResult(n, name)
        note("🎰 SPIN RESULT", tostring(name or "?") .. " → " .. tostring(n or "?"), 4)
    end)
end)

-- ══════════════════════════════════════════════════════════════
--  TAB · PROFILE
-- ══════════════════════════════════════════════════════════════
local TabProfile = Window:CreateTab("🪪  PROFILE", nil)

local nametagTextVal = ""
local nametagColorName = "White"
local nametagStyleVal = "default"
local profileStatus = TabProfile:CreateLabel("Nametag: belum dipasang")

TabProfile:CreateSection("Nametag Visual")
TabProfile:CreateInput({
    Name        = "Teks Nametag",
    PlaceholderText = "Nama yang tampil di atas karakter…",
    RemoveTextAfterFocusLost = false,
    Flag        = "v2_name_text",
    Callback    = function(v)
        nametagTextVal = v
    end,
})

TabProfile:CreateDropdown({
    Name    = "Warna",
    Options = COLOR_NAMES,
    CurrentOption = { "White" },
    Flag    = "v2_name_color",
    Callback = function(v)
        local s = type(v) == "table" and v[1] or v
        nametagColorName = tostring(s or "White")
    end,
})

TabProfile:CreateDropdown({
    Name    = "Style",
    Options = { "Default (berwarna)", "Plain (tanpa kode)" },
    CurrentOption = { "Default (berwarna)" },
    Flag    = "v2_name_style",
    Callback = function(v)
        local s = tostring(type(v) == "table" and v[1] or v or "")
        nametagStyleVal = s:find("Plain") and "plain" or "default"
    end,
})

TabProfile:CreateButton({
    Name     = "✅  PASANG NAMETAG",
    Callback = function()
        if nametagTextVal == "" then
            note("NAMETAG", "Isi teks dulu!", 2)
            return
        end
        local ok = LX.SetNametag(nametagTextVal, nametagStyleVal, colorCode(nametagColorName))
        setLabel(profileStatus, "Nametag: " .. (ok and nametagTextVal or "gagal"))
        note("NAMETAG", ok and ("Dipasang: " .. nametagTextVal) or "Gagal (backend belum siap)", 2)
    end,
})

TabProfile:CreateButton({
    Name     = "❌  HAPUS NAMETAG",
    Callback = function()
        LX.RemoveNametag()
        setLabel(profileStatus, "Nametag: belum dipasang")
        note("NAMETAG", "Dihapus", 1.5)
    end,
})

TabProfile:CreateParagraph({
    Title   = "Cara kerja",
    Content = "Nametag memakai attribute Nick lokal. Game menggambar nama di atas karakter / samping flag setiap frame, jadi perubahan langsung terlihat di client kamu.",
})

TabProfile:CreateSection("Visual Worn")
TabProfile:CreateParagraph({
    Title   = "Slot",
    Content = "Isi ID item untuk tiap slot (0 = kosong). Paket wear = map<string,uint16> dikirim ke server world.",
})

local wearSlots = { hand = 0, hat = 0, shirt = 0, pants = 0 }
for _, slot in ipairs({ "hand", "hat", "shirt", "pants" }) do
    TabProfile:CreateInput({
        Name        = "Slot " .. string.upper(slot),
        PlaceholderText = "ID item (0 = kosong)",
        RemoveTextAfterFocusLost = false,
        Flag        = "v2_wear_" .. slot,
        Callback    = function(v)
            wearSlots[slot] = tonumber(v) or 0
        end,
    })
end
TabProfile:CreateButton({
    Name     = "👕  TERAPKAN VISUAL",
    Callback = function()
        local ok = LX.WearVisual(wearSlots)
        note("WEAR", ok and "Paket visual dikirim" or "Gagal mengirim", 2)
    end,
})

-- ══════════════════════════════════════════════════════════════
--  TAB · TROLL
-- ══════════════════════════════════════════════════════════════
local TabTroll = Window:CreateTab("📢  TROLL", nil)

local announceText = ""
local trollStatus = TabTroll:CreateLabel("Announce: —")

TabTroll:CreateParagraph({
    Title   = "Announce Lintas World",
    Content = "Memakai event Broadcast game (paket server). Pesan diteruskan server ke world/dimensi lain. Butuh item Megaphone di inventory. Ini bukan chat biasa dan bukan SB.",
})

TabTroll:CreateInput({
    Name        = "Teks Announcement",
    PlaceholderText = "Pesan untuk semua world…",
    RemoveTextAfterFocusLost = false,
    Flag        = "v2_announce_text",
    Callback    = function(v)
        announceText = v
    end,
})

TabTroll:CreateButton({
    Name     = "📢  KIRIM ANNOUNCE",
    Callback = function()
        if announceText == "" then
            note("ANNOUNCE", "Isi teks dulu!", 2)
            return
        end
        local ok, err = LX.AnnounceAll(announceText)
        if ok then
            setLabel(trollStatus, "Announce: mengirim…")
            note("ANNOUNCE", "Mengirim via Broadcast…", 2)
        else
            setLabel(trollStatus, "Announce: " .. tostring(err or "gagal"))
            note("ANNOUNCE", tostring(err or "gagal"), 3)
        end
    end,
})

TabTroll:CreateSection("Voice All")
TabTroll:CreateToggle({
    Name         = "🔊  Voice All (volume suara dipaksa)",
    CurrentValue = false,
    Flag         = "v2_voiceall",
    Callback     = function(v)
        if v then LX.VoiceAll_On() else LX.VoiceAll_Off() end
        note("VOICE ALL", v and "ON — fader jarak dipaksa 1.0" or "OFF", 2)
    end,
})

TabTroll:CreateParagraph({
    Title   = "Batas Voice",
    Content = "Voice All membuka volume semua AudioFader ProximityVoice di client kamu, jadi suara player jauh tetap terdengar. Roblox memutar suara voice di client pendengar, bukan pengirim, jadi script tidak bisa memaksa client lain mendengar kita dari jauh."
})

-- ══════════════════════════════════════════════════════════════
--  TAB · ANTI-DETECT
-- ══════════════════════════════════════════════════════════════
local TabAnti = Window:CreateTab("🛡  ANTI-DETECT", nil)

local antiStatus = TabAnti:CreateLabel("Anti-Detect: OFF  |  UnlockAll: OFF")

TabAnti:CreateToggle({
    Name         = "Anti Detection",
    CurrentValue = false,
    Flag         = "v2_antidetect",
    Callback     = function(v)
        if v then LX.AntiDetect_On() else LX.AntiDetect_Off() end
        note("ANTI-DETECT", v and "ON — delay dijitter, staff watch aktif" or "OFF", 2)
    end,
})

TabAnti:CreateToggle({
    Name         = "Unlock All (client patch)",
    CurrentValue = false,
    Flag         = "v2_unlockall",
    Callback     = function(v)
        if v then LX.UnlockAll_On() else LX.UnlockAll_Off() end
        note("UNLOCK", v and "ON — dropOk/areas/Level dipatch (client)" or "OFF", 3)
    end,
})

local dropTestVal = nil
TabAnti:CreateInput({
    Name        = "Test Drop — Seed ID",
    PlaceholderText = "contoh: 12",
    RemoveTextAfterFocusLost = false,
    Flag        = "v2_drop_test_id",
    Callback    = function(v)
        dropTestVal = tonumber(v)
    end,
})
TabAnti:CreateButton({
    Name     = "🧪  TEST DROP",
    Callback = function()
        if not dropTestVal then
            note("DROP", "Isi seed ID dulu", 2)
            return
        end
        local ok, err = LX.TryDrop(dropTestVal)
        note("DROP", ok and ("Packet drop ID " .. tostring(dropTestVal) .. " terkirim") or ("Gagal: " .. tostring(err)), 3)
    end,
})

TabAnti:CreateParagraph({
    Title   = "Batas Client (jujur)",
    Content = "Level 10 + /verify untuk drop/trade dicek SERVER. Script hanya bisa mem-patch pengecekan lokal (dropOk, areas) dan attribute Level. Kalau server menolak paket, tidak ada cara client-side untuk memaksa. Anti-detect hanya menjitter delay + auto-stop saat staff terdeteksi; tidak menjamin bebas ban.",
})

-- ══════════════════════════════════════════════════════════════
--  LIVE STATUS LOOP
-- ══════════════════════════════════════════════════════════════
local lastModLogged = -1

task.spawn(function()
    while true do
        task.wait(0.3)
        pcall(function()
            local P = LX.Pos or {}
            local px = tonumber(P.x) or 0
            local py = tonumber(P.y) or 0
            local posText = string.format(
                "Posisi: X=%.2f  Y=%.2f  |  Tile: %d, %d  |  HP: %s/5%s",
                px, py, math.floor(px), math.floor(py - 1),
                tostring(P.hp or "?"), P.dead and "  (DEAD)" or ""
            )
            setLabel(tpPosLabel, posText)
            setLabel(farmPosLabel, posText)

            local z = tonumber(STATE.zoom) or 1
            setLabel(zoomStatus, string.format(
                "Zoom: %.2fx  |  Batas %.2f–%.2f  |  Unlock: %s  |  Render: %.2fx",
                z, tonumber(STATE.zoomMin) or 0, tonumber(STATE.zoomMax) or 0,
                STATE.zoomUnlock and "ON" or "OFF", tonumber(STATE.renderScale) or 0
            ))

            local cs = LX.ChatStats or {}
            setLabel(spamStatusLabel, string.format(
                "Status: %s  |  Terkirim: %d  |  Gagal: %d  |  %s",
                STATE.spamRunning and "SPAM ON" or "idle",
                tonumber(cs.sent) or 0, tonumber(cs.failed) or 0, tostring(cs.last or "")
            ))

            setLabel(farmStatus, string.format(
                "PNB: %s  |  DF: %s  |  CLEAR: %s  |  Seed: %s",
                STATE.pnbRunning and "ON" or "OFF",
                STATE.dfRunning and "ON" or "OFF",
                STATE.clearRunning and "ON" or "OFF",
                tostring(STATE.pnbSeedId or "—")
            ))
            updateGridSummary()

            setLabel(modCountLabel, string.format(
                "Deteksi: %dx  |  Status: %s  |  Aksi: %s",
                tonumber(STATE.modCount) or 0,
                STATE.modWatchOn and "ON" or "OFF",
                tostring(STATE.modAction or "SLEEP")
            ))
            if (tonumber(STATE.modCount) or 0) ~= lastModLogged then
                lastModLogged = tonumber(STATE.modCount) or 0
                local lines = {}
                for i, e in ipairs(STATE.modLog or {}) do
                    if i > 12 then break end
                    lines[#lines + 1] = string.format("[%s] %s (%s)", tostring(e.time), tostring(e.name), tostring(e.role))
                end
                setPara(modLogPara, #lines > 0 and table.concat(lines, "\n") or "(belum ada deteksi)")
            end

            local last = STATE.lastSpin
            if last then
                setLabel(spinLastLabel, string.format(
                    "Hasil terakhir: %s → %s  @ %s,%s",
                    tostring(last.name or "?"), tostring(last.n or "?"),
                    tostring(last.x or "?"), tostring(last.y or "?")
                ))
            end

            if STATE.lastAnnounce then
                local la = STATE.lastAnnounce
                setLabel(trollStatus, la.ok and ("Announce: terkirim — " .. tostring(la.text))
                    or ("Announce: gagal — " .. tostring(la.error or "server menolak")))
            end

            setLabel(antiStatus, string.format("Anti-Detect: %s  |  UnlockAll: %s",
                STATE.antiDetect and "ON" or "OFF",
                STATE.unlockAll and "ON" or "OFF"))

            local db = LX.GetItemDB and LX.GetItemDB() or {}
            local count = 0
            for _ in pairs(db) do count = count + 1 end
            setLabel(itemTabStatus, string.format("Database: %d item  |  %s", count,
                (LX.IsReady and LX.IsReady()) and "game siap" or "menunggu game"))
        end)
    end
end)

note("NX Hub v2.0", "Semua fitur memakai API game. Buka tab untuk kontrol.", 4)
