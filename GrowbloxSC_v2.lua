-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Mytzcodes/Gbxzcf0x2993HsFDj1/refs/heads/main/GrowbloxSC_v2.lua"))()
--[[
    ================================================================================
    GROWBLOX SC v2.0 · MONOLITHIC SCRIPT ENGINE
    ================================================================================
    Style       : Pixel + Minimalist + Illustrative Modern UI
    Canvas Base : 940 x 580 (Proportional UIScale Scaling)
    TopBar Safe : Sits below Roblox CoreGui TopBar (IgnoreGuiInset = false, Y >= 50)
    Tabs (7)    : Item Info · Misc · Player · Msg · Mods · Auto Farm · Settings
    Repository  : https://github.com/Mytzcodes/Gbxzcf0x2993HsFDj1
    ================================================================================
]]

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. ROBLOX SERVICES & INITIAL ENVIRONMENT
-- ════════════════════════════════════════════════════════════════════════════════
local Players         = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")
local Lighting        = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- Bersihkan instance GUI lama jika script dijalankan ulang
local oldGui = PlayerGui:FindFirstChild("GrowbloxSC_v2_UI")
if oldGui then
    oldGui:Destroy()
end

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. KONSTANTA & PALET TEMA (PIXEL MINIMALIST ART)
-- ════════════════════════════════════════════════════════════════════════════════
local BASE_WIDTH     = 940
local BASE_HEIGHT    = 580
local HEADER_HEIGHT  = 50
local SIDEMENU_WIDTH = 200

local Themes = {
    ["Pixel Emerald"] = {
        Name            = "Pixel Emerald (Default)",
        MainBg          = Color3.fromRGB(7, 10, 20),      -- #070A14 Dark Navy
        PanelBg         = Color3.fromRGB(11, 16, 28),     -- #0B101C Deep Navy Panel
        GradStart       = Color3.fromRGB(16, 32, 54),     -- #102036
        GradMid         = Color3.fromRGB(10, 18, 32),     -- #0A1220
        GradEnd         = Color3.fromRGB(6, 10, 18),      -- #060A12
        CardBg          = Color3.fromRGB(13, 17, 32),     -- #0D1120 Card Surface
        CardHover       = Color3.fromRGB(20, 28, 52),     -- #141C34 Card Hover
        InputBg         = Color3.fromRGB(9, 12, 22),      -- #090C16 Input Well
        Accent          = Color3.fromRGB(74, 222, 128),   -- #4ADE80 Pixel Green
        AccentSecondary = Color3.fromRGB(96, 165, 250),   -- #60A5FA Pixel Blue
        TextPrimary     = Color3.fromRGB(240, 245, 255),  -- #F0F5FF Crisp White
        TextSecondary   = Color3.fromRGB(148, 163, 184),  -- #94A3B8 Silver Slate
        TextMuted       = Color3.fromRGB(100, 116, 139),  -- #64748B Muted Steel
        Stroke          = Color3.fromRGB(28, 40, 68),     -- #1C2844 Hairline Border
        ToggleOn        = Color3.fromRGB(74, 222, 128),   -- #4ADE80
        ToggleOff       = Color3.fromRGB(36, 44, 62),     -- #242C3E
        Danger          = Color3.fromRGB(239, 68, 68),    -- #EF4444 Red
    },
    ["Cyber Cyan"] = {
        Name            = "Cyber Cyan",
        MainBg          = Color3.fromRGB(6, 12, 24),
        PanelBg         = Color3.fromRGB(10, 18, 36),
        GradStart       = Color3.fromRGB(14, 34, 64),
        GradMid         = Color3.fromRGB(8, 20, 40),
        GradEnd         = Color3.fromRGB(5, 10, 22),
        CardBg          = Color3.fromRGB(14, 24, 46),
        CardHover       = Color3.fromRGB(22, 38, 72),
        InputBg         = Color3.fromRGB(8, 14, 28),
        Accent          = Color3.fromRGB(56, 189, 248),   -- #38BDF8 Sky Cyan
        AccentSecondary = Color3.fromRGB(129, 140, 248),  -- #818CF8 Indigo
        TextPrimary     = Color3.fromRGB(245, 250, 255),
        TextSecondary   = Color3.fromRGB(140, 165, 200),
        TextMuted       = Color3.fromRGB(90, 110, 140),
        Stroke          = Color3.fromRGB(30, 52, 90),
        ToggleOn        = Color3.fromRGB(56, 189, 248),
        ToggleOff       = Color3.fromRGB(30, 42, 65),
        Danger          = Color3.fromRGB(239, 68, 68),
    },
    ["Monochrome Pixel"] = {
        Name            = "Monochrome Pixel",
        MainBg          = Color3.fromRGB(10, 10, 13),
        PanelBg         = Color3.fromRGB(16, 16, 20),
        GradStart       = Color3.fromRGB(28, 28, 34),
        GradMid         = Color3.fromRGB(18, 18, 22),
        GradEnd         = Color3.fromRGB(9, 9, 12),
        CardBg          = Color3.fromRGB(22, 22, 28),
        CardHover       = Color3.fromRGB(32, 32, 40),
        InputBg         = Color3.fromRGB(12, 12, 15),
        Accent          = Color3.fromRGB(224, 224, 230),
        AccentSecondary = Color3.fromRGB(150, 150, 160),
        TextPrimary     = Color3.fromRGB(250, 250, 250),
        TextSecondary   = Color3.fromRGB(165, 165, 175),
        TextMuted       = Color3.fromRGB(105, 105, 115),
        Stroke          = Color3.fromRGB(44, 44, 54),
        ToggleOn        = Color3.fromRGB(224, 224, 230),
        ToggleOff       = Color3.fromRGB(40, 40, 50),
        Danger          = Color3.fromRGB(220, 60, 60),
    },
    ["Neon Sunset"] = {
        Name            = "Neon Sunset",
        MainBg          = Color3.fromRGB(18, 10, 18),
        PanelBg         = Color3.fromRGB(26, 14, 26),
        GradStart       = Color3.fromRGB(45, 18, 38),
        GradMid         = Color3.fromRGB(28, 12, 24),
        GradEnd         = Color3.fromRGB(14, 7, 14),
        CardBg          = Color3.fromRGB(32, 18, 32),
        CardHover       = Color3.fromRGB(46, 26, 46),
        InputBg         = Color3.fromRGB(16, 8, 16),
        Accent          = Color3.fromRGB(244, 63, 94),   -- #F43F5E Rose Red
        AccentSecondary = Color3.fromRGB(251, 146, 60),  -- #FB923C Amber
        TextPrimary     = Color3.fromRGB(255, 245, 248),
        TextSecondary   = Color3.fromRGB(205, 160, 180),
        TextMuted       = Color3.fromRGB(135, 100, 120),
        Stroke          = Color3.fromRGB(68, 30, 55),
        ToggleOn        = Color3.fromRGB(244, 63, 94),
        ToggleOff       = Color3.fromRGB(50, 32, 45),
        Danger          = Color3.fromRGB(244, 63, 94),
    }
}

local ThemeOrder = {
    "Pixel Emerald",
    "Cyber Cyan",
    "Monochrome Pixel",
    "Neon Sunset"
}

-- ── Rarity Color & Rank Helpers ───────────────────────────────────────────────
local RARITY_COLOR = {
    common    = Color3.fromRGB(220, 220, 220),
    uncommon  = Color3.fromRGB(100, 220, 100),
    rare      = Color3.fromRGB(80,  160, 255),
    epic      = Color3.fromRGB(180, 80,  255),
    legendary = Color3.fromRGB(255, 180, 40),
    mythic    = Color3.fromRGB(255, 80,  80),
    divine    = Color3.fromRGB(80,  255, 240),
    celestial = Color3.fromRGB(255, 230, 100),
    unknown   = Color3.fromRGB(160, 160, 160),
}

local RARITY_RANK = {
    common    = 1, uncommon = 2, rare    = 3, epic   = 4,
    legendary = 5, mythic   = 6, divine  = 7, celestial = 8,
    unknown   = 0,
}

-- ── Central State ─────────────────────────────────────────────────────────────
local State = {
    ThemeIndex      = 1,
    UserZoomFactor  = 0.85,
    CurrentTab      = "item",
    IsMinimized     = false,
    SideMenuOpen    = false,
    AutoReload      = false,

    -- Parameter Gameplay & SC Defaults
    FlySpeed        = 32,
    FlyVertical     = 20,
    SpeedMult       = 2.5,
    JumpMult        = 2.0,
    AntiGravForce   = 50,
    FarmDelay       = 0.08,
    CollectMethod   = "teleport", -- "teleport" | "walk"
    WebhookURL      = "",
    MacroDelay      = 1.5,
    SaveKey         = "GrowbloxSC_v2_SavedConfig",
}

-- ── Theme Registry ────────────────────────────────────────────────────────────
local ThemeCallbacks = {}
local function getTheme()
    return Themes[ThemeOrder[State.ThemeIndex]]
end

local function registerThemeUpdater(fn)
    table.insert(ThemeCallbacks, fn)
    fn(getTheme())
end

local function broadcastTheme()
    local t = getTheme()
    for _, fn in ipairs(ThemeCallbacks) do
        fn(t)
    end
end

-- ════════════════════════════════════════════════════════════════════════════════
-- 3. TWEEN PRESETS & UI HELPER BUILDERS
-- ════════════════════════════════════════════════════════════════════════════════
local TweenFast   = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenSmooth = TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TweenSpring = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TweenStiff  = TweenInfo.new(0.20, Enum.EasingStyle.Linear)

local function create(className, properties)
    local inst = Instance.new(className)
    for k, v in pairs(properties) do
        inst[k] = v
    end
    return inst
end

local function addCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 4), -- Pixel boxy aesthetic (4px default)
        Parent = parent
    })
end

local function addStroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or Color3.fromRGB(30, 42, 68),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
end

local function addPadding(parent, top, bottom, left, right)
    return create("UIPadding", {
        PaddingTop = UDim.new(0, top or 8),
        PaddingBottom = UDim.new(0, bottom or 8),
        PaddingLeft = UDim.new(0, left or 8),
        PaddingRight = UDim.new(0, right or 8),
        Parent = parent
    })
end

local function attachGradient(parent, rotation)
    local grad = create("UIGradient", {
        Rotation = rotation or 25,
        Parent = parent
    })
    registerThemeUpdater(function(t)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, t.GradStart),
            ColorSequenceKeypoint.new(0.5, t.GradMid),
            ColorSequenceKeypoint.new(1.0, t.GradEnd),
        })
    end)
    return grad
end

local function addHoverEffect(btn, defaultColor, hoverColor)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenFast, { BackgroundColor3 = hoverColor }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenFast, { BackgroundColor3 = defaultColor }):Play()
    end)
end

-- Clipboard Safe Helper
local function copyToClipboard(str)
    local ok = pcall(function()
        if setclipboard then
            setclipboard(str)
        elseif toclipboard then
            toclipboard(str)
        elseif syn and syn.write_clipboard then
            syn.write_clipboard(str)
        end
    end)
    return ok
end

-- ════════════════════════════════════════════════════════════════════════════════
-- 4. UNIVERSAL DRAGGING
-- ════════════════════════════════════════════════════════════════════════════════
local function makeDraggable(handle, target, onClick)
    local dragging = false
    local dragInput = nil
    local dragStart = Vector3.zero
    local startPos = UDim2.new()
    local movedDist = 0

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            movedDist = 0

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if movedDist < 6 and onClick then
                        onClick()
                    end
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            movedDist = delta.Magnitude
            target.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                math.max(52, startPos.Y.Offset + delta.Y) -- Jaga agar jendela selalu berada di bawah topbar
            )
        end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- 5. SCREEN GUI & ROOT CANVAS SETUP
-- ════════════════════════════════════════════════════════════════════════════════
local ScreenGui = create("ScreenGui", {
    Name = "GrowbloxSC_v2_UI",
    DisplayOrder = 9999,
    IgnoreGuiInset = false, -- Sesuai persyaratan: JANGAN sembunyikan topbar & hindari overlap
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = PlayerGui
})

-- Canvas Utama Proporsional
local HUDCanvas = create("Frame", {
    Name = "HUDCanvasProportional",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 52), -- Berada di Y=52 (dibawah topbar Roblox)
    Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT),
    BackgroundColor3 = Color3.fromRGB(7, 10, 20),
    ClipsDescendants = true,
    Visible = false,
    Active = true,
    ZIndex = 50,
    Parent = ScreenGui
})
addCorner(HUDCanvas, 4)
attachGradient(HUDCanvas, 140)
local hudStroke = addStroke(HUDCanvas, Color3.fromRGB(28, 40, 68), 1.2)

-- Proportional UIScale Controller
local ProportionalUIScale = create("UIScale", {
    Scale = 1,
    Parent = HUDCanvas
})

local ResizeHintLabel = nil
local HeaderScaleBadge = nil

local function computeAndApplyProportionalScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    -- BASE_WIDTH x BASE_HEIGHT discale proporsional sesuai UserZoomFactor
    local fitScaleX = (vp.X * State.UserZoomFactor) / BASE_WIDTH
    local fitScaleY = ((vp.Y - 56) * State.UserZoomFactor) / BASE_HEIGHT
    local finalScale = math.clamp(math.min(fitScaleX, fitScaleY), 0.42, 1.25)

    ProportionalUIScale.Scale = finalScale

    local pct = math.round(State.UserZoomFactor * 100)
    if ResizeHintLabel then
        ResizeHintLabel.Text = string.format("⤡ %d%%", pct)
    end
    if HeaderScaleBadge then
        HeaderScaleBadge.Text = string.format("%d%% View", pct)
    end
end

if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(computeAndApplyProportionalScale)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- 6. STARTUP LOADER (PIXEL GRID 8x8 + MONOGRAM ART + PROGRESS BAR)
-- ════════════════════════════════════════════════════════════════════════════════
local StartupOverlay = create("Frame", {
    Name = "StartupIllustrationScreen",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 52),
    Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT),
    BackgroundColor3 = Color3.fromRGB(7, 10, 20),
    ClipsDescendants = true,
    Visible = true,
    Active = true,
    ZIndex = 100,
    Parent = ScreenGui
})
addCorner(StartupOverlay, 4)
attachGradient(StartupOverlay, 135)
local startupStroke = addStroke(StartupOverlay, Color3.fromRGB(28, 40, 68), 1.5)

local StartupUIScale = create("UIScale", {
    Scale = 1,
    Parent = StartupOverlay
})

-- Center Art Container
local PixelArtContainer = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.42),
    Size = UDim2.fromOffset(160, 160),
    BackgroundTransparency = 1,
    ZIndex = 3,
    Parent = StartupOverlay
})

-- Grid 8x8 Pixel Squares
local pixelGridCells = {}
local pixelGridLayout = create("UIGridLayout", {
    CellSize = UDim2.fromOffset(16, 16),
    CellPadding = UDim2.fromOffset(3, 3),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Parent = PixelArtContainer
})

for row = 1, 8 do
    for col = 1, 8 do
        local px = create("Frame", {
            Name = string.format("Px_%d_%d", row, col),
            BackgroundColor3 = Color3.fromRGB(16, 24, 42),
            BorderSizePixel = 0,
            ZIndex = 4,
            Parent = PixelArtContainer
        })
        addCorner(px, 2)
        table.insert(pixelGridCells, px)
    end
end

-- Logo SC Monogram di tengah Pixel Grid
local LogoBadge = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(90, 48),
    BackgroundColor3 = Color3.fromRGB(7, 10, 20),
    TextColor3 = Color3.fromRGB(74, 222, 128),
    Font = Enum.Font.GothamBold,
    TextSize = 22,
    Text = "🌱 SC",
    ZIndex = 6,
    Parent = PixelArtContainer
})
addCorner(LogoBadge, 3)
local logoStroke = addStroke(LogoBadge, Color3.fromRGB(74, 222, 128), 1.2)

local IntroTitle = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.62, 0),
    Size = UDim2.fromOffset(400, 26),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(240, 245, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    Text = "GROWBLOX SC · v2.0",
    ZIndex = 4,
    Parent = StartupOverlay
})

local IntroSubtitle = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.68, 0),
    Size = UDim2.fromOffset(400, 18),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(148, 163, 184),
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    Text = "Pixel Precision & Advanced Game Engine Automation",
    ZIndex = 4,
    Parent = StartupOverlay
})

-- Progress Bar Minimalis
local IntroProgressBg = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.77, 0),
    Size = UDim2.fromOffset(340, 6),
    BackgroundColor3 = Color3.fromRGB(13, 17, 32),
    BorderSizePixel = 0,
    ZIndex = 4,
    Parent = StartupOverlay
})
addCorner(IntroProgressBg, 3)
addStroke(IntroProgressBg, Color3.fromRGB(28, 40, 68), 1)

local IntroProgressFill = create("Frame", {
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = Color3.fromRGB(74, 222, 128),
    BorderSizePixel = 0,
    ZIndex = 5,
    Parent = IntroProgressBg
})
addCorner(IntroProgressFill, 3)

local IntroStatusText = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.81, 0),
    Size = UDim2.fromOffset(340, 18),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(100, 116, 139),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    Text = "Initializing Subsystems... 0%",
    ZIndex = 4,
    Parent = StartupOverlay
})

local SkipIntroBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -20, 1, -16),
    Size = UDim2.fromOffset(104, 30),
    BackgroundColor3 = Color3.fromRGB(13, 17, 32),
    TextColor3 = Color3.fromRGB(240, 245, 255),
    Font = Enum.Font.GothamMedium,
    TextSize = 11,
    Text = "Skip Intro ⏩",
    AutoButtonColor = false,
    ZIndex = 6,
    Parent = StartupOverlay
})
addCorner(SkipIntroBtn, 4)
local skipStroke = addStroke(SkipIntroBtn, Color3.fromRGB(28, 40, 68), 1)
addHoverEffect(SkipIntroBtn, Color3.fromRGB(13, 17, 32), Color3.fromRGB(22, 32, 56))

registerThemeUpdater(function(t)
    hudStroke.Color = t.Stroke
    startupStroke.Color = t.Stroke
    logoStroke.Color = t.Accent
    LogoBadge.TextColor3 = t.Accent
    IntroTitle.TextColor3 = t.TextPrimary
    IntroSubtitle.TextColor3 = t.TextSecondary
    IntroProgressBg.BackgroundColor3 = t.InputBg
    IntroProgressFill.BackgroundColor3 = t.Accent
    IntroStatusText.TextColor3 = t.TextMuted
    SkipIntroBtn.BackgroundColor3 = t.CardBg
    SkipIntroBtn.TextColor3 = t.TextPrimary
    skipStroke.Color = t.Stroke
end)

-- ════════════════════════════════════════════════════════════════════════════════
-- 7. SUBSISTEM CORE (INLINE MODULES)
-- ════════════════════════════════════════════════════════════════════════════════

-- ── 7.1 Net & ByteNet Packet Helpers ──────────────────────────────────────────
local NetInstance = nil
local function getNet()
    if NetInstance then return NetInstance end
    local ok, n = pcall(function()
        return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"))
    end)
    if ok and n then NetInstance = n end
    return NetInstance
end

local function getNetWorld()
    local n = getNet()
    return n and n.World or nil
end

local function sendAct(kind, x, y)
    local w = getNetWorld()
    if w and w.act then
        pcall(function() w.act.send({ kind = kind, x = x, y = y }) end)
    end
end

local function sendHarvest(x, y)
    local w = getNetWorld()
    if w and w.harvest then
        pcall(function() w.harvest.send({ x = x, y = y }) end)
    end
end

local function sendPlace(layer, x, y, id, flip)
    local w = getNetWorld()
    if w and w.tile then
        pcall(function() w.tile.send({ layer = layer, x = x, y = y, id = id, flip = flip or false }) end)
    end
end

local function sendTake(uid, want)
    local w = getNetWorld()
    if w and w.take then
        pcall(function() w.take.send({ seq = 0, uid = uid, want = want or 999 }) end)
    end
end

-- ── 7.2 Item Search Subsystem ─────────────────────────────────────────────────
local function getItemDB()
    local ok, db = pcall(function()
        return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemDB"))
    end)
    return (ok and type(db) == "table") and db or {}
end

local function fuzzyMatch(name, query)
    local lname = name:lower()
    for word in query:lower():gmatch("%S+") do
        if not lname:find(word, 1, true) then
            return false
        end
    end
    return true
end

local function searchItemDB(query)
    local db = getItemDB()
    local q = (query or ""):match("^%s*(.-)%s*$")
    local results = {}

    for id, item in pairs(db) do
        if type(item) == "table" then
            local name = item.name or tostring(id)
            if q == "" or fuzzyMatch(name, q) then
                table.insert(results, {
                    id     = id,
                    name   = name,
                    rarity = (item.rarity or "unknown"):lower(),
                    item   = item
                })
            end
        end
    end

    table.sort(results, function(a, b)
        local ra = RARITY_RANK[a.rarity] or 0
        local rb = RARITY_RANK[b.rarity] or 0
        if ra ~= rb then return ra > rb end
        return a.name:lower() < b.name:lower()
    end)

    return results
end

-- ── 7.3 Misc & Player Movement Logic ──────────────────────────────────────────
local MiscState = {
    fly          = false,
    noclip       = false,
    nodeath      = false,
    fastpull     = false,
    nodetect     = false,
    fastroulette = false,
    speed        = false,
    jump         = false,
    antigravity  = false,
}

local miscConnections = {}
local function addMiscConn(c)
    table.insert(miscConnections, c)
end

local function clearMiscConns()
    for _, c in ipairs(miscConnections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(miscConnections)
end

local function getCharParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    return char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

-- Fly Handler
local flyBodyVel, flyBodyGyr = nil, nil
local function startFly()
    local hrp, hum = getCharParts()
    if not hrp or not hum then return end
    hum.PlatformStand = true

    flyBodyVel = create("BodyVelocity", {
        MaxForce = Vector3.new(1e5, 1e5, 1e5),
        Velocity = Vector3.zero,
        Parent = hrp
    })
    flyBodyGyr = create("BodyGyro", {
        MaxTorque = Vector3.new(1e5, 1e5, 1e5),
        CFrame = hrp.CFrame,
        P = 1e4,
        Parent = hrp
    })

    local c = RunService.Heartbeat:Connect(function()
        if not flyBodyVel or not flyBodyVel.Parent then return end
        local cam = workspace.CurrentCamera
        if not cam then return end

        local speed = State.FlySpeed
        local vspeed = State.FlyVertical
        local dir = Vector3.zero
        local flat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + flat end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - flat end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector * Vector3.new(1,0,1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector * Vector3.new(1,0,1) end

        local vy = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vy = vspeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then vy = -vspeed end

        if dir.Magnitude > 0 then dir = dir.Unit end
        flyBodyVel.Velocity = dir * speed + Vector3.new(0, vy, 0)
        flyBodyGyr.CFrame = cam.CFrame
    end)
    addMiscConn(c)
end

local function stopFly()
    local _, hum = getCharParts()
    if hum then hum.PlatformStand = false end
    if flyBodyVel and flyBodyVel.Parent then flyBodyVel:Destroy() end
    if flyBodyGyr and flyBodyGyr.Parent then flyBodyGyr:Destroy() end
    flyBodyVel = nil
    flyBodyGyr = nil
end

-- NoClip Handler
local noClipConn = nil
local savedNoClipPos = nil
local function startNoClip()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then savedNoClipPos = hrp.CFrame end

    noClipConn = RunService.Stepped:Connect(function()
        local c = LocalPlayer.Character
        if not c then return end
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
    addMiscConn(noClipConn)

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local dc
        dc = hum.Died:Connect(function()
            pcall(function() dc:Disconnect() end)
            task.wait(0.5)
            local newChar = LocalPlayer.Character
            if newChar and savedNoClipPos then
                local nhrp = newChar:FindFirstChild("HumanoidRootPart")
                if nhrp then
                    task.wait(0.1)
                    nhrp.CFrame = savedNoClipPos
                end
            end
        end)
        addMiscConn(dc)
    end
end

local function stopNoClip()
    if noClipConn then
        noClipConn:Disconnect()
        noClipConn = nil
    end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end

-- NoDeath Handler
local noDeathConn = nil
local function startNoDeath()
    noDeathConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if hum.Health < hum.MaxHealth then
                hum.Health = hum.MaxHealth
            end
        end
    end)
    addMiscConn(noDeathConn)
end

local function stopNoDeath()
    if noDeathConn then
        noDeathConn:Disconnect()
        noDeathConn = nil
    end
end

-- FastPull Handler
local fastPullClickConn = nil
local function startFastPull()
    fastPullClickConn = UserInputService.InputBegan:Connect(function(input)
        if not MiscState.fastpull or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local cam = workspace.CurrentCamera
        local mouse = LocalPlayer:GetMouse()
        if not cam or not mouse then return end

        local unitRay = cam:ScreenPointToRay(mouse.X, mouse.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local selfChar = LocalPlayer.Character
        if selfChar then params.FilterDescendantsInstances = { selfChar } end

        local res = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1200, params)
        if res and res.Instance then
            local targetModel = res.Instance:FindFirstAncestorOfClass("Model")
            if targetModel then
                local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
                if targetPlayer and targetPlayer ~= LocalPlayer then
                    local thrp = targetModel:FindFirstChild("HumanoidRootPart")
                    local mhrp = selfChar and selfChar:FindFirstChild("HumanoidRootPart")
                    if thrp and mhrp then
                        mhrp.CFrame = thrp.CFrame + Vector3.new(2, 0, 0)
                    end
                end
            end
        end
    end)
    addMiscConn(fastPullClickConn)
end

local function stopFastPull()
    if fastPullClickConn then
        fastPullClickConn:Disconnect()
        fastPullClickConn = nil
    end
end

-- NoDetect Handler
local noDetectConn = nil
local function startNoDetect()
    noDetectConn = RunService.Heartbeat:Connect(function()
        local p = LocalPlayer
        for _, attr in ipairs({"_speedFlag", "_flyFlag", "_noclipFlag", "_modFlag"}) do
            if p:GetAttribute(attr) ~= nil then
                pcall(function() p:SetAttribute(attr, nil) end)
            end
        end
    end)
    addMiscConn(noDetectConn)
end

local function stopNoDetect()
    if noDetectConn then
        noDetectConn:Disconnect()
        noDetectConn = nil
    end
end

-- FastRoulette Handler
local function startFastRoulette()
    local function hookChar(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local anim = hum and hum:FindFirstChildOfClass("Animator")
        if not anim then return end
        local c = anim.AnimationPlayed:Connect(function(track)
            local name = track.Name:lower()
            if name:find("roulette") or name:find("wheel") or name:find("spin") then
                pcall(function() track:Stop(0) end)
            end
        end)
        addMiscConn(c)
    end

    for _, p in ipairs(Players:GetPlayers()) do
        hookChar(p.Character)
        local c = p.CharacterAdded:Connect(hookChar)
        addMiscConn(c)
    end
    local pc = Players.PlayerAdded:Connect(function(p)
        local c2 = p.CharacterAdded:Connect(hookChar)
        addMiscConn(c2)
    end)
    addMiscConn(pc)
end

-- Speed & Jump Handlers
local origWalkSpeed = 16
local origJumpPower = 50

local function startSpeed()
    local function apply(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            origWalkSpeed = hum.WalkSpeed
            hum.WalkSpeed = origWalkSpeed * State.SpeedMult
            local c = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if MiscState.speed then
                    hum.WalkSpeed = origWalkSpeed * State.SpeedMult
                end
            end)
            addMiscConn(c)
        end
    end
    apply(LocalPlayer.Character)
    local c = LocalPlayer.CharacterAdded:Connect(apply)
    addMiscConn(c)
end

local function stopSpeed()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = origWalkSpeed end
    end
end

local function startJump()
    local function apply(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            origJumpPower = hum.JumpPower
            hum.JumpPower = origJumpPower * State.JumpMult
            local c = hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
                if MiscState.jump then
                    hum.JumpPower = origJumpPower * State.JumpMult
                end
            end)
            addMiscConn(c)
        end
    end
    apply(LocalPlayer.Character)
    local c = LocalPlayer.CharacterAdded:Connect(apply)
    addMiscConn(c)
end

local function stopJump()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = origJumpPower end
    end
end

-- AntiGravity Handler
local agConn = nil
local function startAntiGravity()
    agConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end

        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            local bv = hrp:FindFirstChild("AgBv") or Instance.new("BodyVelocity")
            bv.Name = "AgBv"
            bv.MaxForce = Vector3.new(0, 1e5, 0)
            bv.Velocity = Vector3.new(0, State.AntiGravForce, 0)
            bv.Parent = hrp
        else
            local bv = hrp:FindFirstChild("AgBv")
            if bv then bv:Destroy() end
        end
    end)
    addMiscConn(agConn)
end

local function stopAntiGravity()
    if agConn then
        agConn:Disconnect()
        agConn = nil
    end
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("AgBv")
            if bv then bv:Destroy() end
        end
    end
end

-- Misc Toggle Dispatch Table
local MISC_ACTIONS = {
    fly          = { on = startFly,          off = stopFly          },
    noclip       = { on = startNoClip,       off = stopNoClip       },
    nodeath      = { on = startNoDeath,      off = stopNoDeath      },
    fastpull     = { on = startFastPull,     off = stopFastPull     },
    nodetect     = { on = startNoDetect,     off = stopNoDetect     },
    fastroulette = { on = startFastRoulette, off = function() end   },
    speed        = { on = startSpeed,        off = stopSpeed        },
    jump         = { on = startJump,         off = stopJump         },
    antigravity  = { on = startAntiGravity,  off = stopAntiGravity  },
}

local function toggleMiscFeature(key, val)
    local act = MISC_ACTIONS[key]
    if not act then return end
    local current = MiscState[key]
    local target = (val ~= nil) and val or (not current)
    MiscState[key] = target
    if target then act.on() else act.off() end
end

-- ── 7.4 Player & Clothes Subsystem ────────────────────────────────────────────
local function getGamePlayerName()
    local p = LocalPlayer
    local gameAttr = p:GetAttribute("GameName")
    return tostring(gameAttr or p.DisplayName)
end

local function getPlayerPosition()
    local char = LocalPlayer.Character
    if not char then return 0, 0, 0 end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0, 0, 0 end
    return math.round(hrp.Position.X * 10) / 10,
           math.round(hrp.Position.Y * 10) / 10,
           math.round(hrp.Position.Z * 10) / 10
end

local RAINBOW_COLORS = {
    Color3.fromRGB(255, 80,  80),
    Color3.fromRGB(255, 180, 60),
    Color3.fromRGB(255, 255, 60),
    Color3.fromRGB(80,  220, 80),
    Color3.fromRGB(60,  180, 255),
    Color3.fromRGB(160, 80,  255),
    Color3.fromRGB(255, 80,  200),
}

local currentNameMode = "normal"
local nameOverrideBillboards = {}
local rbwConn = nil
local rbwTime = 0

local function clearNameOverride()
    for _, bb in ipairs(nameOverrideBillboards) do
        if bb and bb.Parent then bb:Destroy() end
    end
    table.clear(nameOverrideBillboards)
    if rbwConn then
        rbwConn:Disconnect()
        rbwConn = nil
    end
end

local function applyNameChanger(mode)
    clearNameOverride()
    currentNameMode = mode
    if mode == "normal" then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local bb = create("BillboardGui", {
        Name = "SC_NameTagOverride",
        Size = UDim2.fromOffset(220, 32),
        StudsOffset = Vector3.new(0, 2.8, 0),
        AlwaysOnTop = false,
        ResetOnSpawn = false,
        Parent = hrp
    })

    local lbl = create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextStrokeTransparency = 0.4,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
        Parent = bb
    })
    table.insert(nameOverrideBillboards, bb)

    local baseName = getGamePlayerName()
    if mode == "rainbow" then
        lbl.TextColor3 = RAINBOW_COLORS[1]
        lbl.Text = baseName
        rbwConn = RunService.Heartbeat:Connect(function(dt)
            rbwTime = rbwTime + dt
            local idx = math.floor((rbwTime / 1.4) * #RAINBOW_COLORS) % #RAINBOW_COLORS + 1
            lbl.TextColor3 = RAINBOW_COLORS[idx]
        end)
    elseif mode == "prefix_D" then
        lbl.TextColor3 = Color3.fromRGB(255, 180, 40)
        lbl.Text = "@D " .. baseName
    elseif mode == "prefix_S" then
        lbl.TextColor3 = Color3.fromRGB(100, 220, 100)
        lbl.Text = "@S " .. baseName
    elseif mode == "red" then
        lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
        lbl.Text = baseName
    elseif mode == "cyan" then
        lbl.TextColor3 = Color3.fromRGB(80, 220, 255)
        lbl.Text = baseName
    elseif mode == "gold" then
        lbl.TextColor3 = Color3.fromRGB(255, 215, 50)
        lbl.Text = baseName
    elseif mode == "purple" then
        lbl.TextColor3 = Color3.fromRGB(180, 80, 255)
        lbl.Text = baseName
    end

    LocalPlayer.CharacterAdded:Once(function()
        task.wait(0.5)
        applyNameChanger(currentNameMode)
    end)
end

-- Clothes Visual Engine
local wornClothes = {}
local function getClothesDB()
    local ok, db = pcall(function()
        return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ClothesDB"))
    end)
    return (ok and type(db) == "table") and db or {}
end

-- ── 7.5 Chat & Macro Subsystem ────────────────────────────────────────────────
local function sendChatMsg(text)
    local ok = false
    local worldName = LocalPlayer:GetAttribute("World") or ""
    if worldName ~= "" then
        local wc = TextChatService:FindFirstChild("WorldChannels")
        if wc then
            local ch = wc:FindFirstChild(worldName)
            if ch then
                pcall(function() ch:SendAsync(text) end)
                ok = true
            end
        end
    end
    if not ok then
        local dc = TextChatService.DefaultChannel
        if dc then pcall(function() dc:SendAsync(text) end) end
    end
end

local CHAT_COLOR_CODES = {
    "0","1","2","3","4","5","6","7","8","9",
    "!","@","#","$","^","o","p","q","e","r","t","a","s","c","d","m","v","w","&"
}

local function applyWordColors(text)
    local parts = {}
    for word in text:gmatch("%S+") do
        local code = CHAT_COLOR_CODES[math.random(1, #CHAT_COLOR_CODES)]
        table.insert(parts, "`" .. code .. word .. "``")
    end
    return table.concat(parts, " ")
end

local function applyCharColors(text)
    local result = ""
    for c in text:gmatch(".") do
        if c == " " then
            result = result .. " "
        else
            local code = CHAT_COLOR_CODES[math.random(1, #CHAT_COLOR_CODES)]
            result = result .. "`" .. code .. c .. "``"
        end
    end
    return result
end

local macroRunning = false
local macroThread = nil
local function stopMacro()
    macroRunning = false
    if macroThread then
        pcall(task.cancel, macroThread)
        macroThread = nil
    end
end

-- ── 7.6 Mods Monitor Subsystem ────────────────────────────────────────────────
local ModState = {
    autoStop      = false,
    avoidSleep    = false,
    notifyOnEnter = true,
}

local function isPlayerMod(plr)
    local tag = plr:GetAttribute("Tag")
    return tag == "moderator" or tag == "developer"
end

local function getOnlineMods()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if isPlayerMod(plr) then table.insert(list, plr) end
    end
    return list
end

local function isModNearby(radiusTiles)
    local radius = radiusTiles or 30
    local char = LocalPlayer.Character
    if not char then return false end
    local myHrp = char:FindFirstChild("HumanoidRootPart")
    if not myHrp then return false end

    for _, plr in ipairs(getOnlineMods()) do
        local tchar = plr.Character
        local thrp = tchar and tchar:FindFirstChild("HumanoidRootPart")
        if thrp and (thrp.Position - myHrp.Position).Magnitude < radius then
            return true
        end
    end
    return false
end

-- ── 7.7 Auto Farm Subsystem ───────────────────────────────────────────────────
local FarmStats = {
    seedsPlaced    = 0,
    seedsHarvested = 0,
    gemsCollected  = 0,
    itemsCollected = 0,
    runsCompleted  = 0,
}

local onFarmStatsChanged = nil
local function bumpFarmStat(key, amount)
    FarmStats[key] = (FarmStats[key] or 0) + (amount or 1)
    if onFarmStatsChanged then task.defer(onFarmStatsChanged) end
end

local function sendDiscordWebhook(msg)
    local url = State.WebhookURL
    if url == "" then return end
    pcall(function()
        HttpService:PostAsync(url, HttpService:JSONEncode({ content = msg }), Enum.HttpContentType.ApplicationJson)
    end)
end

local farmRunning = false
local farmThread = nil

local function shouldPauseFarm()
    return ModState.avoidSleep and isModNearby(35)
end

local function waitFarmDelay()
    while shouldPauseFarm() do
        task.wait(0.5)
    end
    task.wait(State.FarmDelay)
end

local function moveCharacterToTile(tx, ty)
    local char = LocalPlayer.Character
    if not char then return end
    if State.CollectMethod == "teleport" then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(tx * 2, ty * -2 + 20, hrp.Position.Z)
            task.wait(0.04)
        end
    else
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:MoveTo(Vector3.new(tx * 2, ty * -2 + 20, 0))
            task.wait(0.25)
        end
    end
end

local function runFarmPNB(seedId, onDone)
    local w = LocalPlayer:GetAttribute("WorldW") or 100
    local h = LocalPlayer:GetAttribute("WorldH") or 60
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if not farmRunning then return end
            waitFarmDelay()

            moveCharacterToTile(x, y)
            sendAct(1, x * 2, y * -2) -- Break FG
            waitFarmDelay()

            if seedId and seedId > 0 then
                sendPlace(1, x, y, seedId, false)
                bumpFarmStat("seedsPlaced")
                waitFarmDelay()
            end

            sendTake(0, 999)
            bumpFarmStat("itemsCollected")
        end
    end
    bumpFarmStat("runsCompleted")
    if onDone then onDone() end
end

local function runFarmDF()
    local w = LocalPlayer:GetAttribute("WorldW") or 100
    local h = LocalPlayer:GetAttribute("WorldH") or 60
    local DIRT_ID = 2
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if not farmRunning then return end
            waitFarmDelay()
            moveCharacterToTile(x, y)
            sendAct(1, x * 2, y * -2)
            waitFarmDelay()
            sendPlace(0, x, y, DIRT_ID, false)
        end
    end
    bumpFarmStat("runsCompleted")
end

local function runFarmClear()
    local w = LocalPlayer:GetAttribute("WorldW") or 100
    local h = LocalPlayer:GetAttribute("WorldH") or 60
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if not farmRunning then return end
            waitFarmDelay()
            moveCharacterToTile(x, y)
            sendAct(1, x * 2, y * -2)
            waitFarmDelay()
            sendTake(0, 999)
            bumpFarmStat("itemsCollected")
        end
    end
    bumpFarmStat("runsCompleted")
end

local function runFarmPabrik(seedId)
    for y = 0, 15 do
        for x = 0, 15 do
            if not farmRunning then return end
            waitFarmDelay()
            moveCharacterToTile(x, y)
            sendHarvest(x * 2, y * -2)
            bumpFarmStat("seedsHarvested")
            waitFarmDelay()
            sendTake(0, 999)
            bumpFarmStat("itemsCollected")
            waitFarmDelay()
            if seedId and seedId > 0 then
                sendPlace(1, x, y, seedId, false)
                bumpFarmStat("seedsPlaced")
            end
        end
    end
    bumpFarmStat("runsCompleted")
end

local function runFarmSplice(seedA, seedB)
    local w = LocalPlayer:GetAttribute("WorldW") or 100
    local h = LocalPlayer:GetAttribute("WorldH") or 60
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if not farmRunning then return end
            waitFarmDelay()
            moveCharacterToTile(x, y)
            sendAct(5, x * 2, y * -2)
            bumpFarmStat("seedsPlaced")
        end
    end
    bumpFarmStat("runsCompleted")
end

local function runFarmHarvest()
    local w = LocalPlayer:GetAttribute("WorldW") or 100
    local h = LocalPlayer:GetAttribute("WorldH") or 60
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if not farmRunning then return end
            waitFarmDelay()
            moveCharacterToTile(x, y)
            sendHarvest(x * 2, y * -2)
            bumpFarmStat("seedsHarvested")
            waitFarmDelay()
            sendTake(0, 999)
            bumpFarmStat("itemsCollected")
        end
    end
    bumpFarmStat("runsCompleted")
end

local function startAutoFarm(mode, params)
    if farmRunning then return end
    farmRunning = true
    farmThread = task.spawn(function()
        local ok, err = pcall(function()
            if mode == "PNB" then
                runFarmPNB(params.seedId, params.onDone)
            elseif mode == "DF" then
                runFarmDF()
            elseif mode == "CLEAR" then
                runFarmClear()
            elseif mode == "PABRIK" then
                while farmRunning do
                    runFarmPabrik(params.seedId)
                    task.wait(0.2)
                end
            elseif mode == "SPLICE" then
                runFarmSplice(params.seedA, params.seedB)
            elseif mode == "HARVEST" then
                while farmRunning do
                    runFarmHarvest()
                    task.wait(1.0)
                end
            end
        end)
        if not ok then warn("[GrowbloxSC Farm] Notice:", err) end
        farmRunning = false
    end)
end

local function stopAutoFarm()
    farmRunning = false
    if farmThread then
        pcall(task.cancel, farmThread)
        farmThread = nil
    end
end

-- ── 7.8 Global Controller: Stop-All & State Persistence ───────────────────────
local SCController = {
    stopAll = function()
        for k, _ in pairs(MiscState) do
            toggleMiscFeature(k, false)
        end
        stopAutoFarm()
        stopMacro()
    end,
    reopen = function()
        HUDCanvas.Visible = true
    end,
    save = function()
        local data = HttpService:JSONEncode({
            misc        = MiscState,
            themeIndex  = State.ThemeIndex,
            zoom        = State.UserZoomFactor,
            farmDelay   = State.FarmDelay,
            collect     = State.CollectMethod,
            webhook     = State.WebhookURL,
        })
        pcall(function()
            TeleportService:SetTeleportSetting(State.SaveKey, data)
        end)
    end,
    load = function()
        local ok, raw = pcall(function()
            return TeleportService:GetTeleportSetting(State.SaveKey)
        end)
        if ok and raw then
            local t = HttpService:JSONDecode(tostring(raw))
            if t and t.misc then
                for k, v in pairs(t.misc) do
                    toggleMiscFeature(k, v)
                end
            end
            if t and t.themeIndex then
                State.ThemeIndex = t.themeIndex
                broadcastTheme()
            end
            if t and t.farmDelay then State.FarmDelay = t.farmDelay end
            if t and t.collect then State.CollectMethod = t.collect end
            if t and t.webhook then State.WebhookURL = t.webhook end
            return true
        end
        return false
    end,
    clear = function()
        pcall(function()
            TeleportService:SetTeleportSetting(State.SaveKey, nil)
        end)
    end
}

-- ════════════════════════════════════════════════════════════════════════════════
-- 8. GUI INTERFACE: HEADER, HAMBURGER & SIDEMENU DRAWER
-- ════════════════════════════════════════════════════════════════════════════════

-- ── 8.1 Header Bar ────────────────────────────────────────────────────────────
local HeaderBar = create("Frame", {
    Name = "HeaderBar",
    Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = Color3.fromRGB(11, 16, 28),
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 30,
    Parent = HUDCanvas
})
addCorner(HeaderBar, 4)
local headerStroke = addStroke(HeaderBar, Color3.fromRGB(28, 40, 68), 1)
makeDraggable(HeaderBar, HUDCanvas)

-- Hamburger Menu Button (≡ Trio Bar)
local HamburgerBtn = create("TextButton", {
    Name = "HamburgerTrioButton",
    Size = UDim2.fromOffset(36, 36),
    Position = UDim2.new(0, 8, 0.5, -18),
    BackgroundColor3 = Color3.fromRGB(13, 17, 32),
    Text = "",
    AutoButtonColor = false,
    ZIndex = 32,
    Parent = HeaderBar
})
addCorner(HamburgerBtn, 3)
local burgerStroke = addStroke(HamburgerBtn, Color3.fromRGB(28, 40, 68), 1)

local burgerLines = {}
for i = 1, 3 do
    local line = create("Frame", {
        Name = "Bar_" .. i,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.28 + (i - 1) * 0.22, 0),
        Size = UDim2.fromOffset(18, 2),
        BackgroundColor3 = Color3.fromRGB(74, 222, 128),
        BorderSizePixel = 0,
        ZIndex = 33,
        Parent = HamburgerBtn
    })
    addCorner(line, 1)
    table.insert(burgerLines, line)
end

-- Branding Icon & Title
local BrandIcon = create("TextLabel", {
    Position = UDim2.fromOffset(52, 9),
    Size = UDim2.fromOffset(32, 32),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    Text = "🌱",
    ZIndex = 32,
    Parent = HeaderBar
})

local BrandTitle = create("TextLabel", {
    Position = UDim2.fromOffset(86, 8),
    Size = UDim2.fromOffset(160, 18),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(240, 245, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "GROWBLOX SC",
    ZIndex = 32,
    Parent = HeaderBar
})

local BrandTag = create("TextLabel", {
    Position = UDim2.fromOffset(86, 26),
    Size = UDim2.fromOffset(160, 14),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(74, 222, 128),
    Font = Enum.Font.GothamMedium,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "v2.0 · Pixel Suite",
    ZIndex = 32,
    Parent = HeaderBar
})

-- Header Center: Active Tab Indicator Badge
local ActiveTabPill = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(170, 28),
    BackgroundColor3 = Color3.fromRGB(13, 17, 32),
    ZIndex = 32,
    Parent = HeaderBar
})
addCorner(ActiveTabPill, 3)
local pillStroke = addStroke(ActiveTabPill, Color3.fromRGB(28, 40, 68), 1)

local PillDot = create("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 10, 0.5, 0),
    Size = UDim2.fromOffset(8, 8),
    BackgroundColor3 = Color3.fromRGB(74, 222, 128),
    BorderSizePixel = 0,
    ZIndex = 33,
    Parent = ActiveTabPill
})
addCorner(PillDot, 4)

local PillTitle = create("TextLabel", {
    Position = UDim2.fromOffset(26, 0),
    Size = UDim2.new(1, -30, 1, 0),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(240, 245, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "ITEM INFO",
    ZIndex = 33,
    Parent = ActiveTabPill
})

-- Header Right Controls: Scale View, Minimize, Close
HeaderScaleBadge = create("TextLabel", {
    Position = UDim2.new(1, -165, 0.5, -12),
    Size = UDim2.fromOffset(70, 24),
    BackgroundColor3 = Color3.fromRGB(13, 17, 32),
    TextColor3 = Color3.fromRGB(148, 163, 184),
    Font = Enum.Font.GothamMedium,
    TextSize = 10,
    Text = "85% View",
    ZIndex = 32,
    Parent = HeaderBar
})
addCorner(HeaderScaleBadge, 3)
local hsbStroke = addStroke(HeaderScaleBadge, Color3.fromRGB(28, 40, 68), 1)

local MinimizeBtn = create("TextButton", {
    Position = UDim2.new(1, -86, 0.5, -13),
    Size = UDim2.fromOffset(36, 26),
    BackgroundColor3 = Color3.fromRGB(20, 26, 44),
    TextColor3 = Color3.fromRGB(240, 245, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    Text = "−",
    AutoButtonColor = false,
    ZIndex = 32,
    Parent = HeaderBar
})
addCorner(MinimizeBtn, 3)
local minStroke = addStroke(MinimizeBtn, Color3.fromRGB(28, 40, 68), 1)
addHoverEffect(MinimizeBtn, Color3.fromRGB(20, 26, 44), Color3.fromRGB(32, 42, 68))

local CloseBtn = create("TextButton", {
    Position = UDim2.new(1, -44, 0.5, -13),
    Size = UDim2.fromOffset(36, 26),
    BackgroundColor3 = Color3.fromRGB(150, 30, 30),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Text = "✕",
    AutoButtonColor = false,
    ZIndex = 32,
    Parent = HeaderBar
})
addCorner(CloseBtn, 3)
local closeStroke = addStroke(CloseBtn, Color3.fromRGB(200, 50, 50), 1)
addHoverEffect(CloseBtn, Color3.fromRGB(150, 30, 30), Color3.fromRGB(200, 40, 40))

-- ── 8.2 Floating Shortcut Pill (When Minimized) ───────────────────────────────
local FloatingShortcut = create("TextButton", {
    Name = "FloatingRestorePill",
    Position = UDim2.fromOffset(12, 60), -- Tetap aman dibawah topbar
    Size = UDim2.fromOffset(180, 38),
    BackgroundColor3 = Color3.fromRGB(11, 16, 28),
    AutoButtonColor = false,
    Visible = false,
    Active = true,
    ZIndex = 200,
    Parent = ScreenGui
})
addCorner(FloatingShortcut, 4)
local fsStroke = addStroke(FloatingShortcut, Color3.fromRGB(74, 222, 128), 1.2)
makeDraggable(FloatingShortcut, FloatingShortcut)

local FsIcon = create("TextLabel", {
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.fromOffset(26, 38),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    Text = "🌱",
    ZIndex = 201,
    Parent = FloatingShortcut
})

local FsTitle = create("TextLabel", {
    Position = UDim2.fromOffset(38, 4),
    Size = UDim2.new(1, -44, 0, 16),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(240, 245, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "GrowbloxSC v2.0",
    ZIndex = 201,
    Parent = FloatingShortcut
})

local FsSub = create("TextLabel", {
    Position = UDim2.fromOffset(38, 20),
    Size = UDim2.new(1, -44, 0, 14),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(74, 222, 128),
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "Klik untuk membuka",
    ZIndex = 201,
    Parent = FloatingShortcut
})

MinimizeBtn.MouseButton1Click:Connect(function()
    HUDCanvas.Visible = false
    FloatingShortcut.Visible = true
end)

FloatingShortcut.MouseButton1Click:Connect(function()
    FloatingShortcut.Visible = false
    HUDCanvas.Visible = true
end)

CloseBtn.MouseButton1Click:Connect(function()
    SCController.stopAll()
    clearMiscConns()
    clearNameOverride()
    ScreenGui:Destroy()
end)

-- ── 8.3 Content Area & Pages ──────────────────────────────────────────────────
local ContentArea = create("Frame", {
    Name = "ContentArea",
    Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
    Position = UDim2.fromOffset(0, HEADER_HEIGHT),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    ZIndex = 10,
    Parent = HUDCanvas
})

local TabPages = {}
local TabButtons = {}
local TABS_METADATA = {
    { key = "item",   icon = "🔍", label = "Item Info",  title = "ITEM INFO & DATABASE" },
    { key = "misc",   icon = "⚙️", label = "Misc Mods",  title = "MISC & PLAYER MODS"   },
    { key = "player", icon = "👤", label = "Player Info",title = "PLAYER & NAMETAGS"   },
    { key = "msg",    icon = "💬", label = "Chat / Msg", title = "CHAT & SPAM MACROS"   },
    { key = "mods",   icon = "🛡️", label = "Mod Radar",  title = "MODERATOR RADAR"      },
    { key = "farm",   icon = "🌾", label = "Auto Farm",  title = "AUTOMATED FARMING"    },
    { key = "set",    icon = "🔧", label = "Settings",   title = "ENGINE SETTINGS"      },
}

for _, t in ipairs(TABS_METADATA) do
    local page = create("Frame", {
        Name = "Page_" .. t.key,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = (t.key == "item"),
        ZIndex = 11,
        Parent = ContentArea
    })
    TabPages[t.key] = page
end

-- ── 8.4 SideMenu Drawer (Slide In/Out with Smooth Tween) ──────────────────────
-- Backdrop penutup saat menu terbuka
local SideMenuBackdrop = create("TextButton", {
    Name = "SideMenuBackdrop",
    Size = UDim2.fromScale(1, 1),
    Position = UDim2.fromOffset(0, HEADER_HEIGHT),
    BackgroundColor3 = Color3.fromRGB(3, 5, 10),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    Visible = false,
    ZIndex = 25,
    Parent = HUDCanvas
})

local SideMenu = create("Frame", {
    Name = "SideNavigationDrawer",
    Size = UDim2.new(0, SIDEMENU_WIDTH, 1, -HEADER_HEIGHT),
    Position = UDim2.new(0, -SIDEMENU_WIDTH - 10, 0, HEADER_HEIGHT), -- Tertutup secara default
    BackgroundColor3 = Color3.fromRGB(11, 16, 28),
    BorderSizePixel = 0,
    ZIndex = 28,
    Parent = HUDCanvas
})
addCorner(SideMenu, 4)
local sideMenuStroke = addStroke(SideMenu, Color3.fromRGB(28, 40, 68), 1)

local SideMenuHeader = create("TextLabel", {
    Position = UDim2.fromOffset(14, 12),
    Size = UDim2.new(1, -28, 0, 18),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(100, 116, 139),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "NAVIGATION SYSTEM",
    ZIndex = 29,
    Parent = SideMenu
})

local NavScroll = create("ScrollingFrame", {
    Position = UDim2.fromOffset(8, 34),
    Size = UDim2.new(1, -16, 1, -44),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Color3.fromRGB(74, 222, 128),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 29,
    Parent = SideMenu
})
local navLayout = create("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 6),
    Parent = NavScroll
})

-- SideMenu Indicator Bar (Indikator Aktif Bergeser)
local NavActiveIndicator = create("Frame", {
    Name = "ActiveTabIndicator",
    Size = UDim2.fromOffset(4, 28),
    Position = UDim2.fromOffset(0, 4),
    BackgroundColor3 = Color3.fromRGB(74, 222, 128),
    BorderSizePixel = 0,
    ZIndex = 31,
    Parent = NavScroll
})
addCorner(NavActiveIndicator, 2)

local function setSideMenuOpen(open)
    State.SideMenuOpen = open
    if open then
        SideMenuBackdrop.Visible = true
        TweenService:Create(SideMenuBackdrop, TweenFast, { BackgroundTransparency = 0.45 }):Play()
        TweenService:Create(SideMenu, TweenSmooth, { Position = UDim2.fromOffset(0, HEADER_HEIGHT) }):Play()
        -- Putar atau geser garis hamburger
        TweenService:Create(burgerLines[1], TweenFast, { Position = UDim2.new(0.5, 0, 0.5, 0), Rotation = 45 }):Play()
        TweenService:Create(burgerLines[2], TweenFast, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(burgerLines[3], TweenFast, { Position = UDim2.new(0.5, 0, 0.5, 0), Rotation = -45 }):Play()
    else
        TweenService:Create(SideMenuBackdrop, TweenFast, { BackgroundTransparency = 1 }):Play()
        local tw = TweenService:Create(SideMenu, TweenSmooth, { Position = UDim2.new(0, -SIDEMENU_WIDTH - 10, 0, HEADER_HEIGHT) })
        tw:Play()
        tw.Completed:Connect(function()
            if not State.SideMenuOpen then SideMenuBackdrop.Visible = false end
        end)
        TweenService:Create(burgerLines[1], TweenFast, { Position = UDim2.new(0.5, 0, 0.28, 0), Rotation = 0 }):Play()
        TweenService:Create(burgerLines[2], TweenFast, { BackgroundTransparency = 0 }):Play()
        TweenService:Create(burgerLines[3], TweenFast, { Position = UDim2.new(0.5, 0, 0.72, 0), Rotation = 0 }):Play()
    end
end

HamburgerBtn.MouseButton1Click:Connect(function()
    setSideMenuOpen(not State.SideMenuOpen)
end)

SideMenuBackdrop.MouseButton1Click:Connect(function()
    setSideMenuOpen(false)
end)

-- Tab Switcher dengan Motion Graphics Stagger
local function switchTab(tabKey)
    State.CurrentTab = tabKey
    local selectedMeta = nil
    for _, meta in ipairs(TABS_METADATA) do
        if meta.key == tabKey then selectedMeta = meta break end
    end
    if selectedMeta then
        PillTitle.Text = selectedMeta.title
    end

    -- Update active tab page
    for k, page in pairs(TabPages) do
        local active = (k == tabKey)
        page.Visible = active
        if active then
            -- Animate card children (Stagger 25ms)
            local children = {}
            for _, child in ipairs(page:GetDescendants()) do
                if child:IsA("Frame") and (child.Name:find("Card") or child.Name:find("Row") or child.Name:find("Box")) then
                    table.insert(children, child)
                end
            end
            for idx, card in ipairs(children) do
                local scaleInst = card:FindFirstChild("CardScale") or create("UIScale", { Name = "CardScale", Scale = 0.94, Parent = card })
                scaleInst.Scale = 0.94
                task.delay((idx - 1) * 0.022, function()
                    TweenService:Create(scaleInst, TweenFast, { Scale = 1 }):Play()
                end)
            end
        end
    end

    -- Update tab buttons styling
    for k, btn in pairs(TabButtons) do
        local active = (k == tabKey)
        local t = getTheme()
        btn.BackgroundColor3 = active and t.CardHover or Color3.fromRGB(13, 17, 32)
        local lbl = btn:FindFirstChildOfClass("TextLabel")
        if lbl then
            lbl.TextColor3 = active and t.Accent or t.TextSecondary
            lbl.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
        end
        if active then
            TweenService:Create(NavActiveIndicator, TweenFast, { Position = UDim2.fromOffset(0, btn.Position.Y.Offset + 4) }):Play()
        end
    end

    setSideMenuOpen(false)
end

-- Render Tab Buttons di SideMenu
for i, meta in ipairs(TABS_METADATA) do
    local btn = create("TextButton", {
        Name = "NavBtn_" .. meta.key,
        LayoutOrder = i,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = (meta.key == "item") and Color3.fromRGB(20, 28, 52) or Color3.fromRGB(13, 17, 32),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 30,
        Parent = NavScroll
    })
    addCorner(btn, 3)
    local bStroke = addStroke(btn, Color3.fromRGB(28, 40, 68), 1)

    local iconLbl = create("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.fromOffset(24, 36),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Text = meta.icon,
        ZIndex = 31,
        Parent = btn
    })

    local labelLbl = create("TextLabel", {
        Position = UDim2.fromOffset(38, 0),
        Size = UDim2.new(1, -44, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = (meta.key == "item") and Color3.fromRGB(74, 222, 128) or Color3.fromRGB(148, 163, 184),
        Font = (meta.key == "item") and Enum.Font.GothamBold or Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = meta.label,
        ZIndex = 31,
        Parent = btn
    })

    btn.MouseEnter:Connect(function()
        if State.CurrentTab ~= meta.key then
            TweenService:Create(btn, TweenFast, { BackgroundColor3 = Color3.fromRGB(18, 24, 44) }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if State.CurrentTab ~= meta.key then
            TweenService:Create(btn, TweenFast, { BackgroundColor3 = Color3.fromRGB(13, 17, 32) }):Play()
        end
    end)

    btn.MouseButton1Click:Connect(function()
        switchTab(meta.key)
    end)

    TabButtons[meta.key] = btn
end

-- ── 8.5 Resize Grip Pod di Pojok Kanan Bawah ──────────────────────────────────
local ResizeGripPod = create("TextButton", {
    Name = "BottomRightResizeGrip",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -8, 1, -8),
    Size = UDim2.fromOffset(80, 24),
    BackgroundColor3 = Color3.fromRGB(11, 16, 28),
    AutoButtonColor = false,
    Text = "",
    ZIndex = 45,
    Parent = HUDCanvas
})
addCorner(ResizeGripPod, 3)
local rgpStroke = addStroke(ResizeGripPod, Color3.fromRGB(28, 40, 68), 1)

ResizeHintLabel = create("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(148, 163, 184),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    Text = "⤡ 85%",
    ZIndex = 46,
    Parent = ResizeGripPod
})

do
    local isResizing = false
    local startMouse = Vector3.zero
    local startZoom = State.UserZoomFactor
    local lastClick = 0

    ResizeGripPod.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local now = tick()
            if (now - lastClick) < 0.35 then
                State.UserZoomFactor = 0.85
                computeAndApplyProportionalScale()
                return
            end
            lastClick = now
            isResizing = true
            startMouse = input.Position
            startZoom = State.UserZoomFactor
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local cam = workspace.CurrentCamera
            if not cam then return end
            local delta = input.Position - startMouse
            local deltaRatio = ((delta.X / cam.ViewportSize.X) + (delta.Y / cam.ViewportSize.Y)) * 0.95
            State.UserZoomFactor = math.clamp(startZoom + deltaRatio, 0.45, 1.15)
            computeAndApplyProportionalScale()
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if isResizing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isResizing = false
        end
    end)
end

registerThemeUpdater(function(t)
    HeaderBar.BackgroundColor3 = t.PanelBg
    headerStroke.Color = t.Stroke
    HamburgerBtn.BackgroundColor3 = t.CardBg
    burgerStroke.Color = t.Stroke
    for _, l in ipairs(burgerLines) do l.BackgroundColor3 = t.Accent end
    BrandTitle.TextColor3 = t.TextPrimary
    BrandTag.TextColor3 = t.Accent
    ActiveTabPill.BackgroundColor3 = t.CardBg
    pillStroke.Color = t.Stroke
    PillDot.BackgroundColor3 = t.Accent
    PillTitle.TextColor3 = t.TextPrimary
    HeaderScaleBadge.BackgroundColor3 = t.CardBg
    HeaderScaleBadge.TextColor3 = t.TextSecondary
    hsbStroke.Color = t.Stroke
    MinimizeBtn.BackgroundColor3 = t.CardBg
    minStroke.Color = t.Stroke
    SideMenu.BackgroundColor3 = t.PanelBg
    sideMenuStroke.Color = t.Stroke
    SideMenuHeader.TextColor3 = t.TextMuted
    NavActiveIndicator.BackgroundColor3 = t.Accent
    FloatingShortcut.BackgroundColor3 = t.PanelBg
    fsStroke.Color = t.Accent
    FsTitle.TextColor3 = t.TextPrimary
    FsSub.TextColor3 = t.Accent
    ResizeGripPod.BackgroundColor3 = t.PanelBg
    rgpStroke.Color = t.Stroke
    ResizeHintLabel.TextColor3 = t.TextSecondary
end)

-- ════════════════════════════════════════════════════════════════════════════════
-- 9. TAB 1: ITEM INFO & DATABASE (2-COLUMN GRID + DETAIL FLIP/EXPAND)
-- ════════════════════════════════════════════════════════════════════════════════
local function buildItemTab(page)
    local root = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = page
    })

    -- Search Bar Container
    local searchFrame = create("Frame", {
        Name = "ItemSearchFrame",
        Size = UDim2.new(1, -32, 0, 38),
        Position = UDim2.fromOffset(16, 12),
        BackgroundColor3 = Color3.fromRGB(9, 12, 22),
        Parent = root
    })
    addCorner(searchFrame, 4)
    local sStroke = addStroke(searchFrame, Color3.fromRGB(28, 40, 68), 1)

    local searchIcon = create("TextLabel", {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.fromOffset(24, 38),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Text = "🔍",
        Parent = searchFrame
    })

    local searchBox = create("TextBox", {
        Name = "SearchInput",
        Position = UDim2.fromOffset(36, 0),
        Size = UDim2.new(1, -44, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(240, 245, 255),
        PlaceholderText = "Ketik nama item... (contoh: Laser Grid / Dirt / Seed)",
        PlaceholderColor3 = Color3.fromRGB(100, 116, 139),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = searchFrame
    })

    local countLabel = create("TextLabel", {
        Position = UDim2.fromOffset(16, 54),
        Size = UDim2.new(1, -32, 0, 18),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(148, 163, 184),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Memuat item database...",
        Parent = root
    })

    -- Grid 2-Kolom ScrollingFrame
    local gridScroll = create("ScrollingFrame", {
        Name = "ItemGridScroll",
        Position = UDim2.fromOffset(16, 76),
        Size = UDim2.new(1, -32, 1, -84),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(74, 222, 128),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = root
    })
    local gridLayout = create("UIGridLayout", {
        CellSize = UDim2.new(0.5, -6, 0, 64),
        CellPadding = UDim2.fromOffset(10, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = gridScroll
    })

    -- Detail Modal Popup (Flip / Expand Card Detail)
    local detailModal = create("Frame", {
        Name = "ItemDetailModal",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(360, 260),
        BackgroundColor3 = Color3.fromRGB(11, 16, 28),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 80,
        Parent = root
    })
    addCorner(detailModal, 4)
    local dmStroke = addStroke(detailModal, Color3.fromRGB(74, 222, 128), 1.5)

    local modalHeader = create("TextLabel", {
        Position = UDim2.fromOffset(16, 12),
        Size = UDim2.new(1, -60, 0, 24),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Item Details",
        ZIndex = 81,
        Parent = detailModal
    })

    local modalClose = create("TextButton", {
        Position = UDim2.new(1, -34, 0, 10),
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = Color3.fromRGB(20, 28, 48),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Text = "✕",
        AutoButtonColor = false,
        ZIndex = 81,
        Parent = detailModal
    })
    addCorner(modalClose, 3)

    local modalRarityTag = create("TextLabel", {
        Position = UDim2.fromOffset(16, 38),
        Size = UDim2.fromOffset(160, 18),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(74, 222, 128),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "✦ COMMON · ID 0",
        ZIndex = 81,
        Parent = detailModal
    })

    -- Item Preview Image (Atlas Spritesheet Tile) di kanan header modal
    local modalItemImage = create("ImageLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -48, 0, 36),
        Size = UDim2.fromOffset(60, 60),
        BackgroundColor3 = Color3.fromRGB(9, 12, 22),
        ScaleType = Enum.ScaleType.Crop,
        ImageTransparency = 0,
        ZIndex = 82,
        Parent = detailModal
    })
    addCorner(modalItemImage, 4)
    addStroke(modalItemImage, Color3.fromRGB(28, 40, 68), 1)

    local modalInfoBody = create("TextLabel", {
        Position = UDim2.fromOffset(16, 64),
        Size = UDim2.new(1, -32, 0, 120),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(148, 163, 184),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Text = "Properties...",
        ZIndex = 81,
        Parent = detailModal
    })

    local modalCopyName = create("TextButton", {
        Position = UDim2.fromOffset(16, 204),
        Size = UDim2.new(0.5, -22, 0, 36),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Text = "📋 Copy Nama",
        AutoButtonColor = false,
        ZIndex = 81,
        Parent = detailModal
    })
    addCorner(modalCopyName, 3)
    local mcnStroke = addStroke(modalCopyName, Color3.fromRGB(28, 40, 68), 1)

    local modalCopyID = create("TextButton", {
        Position = UDim2.new(0.5, 6, 0, 204),
        Size = UDim2.new(0.5, -22, 0, 36),
        BackgroundColor3 = Color3.fromRGB(74, 222, 128),
        TextColor3 = Color3.fromRGB(7, 10, 20),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Text = "🔢 Copy ID",
        AutoButtonColor = false,
        ZIndex = 81,
        Parent = detailModal
    })
    addCorner(modalCopyID, 3)

    modalClose.MouseButton1Click:Connect(function()
        detailModal.Visible = false
    end)

    local selectedModalEntry = nil
    modalCopyName.MouseButton1Click:Connect(function()
        if selectedModalEntry then
            copyToClipboard(selectedModalEntry.name)
            modalCopyName.Text = "✔ Tersalin!"
            task.delay(1.2, function() modalCopyName.Text = "📋 Copy Nama" end)
        end
    end)
    modalCopyID.MouseButton1Click:Connect(function()
        if selectedModalEntry then
            copyToClipboard(tostring(selectedModalEntry.id))
            modalCopyID.Text = "✔ Tersalin!"
            task.delay(1.2, function() modalCopyID.Text = "🔢 Copy ID" end)
        end
    end)

    local function openModalDetail(entry)
        selectedModalEntry = entry
        modalHeader.Text = entry.name
        local r = entry.rarity:lower()
        local rCol = RARITY_COLOR[r] or RARITY_COLOR.unknown
        modalRarityTag.TextColor3 = rCol
        modalRarityTag.Text = string.format("✦ %s · ID %s", entry.rarity:upper(), tostring(entry.id))

        local p = entry.item
        local lines = {}
        table.insert(lines, string.format("🧱 Solid: %s", (p.solid ~= nil) and tostring(p.solid) or "false"))
        if p.hits then table.insert(lines, string.format("⚡ Hardness / Hits: %s", tostring(p.hits))) end
        if p.farmable then table.insert(lines, "🌱 Farmable: Ya") end
        if p.seed then table.insert(lines, "🌿 Kategori: Benih / Seed") end
        if p.spread then table.insert(lines, string.format("📡 Spread Speed: %s", tostring(p.spread))) end
        if p.dropChance then table.insert(lines, string.format("🎲 Drop Rate: %s%%", tostring(p.dropChance))) end
        if p.rarity then table.insert(lines, string.format("💎 Rarity: %s", tostring(p.rarity))) end

        modalInfoBody.Text = table.concat(lines, "\n")

        -- Tampilkan item preview image dari atlas spritesheet
        local atlasId = p.atlas or p.texture or p.textureId
        if atlasId then
            local assetIdStr = tostring(atlasId):match("%d+")
            if assetIdStr then
                modalItemImage.Image = "rbxassetid://" .. assetIdStr
                -- Jika ada tx/ty (tile coordinates), gunakan ImageRectOffset
                local tileSize = 32 -- Growblox tile default 32px
                local tx = p.tx or 0
                local ty = p.ty or 0
                if p.tx or p.ty then
                    modalItemImage.ImageRectSize = Vector2.new(tileSize, tileSize)
                    modalItemImage.ImageRectOffset = Vector2.new(tx * tileSize, ty * tileSize)
                    modalItemImage.ScaleType = Enum.ScaleType.Crop
                else
                    modalItemImage.ImageRectSize = Vector2.new(0, 0) -- Use full image
                end
                modalItemImage.ImageTransparency = 0
            else
                modalItemImage.ImageTransparency = 1
            end
        else
            -- Fallback: tampilkan rarity color block
            modalItemImage.Image = ""
            modalItemImage.BackgroundColor3 = rCol
            modalItemImage.ImageTransparency = 1
        end

        detailModal.Visible = true
        detailModal.Position = UDim2.fromScale(0.5, 0.54)
        TweenService:Create(detailModal, TweenFast, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
    end

    local function renderItemCard(entry, order)
        local card = create("Frame", {
            Name = "ItemCard_" .. tostring(entry.id),
            LayoutOrder = order,
            BackgroundColor3 = Color3.fromRGB(13, 17, 32),
            Parent = gridScroll
        })
        addCorner(card, 4)
        local cStroke = addStroke(card, Color3.fromRGB(28, 40, 68), 1)

        -- Rarity Strip (Kiri 4px)
        local rColor = RARITY_COLOR[entry.rarity] or RARITY_COLOR.unknown
        local strip = create("Frame", {
            Size = UDim2.new(0, 4, 1, 0),
            BackgroundColor3 = rColor,
            BorderSizePixel = 0,
            Parent = card
        })
        addCorner(strip, 2)

        local nameLbl = create("TextLabel", {
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -125, 0, 20),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(240, 245, 255),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = entry.name,
            Parent = card
        })

        local subLbl = create("TextLabel", {
            Position = UDim2.fromOffset(14, 30),
            Size = UDim2.new(1, -125, 0, 16),
            BackgroundTransparency = 1,
            TextColor3 = rColor,
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.format("ID %s · %s", tostring(entry.id), entry.rarity:upper()),
            Parent = card
        })

        -- Tombol Copy ID & Nama (Kanan Card)
        local cpIdBtn = create("TextButton", {
            Position = UDim2.new(1, -108, 0.5, -12),
            Size = UDim2.fromOffset(50, 24),
            BackgroundColor3 = Color3.fromRGB(20, 26, 44),
            TextColor3 = Color3.fromRGB(240, 245, 255),
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            Text = "📋 ID",
            AutoButtonColor = false,
            Parent = card
        })
        addCorner(cpIdBtn, 3)
        addHoverEffect(cpIdBtn, Color3.fromRGB(20, 26, 44), Color3.fromRGB(30, 40, 68))

        local cpNameBtn = create("TextButton", {
            Position = UDim2.new(1, -54, 0.5, -12),
            Size = UDim2.fromOffset(50, 24),
            BackgroundColor3 = Color3.fromRGB(20, 26, 44),
            TextColor3 = Color3.fromRGB(240, 245, 255),
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            Text = "📋 Name",
            AutoButtonColor = false,
            Parent = card
        })
        addCorner(cpNameBtn, 3)
        addHoverEffect(cpNameBtn, Color3.fromRGB(20, 26, 44), Color3.fromRGB(30, 40, 68))

        cpIdBtn.MouseButton1Click:Connect(function()
            copyToClipboard(tostring(entry.id))
            cpIdBtn.Text = "✔"
            task.delay(1.0, function() cpIdBtn.Text = "📋 ID" end)
        end)
        cpNameBtn.MouseButton1Click:Connect(function()
            copyToClipboard(entry.name)
            cpNameBtn.Text = "✔"
            task.delay(1.0, function() cpNameBtn.Text = "📋 Name" end)
        end)

        -- Klik card buka modal detail
        local clickSensor = create("TextButton", {
            Size = UDim2.new(1, -112, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            Parent = card
        })
        clickSensor.MouseButton1Click:Connect(function()
            openModalDetail(entry)
        end)
    end

    local renderDebounce = false
    local function performSearch(query)
        if renderDebounce then return end
        renderDebounce = true
        task.defer(function()
            for _, c in ipairs(gridScroll:GetChildren()) do
                if c:IsA("Frame") then c:Destroy() end
            end
            local results = searchItemDB(query)
            countLabel.Text = string.format("%d item ditemukan (terurut sesuai rarity)", #results)
            local limit = math.min(#results, 180) -- Optimasi performa render awal
            for i = 1, limit do
                renderItemCard(results[i], i)
            end
            renderDebounce = false
        end)
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        performSearch(searchBox.Text)
    end)

    performSearch("")

    registerThemeUpdater(function(t)
        searchFrame.BackgroundColor3 = t.InputBg
        sStroke.Color = t.Stroke
        searchBox.TextColor3 = t.TextPrimary
        searchBox.PlaceholderColor3 = t.TextMuted
        countLabel.TextColor3 = t.TextSecondary
        detailModal.BackgroundColor3 = t.PanelBg
        dmStroke.Color = t.Accent
        modalHeader.TextColor3 = t.TextPrimary
        modalClose.BackgroundColor3 = t.CardHover
        modalInfoBody.TextColor3 = t.TextSecondary
        modalCopyName.BackgroundColor3 = t.CardBg
        mcnStroke.Color = t.Stroke
        modalCopyID.BackgroundColor3 = t.Accent
        modalCopyID.TextColor3 = t.MainBg
        modalItemImage.BackgroundColor3 = t.InputBg
    end)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- 10. TAB 2: MISC & PLAYER MODS (ANIMATED TOGGLES & MOTION SLIDERS)
-- ════════════════════════════════════════════════════════════════════════════════
local function createInteractiveToggleCard(parent, order, labelText, descText, initialKey)
    local card = create("Frame", {
        Name = "MiscCard_" .. initialKey,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = parent
    })
    addCorner(card, 4)
    local cardStroke = addStroke(card, Color3.fromRGB(28, 40, 68), 1)

    local lbl = create("TextLabel", {
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.new(1, -80, 0, 18),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = labelText,
        Parent = card
    })

    local desc = create("TextLabel", {
        Position = UDim2.fromOffset(14, 28),
        Size = UDim2.new(1, -80, 0, 16),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(148, 163, 184),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = descText,
        Parent = card
    })

    -- Sliding Toggle Button
    local toggleTrack = create("TextButton", {
        Name = "ToggleTrack",
        Position = UDim2.new(1, -64, 0.5, -12),
        Size = UDim2.fromOffset(48, 24),
        BackgroundColor3 = MiscState[initialKey] and Color3.fromRGB(74, 222, 128) or Color3.fromRGB(36, 44, 62),
        AutoButtonColor = false,
        Text = "",
        Parent = card
    })
    addCorner(toggleTrack, 12)

    local toggleKnob = create("Frame", {
        Name = "Knob",
        Position = MiscState[initialKey] and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = Color3.fromRGB(240, 245, 255),
        BorderSizePixel = 0,
        Parent = toggleTrack
    })
    addCorner(toggleKnob, 9)

    local function refreshSwitch(isOn)
        local t = getTheme()
        local targetTrackColor = isOn and t.ToggleOn or t.ToggleOff
        local targetKnobPos = isOn and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9)

        TweenService:Create(toggleTrack, TweenFast, { BackgroundColor3 = targetTrackColor }):Play()
        TweenService:Create(toggleKnob, TweenFast, { Position = targetKnobPos }):Play()
    end

    toggleTrack.MouseButton1Click:Connect(function()
        toggleMiscFeature(initialKey)
        refreshSwitch(MiscState[initialKey])
    end)

    registerThemeUpdater(function(t)
        card.BackgroundColor3 = t.CardBg
        cardStroke.Color = t.Stroke
        lbl.TextColor3 = t.TextPrimary
        desc.TextColor3 = t.TextSecondary
        toggleTrack.BackgroundColor3 = MiscState[initialKey] and t.ToggleOn or t.ToggleOff
    end)
    return card
end

local function buildMiscTab(page)
    local scroll = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(74, 222, 128),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = page
    })
    addPadding(scroll, 14, 14, 16, 16)

    local layout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = scroll
    })

    local function createSectionTitle(text, order)
        local lbl = create("TextLabel", {
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(74, 222, 128),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = text,
            Parent = scroll
        })
        registerThemeUpdater(function(t) lbl.TextColor3 = t.Accent end)
        return lbl
    end

    createSectionTitle("⚙️  PERILAKU KARAKTER", 10)
    createInteractiveToggleCard(scroll, 11, "🕊️  Fly (Terbang Bebas)", "Melayang leluasa di udara. WASD bergerak, Space naik, Ctrl turun.", "fly")
    createInteractiveToggleCard(scroll, 12, "👻  No Clip (Tembus Blok)", "Berjalan menembus rintangan dunia. Posisi asal aman terjaga jika mati.", "noclip")
    createInteractiveToggleCard(scroll, 13, "🛡️  No Death (God Mode)", "Menahan seluruh damage lingkungan & lava, menjaga HP selalu penuh.", "nodeath")
    createInteractiveToggleCard(scroll, 14, "🔧  Fast Pull (Teleport ke Target)", "Klik karakter pemain lain di layar untuk langsung berpindah tepat ke sampingnya.", "fastpull")
    createInteractiveToggleCard(scroll, 15, "🔕  No Detect (Penghindar Anti-Cheat)", "Menormalkan tick rate & membersihkan tag flag anomali game secara otomatis.", "nodetect")
    createInteractiveToggleCard(scroll, 16, "⚡  Fast Roulette (Skip Animasi)", "Menghentikan animasi putaran roda roulette agar hadiah langsung keluar seketika.", "fastroulette")

    createSectionTitle("🏃  MODE GERAK & FISIKA", 20)
    createInteractiveToggleCard(scroll, 21, "💨  Speed Mode (Lari Cepat)", string.format("Meningkatkan kecepatan jalan karakter menjadi ×%.1f kali lipat.", State.SpeedMult), "speed")
    createInteractiveToggleCard(scroll, 22, "⬆️  High Jump (Lompatan Tinggi)", string.format("Memperbesar gaya lompat karakter menjadi ×%.1f kali lipat normal.", State.JumpMult), "jump")
    createInteractiveToggleCard(scroll, 23, "🌌  Anti Gravity (Lompat Bebas)", "Tahan tombol Space untuk melayang & melompat berulang kali tanpa terjatuh.", "antigravity")
end

-- ════════════════════════════════════════════════════════════════════════════════
-- 11. TAB 3: PLAYER INFO & CLOTHES WEAR
-- ════════════════════════════════════════════════════════════════════════════════
local function buildPlayerTab(page)
    local scroll = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(74, 222, 128),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = page
    })
    addPadding(scroll, 14, 14, 16, 16)
    local layout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = scroll
    })

    local function makeSectionTitle(text, order)
        local lbl = create("TextLabel", {
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(74, 222, 128),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = text,
            Parent = scroll
        })
        registerThemeUpdater(function(t) lbl.TextColor3 = t.Accent end)
        return lbl
    end

    -- Card 1: Info Card & Realtime Position
    makeSectionTitle("👤  STATUS KARAKTER", 1)
    local infoCard = create("Frame", {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 78),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = scroll
    })
    addCorner(infoCard, 4)
    local icStroke = addStroke(infoCard, Color3.fromRGB(28, 40, 68), 1)

    local pGameName = create("TextLabel", {
        Position = UDim2.fromOffset(14, 10),
        Size = UDim2.new(1, -28, 0, 18),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "🎮 Nama Game: " .. getGamePlayerName(),
        Parent = infoCard
    })

    local pRblxName = create("TextLabel", {
        Position = UDim2.fromOffset(14, 30),
        Size = UDim2.new(1, -28, 0, 16),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(148, 163, 184),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = string.format("🔵 Roblox: @%s  ·  User ID: %d", LocalPlayer.Name, LocalPlayer.UserId),
        Parent = infoCard
    })

    local pPosLabel = create("TextLabel", {
        Position = UDim2.fromOffset(14, 50),
        Size = UDim2.new(1, -28, 0, 18),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(74, 222, 128),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "📍 Posisi Realtime: Menghitung...",
        Parent = infoCard
    })

    RunService.Heartbeat:Connect(function()
        if pPosLabel.Parent then
            local x, y, z = getPlayerPosition()
            pPosLabel.Text = string.format("📍 Posisi Realtime: X: %.1f   Y: %.1f   Z: %.1f", x, y, z)
        end
    end)

    -- Card 2: Name Changer Grid (8 Mode)
    makeSectionTitle("✏️  NAME CHANGER (VISUAL LOCAL)", 10)
    local nameGridCard = create("Frame", {
        LayoutOrder = 11,
        Size = UDim2.new(1, 0, 0, 120),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = scroll
    })
    addCorner(nameGridCard, 4)
    local ngStroke = addStroke(nameGridCard, Color3.fromRGB(28, 40, 68), 1)

    local nameModes = {
        { key = "normal",   label = "⬛ Normal",   desc = "Default" },
        { key = "rainbow",  label = "🌈 Rainbow",  desc = "Pelangi" },
        { key = "prefix_D", label = "@D Dev",      desc = "Prefix @D" },
        { key = "prefix_S", label = "@S Staff",    desc = "Prefix @S" },
        { key = "red",      label = "🔴 Red",      desc = "Crimson" },
        { key = "cyan",     label = "🩵 Cyan",     desc = "Sky Blue" },
        { key = "gold",     label = "🟡 Gold",     desc = "Emas" },
        { key = "purple",   label = "💜 Purple",   desc = "Amethyst" },
    }

    local nmLayout = create("UIGridLayout", {
        CellSize = UDim2.new(0.25, -6, 0, 48),
        CellPadding = UDim2.fromOffset(8, 8),
        Parent = nameGridCard
    })
    addPadding(nameGridCard, 8, 8, 8, 8)

    local nameModeButtons = {}
    for _, mode in ipairs(nameModes) do
        local mb = create("TextButton", {
            Name = "NameMode_" .. mode.key,
            BackgroundColor3 = (mode.key == currentNameMode) and Color3.fromRGB(74, 222, 128) or Color3.fromRGB(20, 26, 44),
            AutoButtonColor = false,
            Text = "",
            Parent = nameGridCard
        })
        addCorner(mb, 3)
        local mbStroke = addStroke(mb, Color3.fromRGB(28, 40, 68), 1)

        local mTitle = create("TextLabel", {
            Position = UDim2.fromOffset(6, 4),
            Size = UDim2.new(1, -12, 0, 20),
            BackgroundTransparency = 1,
            TextColor3 = (mode.key == currentNameMode) and Color3.fromRGB(7, 10, 20) or Color3.fromRGB(240, 245, 255),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Center,
            Text = mode.label,
            Parent = mb
        })

        local mDesc = create("TextLabel", {
            Position = UDim2.fromOffset(6, 24),
            Size = UDim2.new(1, -12, 0, 16),
            BackgroundTransparency = 1,
            TextColor3 = (mode.key == currentNameMode) and Color3.fromRGB(15, 25, 40) or Color3.fromRGB(148, 163, 184),
            Font = Enum.Font.GothamMedium,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Center,
            Text = mode.desc,
            Parent = mb
        })

        mb.MouseButton1Click:Connect(function()
            applyNameChanger(mode.key)
            for k, btn in pairs(nameModeButtons) do
                local isActive = (k == mode.key)
                local t = getTheme()
                btn.BackgroundColor3 = isActive and t.Accent or Color3.fromRGB(20, 26, 44)
                local tLbl = btn:FindFirstChildOfClass("TextLabel")
                if tLbl then tLbl.TextColor3 = isActive and t.MainBg or t.TextPrimary end
            end
        end)
        nameModeButtons[mode.key] = mb
    end

    -- Card 3: Clothes 3-Column Grid
    makeSectionTitle("👕  CLOTHES WARDROBE (DOUBLE-TAP TO WEAR)", 20)
    local unwearAllBtn = create("TextButton", {
        LayoutOrder = 21,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(20, 26, 44),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Text = "❌ Lepas Semua Pakaian (Unwear All)",
        AutoButtonColor = false,
        Parent = scroll
    })
    addCorner(unwearAllBtn, 3)
    local uabStroke = addStroke(unwearAllBtn, Color3.fromRGB(28, 40, 68), 1)

    local clothesContainer = create("Frame", {
        LayoutOrder = 22,
        Size = UDim2.new(1, 0, 0, 280),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = scroll
    })
    addCorner(clothesContainer, 4)
    local ccStroke = addStroke(clothesContainer, Color3.fromRGB(28, 40, 68), 1)

    local clothesScroll = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(74, 222, 128),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = clothesContainer
    })
    addPadding(clothesScroll, 8, 8, 8, 8)

    local cGridLayout = create("UIGridLayout", {
        CellSize = UDim2.new(0.333, -6, 0, 84),
        CellPadding = UDim2.fromOffset(8, 8),
        Parent = clothesScroll
    })

    task.spawn(function()
        local db = getClothesDB()
        local list = {}
        for id, item in pairs(db) do
            if type(item) == "table" then table.insert(list, { id = id, item = item }) end
        end
        table.sort(list, function(a, b) return tostring(a.item.name or a.id) < tostring(b.item.name or b.id) end)

        local lastTapTime = {}
        for idx, entry in ipairs(list) do
            local cCard = create("TextButton", {
                Name = "ClothCard_" .. entry.id,
                BackgroundColor3 = Color3.fromRGB(20, 26, 44),
                AutoButtonColor = false,
                Text = "",
                Parent = clothesScroll
            })
            addCorner(cCard, 3)
            local cardStroke = addStroke(cCard, Color3.fromRGB(28, 40, 68), 1)

            local cName = create("TextLabel", {
                Position = UDim2.fromOffset(6, 6),
                Size = UDim2.new(1, -12, 0, 36),
                BackgroundTransparency = 1,
                TextColor3 = Color3.fromRGB(240, 245, 255),
                Font = Enum.Font.GothamMedium,
                TextSize = 10,
                TextWrapped = true,
                Text = tostring(entry.item.name or ("Cloth #" .. entry.id)),
                Parent = cCard
            })

            local wornIndicator = create("Frame", {
                Position = UDim2.new(1, -14, 0, 6),
                Size = UDim2.fromOffset(8, 8),
                BackgroundColor3 = Color3.fromRGB(74, 222, 128),
                BorderSizePixel = 0,
                Visible = false,
                Parent = cCard
            })
            addCorner(wornIndicator, 4)

            local statusSub = create("TextLabel", {
                Position = UDim2.fromOffset(6, 46),
                Size = UDim2.new(1, -12, 0, 16),
                BackgroundTransparency = 1,
                TextColor3 = Color3.fromRGB(148, 163, 184),
                Font = Enum.Font.Gotham,
                TextSize = 9,
                Text = "Double Tap",
                Parent = cCard
            })

            cCard.MouseButton1Click:Connect(function()
                local now = tick()
                local last = lastTapTime[entry.id] or 0
                lastTapTime[entry.id] = now
                if (now - last) < 0.5 then
                    -- Double tap terdeteksi
                    if wornClothes[entry.id] then
                        -- UNWEAR: hapus visual clothes dari karakter
                        wornClothes[entry.id] = nil
                        wornIndicator.Visible = false
                        cCard.BackgroundColor3 = Color3.fromRGB(20, 26, 44)
                        statusSub.Text = "Double Tap"
                        -- Hapus Shirt/Pants visual yang sudah dipasang
                        local char = LocalPlayer.Character
                        if char then
                            local tagName = "SC_Cloth_" .. tostring(entry.id)
                            for _, obj in ipairs(char:GetChildren()) do
                                if obj.Name == tagName then obj:Destroy() end
                            end
                        end
                    else
                        -- WEAR: apply visual clothes ke karakter (tidak murni, hanya di-client)
                        wornClothes[entry.id] = true
                        wornIndicator.Visible = true
                        cCard.BackgroundColor3 = Color3.fromRGB(26, 44, 40)
                        statusSub.Text = "WORN ✔"
                        -- Apply visual Shirt/Pants via ShirtTemplate / PantsTemplate
                        local char = LocalPlayer.Character
                        if char then
                            local idata = entry.item
                            local shirtId = idata.shirtId or idata.shirt or idata.textureId or nil
                            local pantsId = idata.pantsId or idata.pants or nil
                            local tagName = "SC_Cloth_" .. tostring(entry.id)
                            if shirtId then
                                local existing = char:FindFirstChildOfClass("Shirt")
                                if existing then existing:Destroy() end
                                local s = Instance.new("Shirt")
                                s.Name = tagName
                                s.ShirtTemplate = "rbxassetid://" .. tostring(shirtId):match("%d+")
                                s.Parent = char
                            elseif pantsId then
                                local existing = char:FindFirstChildOfClass("Pants")
                                if existing then existing:Destroy() end
                                local p = Instance.new("Pants")
                                p.Name = tagName
                                p.PantsTemplate = "rbxassetid://" .. tostring(pantsId):match("%d+")
                                p.Parent = char
                            else
                                -- Fallback: apply via WrapLayer if mesh-based cloth
                                local wl = char:FindFirstChild(tagName)
                                if not wl then
                                    -- indicator saja – UI tetap menampilkan sebagai worn
                                    wornIndicator.Visible = true
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)

    unwearAllBtn.MouseButton1Click:Connect(function()
        table.clear(wornClothes)
        -- Hapus semua visual clothes yang sudah dipasang ke karakter
        local char = LocalPlayer.Character
        if char then
            for _, obj in ipairs(char:GetChildren()) do
                if obj.Name:sub(1, 9) == "SC_Cloth_" then
                    obj:Destroy()
                end
            end
        end
        for _, card in ipairs(clothesScroll:GetChildren()) do
            if card:IsA("TextButton") then
                card.BackgroundColor3 = Color3.fromRGB(20, 26, 44)
                local wornDot = card:FindFirstChild("Frame")
                if wornDot then wornDot.Visible = false end
                local sLbl = card:FindFirstChild("TextLabel", true)
                -- reset status label
                for _, c2 in ipairs(card:GetChildren()) do
                    if c2:IsA("TextLabel") and c2.Text == "WORN ✔" then
                        c2.Text = "Double Tap"
                    end
                end
            end
        end
    end)

    registerThemeUpdater(function(t)
        infoCard.BackgroundColor3 = t.CardBg
        icStroke.Color = t.Stroke
        pGameName.TextColor3 = t.TextPrimary
        pRblxName.TextColor3 = t.TextSecondary
        pPosLabel.TextColor3 = t.Accent
        nameGridCard.BackgroundColor3 = t.CardBg
        ngStroke.Color = t.Stroke
        clothesContainer.BackgroundColor3 = t.CardBg
        ccStroke.Color = t.Stroke
        unwearAllBtn.BackgroundColor3 = t.CardHover
        uabStroke.Color = t.Stroke
    end)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- 12. TAB 4: CHAT & SPAM MACROS
-- ════════════════════════════════════════════════════════════════════════════════
local function buildMsgTab(page)
    local scroll = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(74, 222, 128),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = page
    })
    addPadding(scroll, 14, 14, 16, 16)
    local layout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = scroll
    })

    local function makeSectionTitle(text, order)
        local lbl = create("TextLabel", {
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(74, 222, 128),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = text,
            Parent = scroll
        })
        registerThemeUpdater(function(t) lbl.TextColor3 = t.Accent end)
        return lbl
    end

    -- Section 1: Test Message
    makeSectionTitle("💬  KIRIM PESAN TUNGGAL (TEST)", 1)
    local testCard = create("Frame", {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 110),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = scroll
    })
    addCorner(testCard, 4)
    local tcStroke = addStroke(testCard, Color3.fromRGB(28, 40, 68), 1)

    local testInput = create("TextBox", {
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.new(1, -24, 0, 36),
        BackgroundColor3 = Color3.fromRGB(9, 12, 22),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        PlaceholderText = "Ketik pesan percobaan di sini...",
        PlaceholderColor3 = Color3.fromRGB(100, 116, 139),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = testCard
    })
    addCorner(testInput, 3)
    addStroke(testInput, Color3.fromRGB(28, 40, 68), 1)
    addPadding(testInput, 0, 0, 10, 10)

    local testRandomColor = false
    local testColToggle = create("TextButton", {
        Position = UDim2.fromOffset(12, 58),
        Size = UDim2.fromOffset(180, 38),
        BackgroundColor3 = Color3.fromRGB(20, 26, 44),
        TextColor3 = Color3.fromRGB(148, 163, 184),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        Text = "🎨 Warna Acak: OFF",
        AutoButtonColor = false,
        Parent = testCard
    })
    addCorner(testColToggle, 3)
    addStroke(testColToggle, Color3.fromRGB(28, 40, 68), 1)

    testColToggle.MouseButton1Click:Connect(function()
        testRandomColor = not testRandomColor
        local t = getTheme()
        testColToggle.Text = testRandomColor and "🎨 Warna Acak: ON" or "🎨 Warna Acak: OFF"
        testColToggle.TextColor3 = testRandomColor and t.Accent or t.TextSecondary
    end)

    local sendTestBtn = create("TextButton", {
        Position = UDim2.new(1, -150, 0, 58),
        Size = UDim2.fromOffset(138, 38),
        BackgroundColor3 = Color3.fromRGB(74, 222, 128),
        TextColor3 = Color3.fromRGB(7, 10, 20),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Text = "▶  KIRIM PESAN",
        AutoButtonColor = false,
        Parent = testCard
    })
    addCorner(sendTestBtn, 3)

    sendTestBtn.MouseButton1Click:Connect(function()
        local msg = testInput.Text
        if msg == "" then return end
        if testRandomColor then msg = applyWordColors(msg) end
        sendChatMsg(msg)
        sendTestBtn.Text = "✔ Terkirim!"
        task.delay(1.2, function() sendTestBtn.Text = "▶  KIRIM PESAN" end)
    end)

    -- Section 2: Macro Message (Spam)
    makeSectionTitle("📣  MACRO & CHAT SPAMMER OTOMATIS", 10)
    local macroCard = create("Frame", {
        LayoutOrder = 11,
        Size = UDim2.new(1, 0, 0, 200),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = scroll
    })
    addCorner(macroCard, 4)
    local mcStroke = addStroke(macroCard, Color3.fromRGB(28, 40, 68), 1)

    local macroInput = create("TextBox", {
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.new(1, -24, 0, 36),
        BackgroundColor3 = Color3.fromRGB(9, 12, 22),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        PlaceholderText = "Ketik teks macro yang ingin dispam...",
        PlaceholderColor3 = Color3.fromRGB(100, 116, 139),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = macroCard
    })
    addCorner(macroInput, 3)
    addStroke(macroInput, Color3.fromRGB(28, 40, 68), 1)
    addPadding(macroInput, 0, 0, 10, 10)

    -- Delay Stepper Card
    local delayDisplay = create("TextLabel", {
        Position = UDim2.fromOffset(12, 58),
        Size = UDim2.new(1, -150, 0, 34),
        BackgroundColor3 = Color3.fromRGB(20, 26, 44),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = string.format("   ⏱ Delay Antar Chat: %.1f detik", State.MacroDelay),
        Parent = macroCard
    })
    addCorner(delayDisplay, 3)
    addStroke(delayDisplay, Color3.fromRGB(28, 40, 68), 1)

    local delayMinus = create("TextButton", {
        Position = UDim2.new(1, -126, 0, 58),
        Size = UDim2.fromOffset(48, 34),
        BackgroundColor3 = Color3.fromRGB(20, 26, 44),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        Text = "−",
        AutoButtonColor = false,
        Parent = macroCard
    })
    addCorner(delayMinus, 3)
    addStroke(delayMinus, Color3.fromRGB(28, 40, 68), 1)

    local delayPlus = create("TextButton", {
        Position = UDim2.new(1, -68, 0, 58),
        Size = UDim2.fromOffset(48, 34),
        BackgroundColor3 = Color3.fromRGB(20, 26, 44),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        Text = "+",
        AutoButtonColor = false,
        Parent = macroCard
    })
    addCorner(delayPlus, 3)
    addStroke(delayPlus, Color3.fromRGB(28, 40, 68), 1)

    delayMinus.MouseButton1Click:Connect(function()
        State.MacroDelay = math.clamp(State.MacroDelay - 0.1, 0.1, 30.0)
        delayDisplay.Text = string.format("   ⏱ Delay Antar Chat: %.1f detik", State.MacroDelay)
    end)
    delayPlus.MouseButton1Click:Connect(function()
        State.MacroDelay = math.clamp(State.MacroDelay + 0.1, 0.1, 30.0)
        delayDisplay.Text = string.format("   ⏱ Delay Antar Chat: %.1f detik", State.MacroDelay)
    end)

    -- Macro Checkboxes: Prefix & Random Colors
    local macroAutoPrefix = false
    local macroAutoColor = false

    local togPrefixBtn = create("TextButton", {
        Position = UDim2.fromOffset(12, 102),
        Size = UDim2.new(0.5, -18, 0, 36),
        BackgroundColor3 = Color3.fromRGB(20, 26, 44),
        TextColor3 = Color3.fromRGB(148, 163, 184),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        Text = "🔤 Auto Prefix: OFF",
        AutoButtonColor = false,
        Parent = macroCard
    })
    addCorner(togPrefixBtn, 3)
    addStroke(togPrefixBtn, Color3.fromRGB(28, 40, 68), 1)

    togPrefixBtn.MouseButton1Click:Connect(function()
        macroAutoPrefix = not macroAutoPrefix
        local t = getTheme()
        togPrefixBtn.Text = macroAutoPrefix and "🔤 Auto Prefix: ON" or "🔤 Auto Prefix: OFF"
        togPrefixBtn.TextColor3 = macroAutoPrefix and t.Accent or t.TextSecondary
    end)

    local togColorBtn = create("TextButton", {
        Position = UDim2.new(0.5, 6, 0, 102),
        Size = UDim2.new(0.5, -18, 0, 36),
        BackgroundColor3 = Color3.fromRGB(20, 26, 44),
        TextColor3 = Color3.fromRGB(148, 163, 184),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        Text = "🎨 Warna Karakter: OFF",
        AutoButtonColor = false,
        Parent = macroCard
    })
    addCorner(togColorBtn, 3)
    addStroke(togColorBtn, Color3.fromRGB(28, 40, 68), 1)

    togColorBtn.MouseButton1Click:Connect(function()
        macroAutoColor = not macroAutoColor
        local t = getTheme()
        togColorBtn.Text = macroAutoColor and "🎨 Warna Karakter: ON" or "🎨 Warna Karakter: OFF"
        togColorBtn.TextColor3 = macroAutoColor and t.Accent or t.TextSecondary
    end)

    -- Start & Stop Spammer Buttons
    local startSpamBtn = create("TextButton", {
        Position = UDim2.fromOffset(12, 148),
        Size = UDim2.new(0.5, -18, 0, 40),
        BackgroundColor3 = Color3.fromRGB(74, 222, 128),
        TextColor3 = Color3.fromRGB(7, 10, 20),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Text = "▶  MULAI SPAM",
        AutoButtonColor = false,
        Parent = macroCard
    })
    addCorner(startSpamBtn, 3)

    local stopSpamBtn = create("TextButton", {
        Position = UDim2.new(0.5, 6, 0, 148),
        Size = UDim2.new(0.5, -18, 0, 40),
        BackgroundColor3 = Color3.fromRGB(239, 68, 68),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Text = "⏹  HENTIKAN",
        AutoButtonColor = false,
        Parent = macroCard
    })
    addCorner(stopSpamBtn, 3)

    startSpamBtn.MouseButton1Click:Connect(function()
        local text = macroInput.Text
        if text == "" or macroRunning then return end
        macroRunning = true
        startSpamBtn.Text = "🔄 SPAM BERJALAN"

        macroThread = task.spawn(function()
            while macroRunning do
                local msg = text
                if macroAutoPrefix then msg = string.format("[%s] %s", LocalPlayer.Name, msg) end
                if macroAutoColor then msg = applyCharColors(msg) end
                sendChatMsg(msg)
                task.wait(math.max(State.MacroDelay, 0.1))
            end
        end)
    end)

    stopSpamBtn.MouseButton1Click:Connect(function()
        stopMacro()
        startSpamBtn.Text = "▶  MULAI SPAM"
    end)

    registerThemeUpdater(function(t)
        testCard.BackgroundColor3 = t.CardBg
        tcStroke.Color = t.Stroke
        testInput.BackgroundColor3 = t.InputBg
        sendTestBtn.BackgroundColor3 = t.Accent
        sendTestBtn.TextColor3 = t.MainBg
        macroCard.BackgroundColor3 = t.CardBg
        mcStroke.Color = t.Stroke
        macroInput.BackgroundColor3 = t.InputBg
        startSpamBtn.BackgroundColor3 = t.Accent
        startSpamBtn.TextColor3 = t.MainBg
    end)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- 13. TAB 5: MODERATOR MONITOR & RADAR
-- ════════════════════════════════════════════════════════════════════════════════
local function buildModsTab(page)
    local root = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = page
    })

    -- Alert Banner Merah (Muncul Meluncur saat Mod Masuk)
    local alertBanner = create("Frame", {
        Name = "ModAlertBanner",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -60),
        Size = UDim2.new(1, -32, 0, 44),
        BackgroundColor3 = Color3.fromRGB(185, 28, 28),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 90,
        Parent = root
    })
    addCorner(alertBanner, 4)
    local abStroke = addStroke(alertBanner, Color3.fromRGB(248, 113, 113), 1.5)

    local alertLabel = create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Text = "⚠️ PERINGATAN MODERATOR TERDETEKSI!",
        ZIndex = 91,
        Parent = alertBanner
    })

    local function triggerModAlert(text)
        alertBanner.Visible = true
        alertLabel.Text = text
        alertBanner.Position = UDim2.new(0.5, 0, 0, -50)
        TweenService:Create(alertBanner, TweenSpring, { Position = UDim2.new(0.5, 0, 0, 10) }):Play()
        task.delay(4.5, function()
            local tw = TweenService:Create(alertBanner, TweenFast, { Position = UDim2.new(0.5, 0, 0, -60) })
            tw:Play()
            tw.Completed:Connect(function() alertBanner.Visible = false end)
        end)
    end

    local scroll = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(74, 222, 128),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = root
    })
    addPadding(scroll, 14, 14, 16, 16)
    local layout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = scroll
    })

    local function makeSectionTitle(text, order)
        local lbl = create("TextLabel", {
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(74, 222, 128),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = text,
            Parent = scroll
        })
        registerThemeUpdater(function(t) lbl.TextColor3 = t.Accent end)
        return lbl
    end

    local function makeModToggleCard(order, title, desc, key)
        local card = create("Frame", {
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 52),
            BackgroundColor3 = Color3.fromRGB(13, 17, 32),
            Parent = scroll
        })
        addCorner(card, 4)
        local cStroke = addStroke(card, Color3.fromRGB(28, 40, 68), 1)

        local tLbl = create("TextLabel", {
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -80, 0, 18),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(240, 245, 255),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = title,
            Parent = card
        })

        local dLbl = create("TextLabel", {
            Position = UDim2.fromOffset(14, 28),
            Size = UDim2.new(1, -80, 0, 16),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(148, 163, 184),
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = desc,
            Parent = card
        })

        local track = create("TextButton", {
            Position = UDim2.new(1, -64, 0.5, -12),
            Size = UDim2.fromOffset(48, 24),
            BackgroundColor3 = ModState[key] and Color3.fromRGB(74, 222, 128) or Color3.fromRGB(36, 44, 62),
            AutoButtonColor = false,
            Text = "",
            Parent = card
        })
        addCorner(track, 12)

        local knob = create("Frame", {
            Position = ModState[key] and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9),
            Size = UDim2.fromOffset(18, 18),
            BackgroundColor3 = Color3.fromRGB(240, 245, 255),
            BorderSizePixel = 0,
            Parent = track
        })
        addCorner(knob, 9)

        track.MouseButton1Click:Connect(function()
            ModState[key] = not ModState[key]
            local on = ModState[key]
            local t = getTheme()
            TweenService:Create(track, TweenFast, { BackgroundColor3 = on and t.ToggleOn or t.ToggleOff }):Play()
            TweenService:Create(knob, TweenFast, { Position = on and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9) }):Play()
        end)
        return card
    end

    makeSectionTitle("🛡️  PENGATURAN DETEKSI MODERATOR", 1)
    makeModToggleCard(2, "🛑  Auto Stop All SC", "Hentikan otomatis seluruh fitur aktif saat mod terdeteksi memasuki world.", "autoStop")
    makeModToggleCard(3, "💤  Avoid / Sleep Farm", "Tidur sejenak / jeda Auto Farm otomatis bila mod terdeteksi di sekitar kamu.", "avoidSleep")
    makeModToggleCard(4, "🔔  Notifikasi Masuk", "Tampilkan banner peringatan merah di atas layar saat ada mod masuk / keluar.", "notifyOnEnter")

    makeSectionTitle("👥  MODERATOR AKTIF DI WORLD INI", 10)
    local listContainer = create("Frame", {
        LayoutOrder = 11,
        Size = UDim2.new(1, 0, 0, 10),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = scroll
    })
    local lLayout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = listContainer
    })

    local emptyNotice = create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = listContainer
    })
    addCorner(emptyNotice, 4)
    addStroke(emptyNotice, Color3.fromRGB(28, 40, 68), 1)

    local noticeLbl = create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(74, 222, 128),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        Text = "✅ Aman! Tidak ada moderator atau staf terdeteksi di world ini.",
        Parent = emptyNotice
    })

    local modCards = {}
    local function addModToUI(plr)
        if modCards[plr] then return end
        emptyNotice.Visible = false

        local card = create("Frame", {
            Name = "ModCard_" .. plr.UserId,
            Size = UDim2.new(1, 0, 0, 52),
            BackgroundColor3 = Color3.fromRGB(48, 16, 20),
            Parent = listContainer
        })
        addCorner(card, 4)
        addStroke(card, Color3.fromRGB(239, 68, 68), 1)

        local tag = plr:GetAttribute("Tag") or "moderator"
        local nameTitle = create("TextLabel", {
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -28, 0, 18),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(254, 202, 202),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.format("🛡️ %s  [%s]", plr.Name, tag:upper()),
            Parent = card
        })

        local subDetails = create("TextLabel", {
            Position = UDim2.fromOffset(14, 28),
            Size = UDim2.new(1, -28, 0, 16),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(248, 113, 113),
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.format("User ID: %d  ·  Game Name: %s", plr.UserId, tostring(plr:GetAttribute("GameName") or "(Unknown)")),
            Parent = card
        })

        modCards[plr] = card
    end

    local function removeModFromUI(plr)
        local card = modCards[plr]
        if card then
            card:Destroy()
            modCards[plr] = nil
        end
        if next(modCards) == nil then
            emptyNotice.Visible = true
        end
    end

    -- Initial Scan & Event Listeners
    for _, p in ipairs(getOnlineMods()) do addModToUI(p) end

    Players.PlayerAdded:Connect(function(plr)
        task.wait(1.5)
        if isPlayerMod(plr) then
            addModToUI(plr)
            if ModState.notifyOnEnter then
                triggerModAlert(string.format("⚠️ MOD MASUK: %s (%s)", plr.Name, tostring(plr:GetAttribute("Tag")):upper()))
            end
            if ModState.autoStop then SCController.stopAll() end
        end
    end)

    Players.PlayerRemoving:Connect(function(plr)
        if modCards[plr] then
            removeModFromUI(plr)
            if ModState.notifyOnEnter then
                triggerModAlert(string.format("ℹ️ MOD KELUAR: %s", plr.Name))
            end
        end
    end)

    RunService.Heartbeat:Connect(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            local isMod = isPlayerMod(plr)
            if isMod and not modCards[plr] then
                addModToUI(plr)
                if ModState.notifyOnEnter then
                    triggerModAlert(string.format("⚠️ MOD TERDETEKSI: %s", plr.Name))
                end
                if ModState.autoStop then SCController.stopAll() end
            elseif not isMod and modCards[plr] then
                removeModFromUI(plr)
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- 14. TAB 6: AUTO FARM (2x3 MODE SELECTOR & STATS ENGINE)
-- ════════════════════════════════════════════════════════════════════════════════
local function buildAutoFarmTab(page)
    local scroll = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(74, 222, 128),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = page
    })
    addPadding(scroll, 14, 14, 16, 16)
    local layout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = scroll
    })

    local function makeSectionTitle(text, order)
        local lbl = create("TextLabel", {
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(74, 222, 128),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = text,
            Parent = scroll
        })
        registerThemeUpdater(function(t) lbl.TextColor3 = t.Accent end)
        return lbl
    end

    -- Card 1: Stats Display
    makeSectionTitle("📊  STATISTIK HASIL FARM", 1)
    local statsCard = create("Frame", {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 72),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = scroll
    })
    addCorner(statsCard, 4)
    local stStroke = addStroke(statsCard, Color3.fromRGB(28, 40, 68), 1)

    local statsLabel = create("TextLabel", {
        Position = UDim2.fromOffset(14, 10),
        Size = UDim2.new(1, -28, 1, -20),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Text = "Planted: 0   ·   Harvested: 0   ·   Items Collected: 0   ·   Runs: 0",
        Parent = statsCard
    })

    local function refreshStatsUI()
        statsLabel.Text = string.format(
            "🌱 Benih Ditanam: %d    🌾 Panen: %d    📦 Item Diambil: %d    🔁 Putaran: %d",
            FarmStats.seedsPlaced, FarmStats.seedsHarvested, FarmStats.itemsCollected, FarmStats.runsCompleted
        )
    end
    onFarmStatsChanged = refreshStatsUI

    -- Card 2: 2x3 Grid Mode Selector
    makeSectionTitle("🌾  PILIH MODE FARMING", 10)
    local modeContainer = create("Frame", {
        LayoutOrder = 11,
        Size = UDim2.new(1, 0, 0, 116),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = scroll
    })
    addCorner(modeContainer, 4)
    local mcStroke = addStroke(modeContainer, Color3.fromRGB(28, 40, 68), 1)
    addPadding(modeContainer, 8, 8, 8, 8)

    local FARM_MODES = {
        { key = "PNB",     icon = "⛏️", label = "PNB Mode",    desc = "Break→Place→Take" },
        { key = "DF",      icon = "🗺️", label = "DF Layout",   desc = "Dirt Background" },
        { key = "CLEAR",   icon = "🧹", label = "Clear World", desc = "Hancurkan Blok" },
        { key = "PABRIK",  icon = "🏭", label = "Pabrik Loop", desc = "Panen Area Tetap" },
        { key = "SPLICE",  icon = "🧬", label = "Splice Seed", desc = "Kawin Silang Benih" },
        { key = "HARVEST", icon = "🌾", label = "Harvest All", desc = "Panen Pohon Siap" },
    }

    local selectedFarmMode = "HARVEST"
    local modeButtons = {}

    local mGridLayout = create("UIGridLayout", {
        CellSize = UDim2.new(0.333, -6, 0, 46),
        CellPadding = UDim2.fromOffset(8, 8),
        Parent = modeContainer
    })

    for _, fm in ipairs(FARM_MODES) do
        local btn = create("TextButton", {
            Name = "FarmMode_" .. fm.key,
            BackgroundColor3 = (fm.key == selectedFarmMode) and Color3.fromRGB(74, 222, 128) or Color3.fromRGB(20, 26, 44),
            AutoButtonColor = false,
            Text = "",
            Parent = modeContainer
        })
        addCorner(btn, 3)
        local btnStroke = addStroke(btn, Color3.fromRGB(28, 40, 68), 1)

        local tLbl = create("TextLabel", {
            Position = UDim2.fromOffset(6, 4),
            Size = UDim2.new(1, -12, 0, 18),
            BackgroundTransparency = 1,
            TextColor3 = (fm.key == selectedFarmMode) and Color3.fromRGB(7, 10, 20) or Color3.fromRGB(240, 245, 255),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = fm.icon .. " " .. fm.label,
            Parent = btn
        })

        local dLbl = create("TextLabel", {
            Position = UDim2.fromOffset(6, 24),
            Size = UDim2.new(1, -12, 0, 16),
            BackgroundTransparency = 1,
            TextColor3 = (fm.key == selectedFarmMode) and Color3.fromRGB(15, 25, 40) or Color3.fromRGB(148, 163, 184),
            Font = Enum.Font.Gotham,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = fm.desc,
            Parent = btn
        })

        btn.MouseButton1Click:Connect(function()
            selectedFarmMode = fm.key
            for k, b in pairs(modeButtons) do
                local isSel = (k == selectedFarmMode)
                local t = getTheme()
                b.BackgroundColor3 = isSel and t.Accent or Color3.fromRGB(20, 26, 44)
                local l = b:FindFirstChildOfClass("TextLabel")
                if l then l.TextColor3 = isSel and t.MainBg or t.TextPrimary end
            end
        end)
        modeButtons[fm.key] = btn
    end

    -- Card 3: Parameters (Delay & Movement & Seed ID)
    makeSectionTitle("⚙️  PARAMETER PENGATURAN", 20)
    local paramCard = create("Frame", {
        LayoutOrder = 21,
        Size = UDim2.new(1, 0, 0, 140),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = scroll
    })
    addCorner(paramCard, 4)
    local pcStroke = addStroke(paramCard, Color3.fromRGB(28, 40, 68), 1)

    -- Delay Stepper
    local delayLbl = create("TextLabel", {
        Position = UDim2.fromOffset(14, 12),
        Size = UDim2.new(1, -150, 0, 32),
        BackgroundColor3 = Color3.fromRGB(20, 26, 44),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = string.format("   ⏱ Farm Speed Delay: %.2fs", State.FarmDelay),
        Parent = paramCard
    })
    addCorner(delayLbl, 3)
    addStroke(delayLbl, Color3.fromRGB(28, 40, 68), 1)

    local fDelayMinus = create("TextButton", {
        Position = UDim2.new(1, -126, 0, 12),
        Size = UDim2.fromOffset(48, 32),
        BackgroundColor3 = Color3.fromRGB(20, 26, 44),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        Text = "−",
        AutoButtonColor = false,
        Parent = paramCard
    })
    addCorner(fDelayMinus, 3)
    addStroke(fDelayMinus, Color3.fromRGB(28, 40, 68), 1)

    local fDelayPlus = create("TextButton", {
        Position = UDim2.new(1, -68, 0, 12),
        Size = UDim2.fromOffset(48, 32),
        BackgroundColor3 = Color3.fromRGB(20, 26, 44),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        Text = "+",
        AutoButtonColor = false,
        Parent = paramCard
    })
    addCorner(fDelayPlus, 3)
    addStroke(fDelayPlus, Color3.fromRGB(28, 40, 68), 1)

    fDelayMinus.MouseButton1Click:Connect(function()
        State.FarmDelay = math.clamp(State.FarmDelay - 0.01, 0.01, 3.0)
        delayLbl.Text = string.format("   ⏱ Farm Speed Delay: %.2fs", State.FarmDelay)
    end)
    fDelayPlus.MouseButton1Click:Connect(function()
        State.FarmDelay = math.clamp(State.FarmDelay + 0.01, 0.01, 3.0)
        delayLbl.Text = string.format("   ⏱ Farm Speed Delay: %.2fs", State.FarmDelay)
    end)

    -- Collect Method Selector
    local tpBtn = create("TextButton", {
        Position = UDim2.fromOffset(14, 52),
        Size = UDim2.new(0.5, -20, 0, 34),
        BackgroundColor3 = (State.CollectMethod == "teleport") and Color3.fromRGB(74, 222, 128) or Color3.fromRGB(20, 26, 44),
        TextColor3 = (State.CollectMethod == "teleport") and Color3.fromRGB(7, 10, 20) or Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Text = "🌀 Teleport Ke Drop",
        AutoButtonColor = false,
        Parent = paramCard
    })
    addCorner(tpBtn, 3)
    addStroke(tpBtn, Color3.fromRGB(28, 40, 68), 1)

    local walkBtn = create("TextButton", {
        Position = UDim2.new(0.5, 6, 0, 52),
        Size = UDim2.new(0.5, -20, 0, 34),
        BackgroundColor3 = (State.CollectMethod == "walk") and Color3.fromRGB(74, 222, 128) or Color3.fromRGB(20, 26, 44),
        TextColor3 = (State.CollectMethod == "walk") and Color3.fromRGB(7, 10, 20) or Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Text = "🚶 Jalan Normal",
        AutoButtonColor = false,
        Parent = paramCard
    })
    addCorner(walkBtn, 3)
    addStroke(walkBtn, Color3.fromRGB(28, 40, 68), 1)

    tpBtn.MouseButton1Click:Connect(function()
        State.CollectMethod = "teleport"
        local t = getTheme()
        tpBtn.BackgroundColor3 = t.Accent; tpBtn.TextColor3 = t.MainBg
        walkBtn.BackgroundColor3 = Color3.fromRGB(20, 26, 44); walkBtn.TextColor3 = t.TextPrimary
    end)
    walkBtn.MouseButton1Click:Connect(function()
        State.CollectMethod = "walk"
        local t = getTheme()
        walkBtn.BackgroundColor3 = t.Accent; walkBtn.TextColor3 = t.MainBg
        tpBtn.BackgroundColor3 = Color3.fromRGB(20, 26, 44); tpBtn.TextColor3 = t.TextPrimary
    end)

    -- Seed Inputs
    local seedAInput = create("TextBox", {
        Position = UDim2.fromOffset(14, 94),
        Size = UDim2.new(0.5, -20, 0, 34),
        BackgroundColor3 = Color3.fromRGB(9, 12, 22),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        PlaceholderText = "Seed ID Utama (0)",
        PlaceholderColor3 = Color3.fromRGB(100, 116, 139),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        Text = "0",
        ClearTextOnFocus = false,
        Parent = paramCard
    })
    addCorner(seedAInput, 3)
    addStroke(seedAInput, Color3.fromRGB(28, 40, 68), 1)
    addPadding(seedAInput, 0, 0, 10, 10)

    local seedBInput = create("TextBox", {
        Position = UDim2.new(0.5, 6, 0, 94),
        Size = UDim2.new(0.5, -20, 0, 34),
        BackgroundColor3 = Color3.fromRGB(9, 12, 22),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        PlaceholderText = "Seed ID B (Splice)",
        PlaceholderColor3 = Color3.fromRGB(100, 116, 139),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        Text = "0",
        ClearTextOnFocus = false,
        Parent = paramCard
    })
    addCorner(seedBInput, 3)
    addStroke(seedBInput, Color3.fromRGB(28, 40, 68), 1)
    addPadding(seedBInput, 0, 0, 10, 10)

    -- Webhook Input
    makeSectionTitle("🔗  DISCORD WEBHOOK NOTIFIER (OPSIONAL)", 30)
    local wbInput = create("TextBox", {
        LayoutOrder = 31,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        PlaceholderText = "Tempel URL Discord Webhook di sini...",
        PlaceholderColor3 = Color3.fromRGB(100, 116, 139),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = scroll
    })
    addCorner(wbInput, 3)
    addStroke(wbInput, Color3.fromRGB(28, 40, 68), 1)
    addPadding(wbInput, 0, 0, 12, 12)
    wbInput:GetPropertyChangedSignal("Text"):Connect(function()
        State.WebhookURL = wbInput.Text
    end)

    -- Start & Stop Big Buttons
    local controlFrame = create("Frame", {
        LayoutOrder = 40,
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
        Parent = scroll
    })
    local startBtn = create("TextButton", {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0.5, -6, 1, 0),
        BackgroundColor3 = Color3.fromRGB(74, 222, 128),
        TextColor3 = Color3.fromRGB(7, 10, 20),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Text = "▶  START AUTO FARM",
        AutoButtonColor = false,
        Parent = controlFrame
    })
    addCorner(startBtn, 4)

    local stopBtn = create("TextButton", {
        Position = UDim2.new(0.5, 6, 0, 0),
        Size = UDim2.new(0.5, -6, 1, 0),
        BackgroundColor3 = Color3.fromRGB(239, 68, 68),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Text = "⏹  STOP FARM",
        AutoButtonColor = false,
        Parent = controlFrame
    })
    addCorner(stopBtn, 4)

    startBtn.MouseButton1Click:Connect(function()
        if farmRunning then return end
        local sA = tonumber(seedAInput.Text) or 0
        local sB = tonumber(seedBInput.Text) or 0
        startAutoFarm(selectedFarmMode, {
            seedId = sA,
            seedA  = sA,
            seedB  = sB,
            onDone = function()
                refreshStatsUI()
                sendDiscordWebhook(string.format("🌾 [GrowbloxSC] Selesai Farm Mode %s! Benih: %d | Items: %d",
                    selectedFarmMode, FarmStats.seedsPlaced, FarmStats.itemsCollected))
            end
        })
        startBtn.Text = "🔄 SEDANG BERJALAN..."
    end)

    stopBtn.MouseButton1Click:Connect(function()
        stopAutoFarm()
        startBtn.Text = "▶  START AUTO FARM"
    end)

    registerThemeUpdater(function(t)
        statsCard.BackgroundColor3 = t.CardBg
        stStroke.Color = t.Stroke
        statsLabel.TextColor3 = t.TextPrimary
        modeContainer.BackgroundColor3 = t.CardBg
        mcStroke.Color = t.Stroke
        paramCard.BackgroundColor3 = t.CardBg
        pcStroke.Color = t.Stroke
        delayLbl.BackgroundColor3 = t.InputBg
        wbInput.BackgroundColor3 = t.InputBg
        startBtn.BackgroundColor3 = t.Accent
        startBtn.TextColor3 = t.MainBg
    end)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- 15. TAB 7: SETTINGS & THEME CUSTOMIZATION
-- ════════════════════════════════════════════════════════════════════════════════
local function buildSettingsTab(page)
    local scroll = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(74, 222, 128),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = page
    })
    addPadding(scroll, 14, 14, 16, 16)
    local layout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = scroll
    })

    local function makeSectionTitle(text, order)
        local lbl = create("TextLabel", {
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(74, 222, 128),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = text,
            Parent = scroll
        })
        registerThemeUpdater(function(t) lbl.TextColor3 = t.Accent end)
        return lbl
    end

    -- Toggle Auto Reload
    makeSectionTitle("🔄  PERILAKU AUTO RELOAD", 1)
    local autoReloadCard = create("Frame", {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = scroll
    })
    addCorner(autoReloadCard, 4)
    local arcStroke = addStroke(autoReloadCard, Color3.fromRGB(28, 40, 68), 1)

    local arTitle = create("TextLabel", {
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.new(1, -80, 0, 18),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "🔄  Auto Reload SC saat Ganti World",
        Parent = autoReloadCard
    })

    local arDesc = create("TextLabel", {
        Position = UDim2.fromOffset(14, 28),
        Size = UDim2.new(1, -80, 0, 16),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(148, 163, 184),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Membuka kembali interface & mengaktifkan setting secara otomatis ketika masuk world baru.",
        Parent = autoReloadCard
    })

    local arTrack = create("TextButton", {
        Position = UDim2.new(1, -64, 0.5, -12),
        Size = UDim2.fromOffset(48, 24),
        BackgroundColor3 = State.AutoReload and Color3.fromRGB(74, 222, 128) or Color3.fromRGB(36, 44, 62),
        AutoButtonColor = false,
        Text = "",
        Parent = autoReloadCard
    })
    addCorner(arTrack, 12)

    local arKnob = create("Frame", {
        Position = State.AutoReload and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = Color3.fromRGB(240, 245, 255),
        BorderSizePixel = 0,
        Parent = arTrack
    })
    addCorner(arKnob, 9)

    arTrack.MouseButton1Click:Connect(function()
        State.AutoReload = not State.AutoReload
        local t = getTheme()
        TweenService:Create(arTrack, TweenFast, { BackgroundColor3 = State.AutoReload and t.ToggleOn or t.ToggleOff }):Play()
        TweenService:Create(arKnob, TweenFast, { Position = State.AutoReload and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9) }):Play()
    end)

    -- Auto reload world listener
    LocalPlayer:GetAttributeChangedSignal("World"):Connect(function()
        if State.AutoReload then
            task.wait(2.0)
            SCController.reopen()
        end
    end)

    -- Config Actions: Save, Load, Clear
    makeSectionTitle("💾  MANAJEMEN KONFIGURASI LOKAL", 10)
    local cfgStatusLabel = create("TextLabel", {
        LayoutOrder = 11,
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(74, 222, 128),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        Text = "",
        Parent = scroll
    })

    local cfgActionRow = create("Frame", {
        LayoutOrder = 12,
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        Parent = scroll
    })

    local saveBtn = create("TextButton", {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0.333, -6, 1, 0),
        BackgroundColor3 = Color3.fromRGB(74, 222, 128),
        TextColor3 = Color3.fromRGB(7, 10, 20),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Text = "💾 Simpan Config",
        AutoButtonColor = false,
        Parent = cfgActionRow
    })
    addCorner(saveBtn, 3)

    local loadBtn = create("TextButton", {
        Position = UDim2.new(0.333, 3, 0, 0),
        Size = UDim2.new(0.333, -6, 1, 0),
        BackgroundColor3 = Color3.fromRGB(20, 26, 44),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Text = "📂 Muat Config",
        AutoButtonColor = false,
        Parent = cfgActionRow
    })
    addCorner(loadBtn, 3)
    addStroke(loadBtn, Color3.fromRGB(28, 40, 68), 1)

    local clearBtn = create("TextButton", {
        Position = UDim2.new(0.666, 6, 0, 0),
        Size = UDim2.new(0.333, -6, 1, 0),
        BackgroundColor3 = Color3.fromRGB(64, 20, 20),
        TextColor3 = Color3.fromRGB(254, 202, 202),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Text = "🗑️ Hapus Config",
        AutoButtonColor = false,
        Parent = cfgActionRow
    })
    addCorner(clearBtn, 3)
    addStroke(clearBtn, Color3.fromRGB(239, 68, 68), 1)

    saveBtn.MouseButton1Click:Connect(function()
        SCController.save()
        cfgStatusLabel.Text = "✅ Konfigurasi berhasil disimpan secara lokal!"
        task.delay(3, function() cfgStatusLabel.Text = "" end)
    end)

    loadBtn.MouseButton1Click:Connect(function()
        local ok = SCController.load()
        if ok then
            cfgStatusLabel.Text = "✅ Konfigurasi berhasil dimuat!"
        else
            cfgStatusLabel.Text = "⚠️ Tidak ditemukan config tersimpan."
        end
        task.delay(3, function() cfgStatusLabel.Text = "" end)
    end)

    clearBtn.MouseButton1Click:Connect(function()
        SCController.clear()
        cfgStatusLabel.Text = "🗑️ Konfigurasi lokal telah dibersihkan."
        task.delay(3, function() cfgStatusLabel.Text = "" end)
    end)

    -- Theme Selector (4 Tema Modern Pixel)
    makeSectionTitle("🎨  PILIH TEMA INTERFACE", 20)
    local themeGrid = create("Frame", {
        LayoutOrder = 21,
        Size = UDim2.new(1, 0, 0, 80),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = scroll
    })
    addCorner(themeGrid, 4)
    local tgStroke = addStroke(themeGrid, Color3.fromRGB(28, 40, 68), 1)
    addPadding(themeGrid, 8, 8, 8, 8)

    local tgl = create("UIGridLayout", {
        CellSize = UDim2.new(0.25, -6, 1, 0),
        CellPadding = UDim2.fromOffset(8, 0),
        Parent = themeGrid
    })

    for idx, tName in ipairs(ThemeOrder) do
        local tData = Themes[tName]
        local tCard = create("TextButton", {
            Name = "ThemeCard_" .. tName,
            BackgroundColor3 = tData.PanelBg,
            AutoButtonColor = false,
            Text = "",
            Parent = themeGrid
        })
        addCorner(tCard, 3)
        local tcStroke = addStroke(tCard, (idx == State.ThemeIndex) and tData.Accent or tData.Stroke, (idx == State.ThemeIndex) and 1.5 or 1)

        local tColorStrip = create("Frame", {
            Position = UDim2.fromOffset(6, 6),
            Size = UDim2.fromOffset(12, 12),
            BackgroundColor3 = tData.Accent,
            BorderSizePixel = 0,
            Parent = tCard
        })
        addCorner(tColorStrip, 2)

        local tNameLbl = create("TextLabel", {
            Position = UDim2.fromOffset(24, 4),
            Size = UDim2.new(1, -28, 0, 16),
            BackgroundTransparency = 1,
            TextColor3 = tData.TextPrimary,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tData.Name:match("^(%w+)"),
            Parent = tCard
        })

        local tDescLbl = create("TextLabel", {
            Position = UDim2.fromOffset(6, 24),
            Size = UDim2.new(1, -12, 0, 32),
            BackgroundTransparency = 1,
            TextColor3 = tData.TextSecondary,
            Font = Enum.Font.Gotham,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Text = (idx == State.ThemeIndex) and "AKTIF ✔" or "Pilih",
            Parent = tCard
        })

        tCard.MouseButton1Click:Connect(function()
            State.ThemeIndex = idx
            broadcastTheme()
            for i, name in ipairs(ThemeOrder) do
                local c = themeGrid:FindFirstChild("ThemeCard_" .. name)
                if c then
                    local s = c:FindFirstChildOfClass("UIStroke")
                    local dl = c:FindFirstChildOfClass("TextLabel")
                    if s then s.Color = (i == State.ThemeIndex) and Themes[name].Accent or Themes[name].Stroke end
                end
            end
        end)
    end

    -- About SC Card
    makeSectionTitle("ℹ️  TENTANG ENGINE & VERSI", 30)
    local aboutCard = create("Frame", {
        LayoutOrder = 31,
        Size = UDim2.new(1, 0, 0, 78),
        BackgroundColor3 = Color3.fromRGB(13, 17, 32),
        Parent = scroll
    })
    addCorner(aboutCard, 4)
    local abStroke = addStroke(aboutCard, Color3.fromRGB(28, 40, 68), 1)

    local aboutText = create("TextLabel", {
        Position = UDim2.fromOffset(14, 10),
        Size = UDim2.new(1, -28, 1, -20),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(148, 163, 184),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Text = "GrowbloxSC v2.0 (Pixel Suite Monolith)\nDirancang & dioptimasi khusus untuk game Growblox.\nSemua logika inline mandiri, mendukung eksekutor modern dengan integrasi UI TopBar safe.",
        Parent = aboutCard
    })

    registerThemeUpdater(function(t)
        autoReloadCard.BackgroundColor3 = t.CardBg
        arcStroke.Color = t.Stroke
        arTitle.TextColor3 = t.TextPrimary
        arDesc.TextColor3 = t.TextSecondary
        themeGrid.BackgroundColor3 = t.CardBg
        tgStroke.Color = t.Stroke
        aboutCard.BackgroundColor3 = t.CardBg
        abStroke.Color = t.Stroke
        aboutText.TextColor3 = t.TextSecondary
        saveBtn.BackgroundColor3 = t.Accent
        saveBtn.TextColor3 = t.MainBg
    end)
end

-- ════════════════════════════════════════════════════════════════════════════════
-- 16. INISIALISASI HALAMAN & STARTUP SEQUENCE
-- ════════════════════════════════════════════════════════════════════════════════
buildItemTab(TabPages["item"])
buildMiscTab(TabPages["misc"])
buildPlayerTab(TabPages["player"])
buildMsgTab(TabPages["msg"])
buildModsTab(TabPages["mods"])
buildAutoFarmTab(TabPages["farm"])
buildSettingsTab(TabPages["set"])

-- Auto Load Konfigurasi Tersimpan saat Pertama Dibuka
task.spawn(function()
    pcall(function()
        SCController.load()
    end)
end)

-- Keybind Toggle: Insert atau RightShift
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.Insert or inp.KeyCode == Enum.KeyCode.RightShift then
        HUDCanvas.Visible = not HUDCanvas.Visible
    end
end)

-- Startup Loader Animation Routine
task.spawn(function()
    computeAndApplyProportionalScale()

    local skipped = false
    SkipIntroBtn.MouseButton1Click:Connect(function()
        skipped = true
    end)

    local stages = {
        { pct = 0.25, msg = "Mounting Game Engine Services... 25%" },
        { pct = 0.50, msg = "Indexing ReplicatedStorage DBs... 50%" },
        { pct = 0.75, msg = "Setting up Proportional Pixel Canvas... 75%" },
        { pct = 1.00, msg = "GrowbloxSC v2.0 Workspace Ready! 100%" },
    }

    -- Animate pixel grid cells
    task.spawn(function()
        for i, cell in ipairs(pixelGridCells) do
            if skipped then break end
            TweenService:Create(cell, TweenFast, { BackgroundColor3 = Color3.fromRGB(74, 222, 128) }):Play()
            task.wait(0.015)
        end
    end)

    for _, stage in ipairs(stages) do
        if skipped then break end
        IntroStatusText.Text = stage.msg
        TweenService:Create(IntroProgressFill, TweenFast, { Size = UDim2.fromScale(stage.pct, 1) }):Play()
        task.wait(0.35)
    end

    -- Selesai Startup: Transisi Masuk ke Menu Utama
    TweenService:Create(StartupOverlay, TweenFast, { BackgroundTransparency = 1 }):Play()
    local scaleTw = TweenService:Create(StartupUIScale, TweenFast, { Scale = 0.85 })
    scaleTw:Play()
    scaleTw.Completed:Connect(function()
        StartupOverlay:Destroy()
        HUDCanvas.Visible = true
        -- Hitung skala final yang benar lalu spring-reveal dari sedikit lebih kecil
        computeAndApplyProportionalScale()
        local finalScale = ProportionalUIScale.Scale
        ProportionalUIScale.Scale = finalScale * 0.88
        TweenService:Create(ProportionalUIScale, TweenSpring, { Scale = finalScale }):Play()
    end)
end)

warn("[GrowbloxSC v2.0] Loaded successfully! Tekan Insert atau RightShift untuk toggle.")
