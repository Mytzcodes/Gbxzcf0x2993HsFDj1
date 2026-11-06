--[[
    ================================================================================
    DRY CURSED | HUB (community) — MONOCHROME DEEP BLUE PREMIERE UI v6.0
    ================================================================================
    Penempatan   : StarterPlayer -> StarterPlayerScripts (LocalScript)
    Perbaikan & Desain v6.0 :
      1. Pure Proportional Scaling (Bukan Crop!):
         - Seluruh jendela menu menggunakan ukuran kanvas referensi tetap (1060 x 600)
           yang dikendalikan 100% melalui UIScale.
         - Saat dikecilkan/dibesarkan lewat pojok kanan bawah (atau otomatis mengikuti
           layar HP/PC), SEMUA teks, tombol, sudut, dan kartu ikut mengecil/membesar
           secara proporsional tanpa ada teks yang terpotong (crop).
      2. Fix ZIndex & Menutupi Area TopBar/Logo Roblox:
         - Menggunakan ZIndexBehavior.Sibling dengan hierarki bersih sehingga tidak ada
           satu pun teks atau tombol yang tenggelam di belakang background.
         - DisplayOrder = 2147483647 (Maksimum) + IgnoreGuiInset = true + ScreenInsets.None
           + menonaktifkan CoreGui sementara saat menu fokus + Top-Left Brand Shield
           yang menutup area pojok kiri atas (logo Roblox).
      3. Tema Monochrome Art & Deep Blue Premiere Gradient:
         - Menghilangkan warna cyberpunk mencolok; beralih ke estetika Monochrome Art
           & Deep Midnight Blue Premiere Gradient yang elegan, bersih, dan tajam.
      4. Branding Kiri Atas:
         - Logo Monogram + Judul Utama "Dry Cursed | Hub" dan sub-judul "community".
      5. Lightweight Motion Graphics & Illustrative Startup Loader:
         - Animasi ringan ramah FPS: pergeseran halus gradien Premiere, ilustrasi
           gerhana geometris monokrom (Monochrome Eclipse Art) saat pertama mulai,
           dan transisi pegas lembut.
    ================================================================================
]]

-- // SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- // Bersihkan UI & Blur lama bila script dijalankan ulang
local oldGui = PlayerGui:FindFirstChild("DryCursedHubUI")
if oldGui then
    oldGui:Destroy()
end
local oldBlur = Lighting:FindFirstChild("DryCursedModalBlur")
if oldBlur then
    oldBlur:Destroy()
end

-- ================================================================================
-- 1. PALET TEMA: MONOCHROME ART & DEEP BLUE PREMIERE GRADIENT
-- ================================================================================
local Themes = {
    ["Premiere Deep Blue"] = {
        Name            = "Premiere Deep Blue",
        MainBg          = Color3.fromRGB(7, 10, 17),     -- #070A11 Obsidian Navy
        PanelBg         = Color3.fromRGB(11, 16, 28),    -- #0B101C Deep Midnight
        GradStart       = Color3.fromRGB(16, 28, 54),    -- #101C36 Premiere Sapphire
        GradMid         = Color3.fromRGB(10, 17, 32),    -- #0A1120 Deep Slate Blue
        GradEnd         = Color3.fromRGB(6, 9, 16),      -- #060910 Monochrome Ink
        CardBg          = Color3.fromRGB(14, 21, 36),    -- #0E1524 Card Surface
        CardHover       = Color3.fromRGB(20, 30, 50),    -- #141E32 Card Hover
        SelectorBg      = Color3.fromRGB(22, 36, 64),    -- #162440 Pill Background
        SelectorHover   = Color3.fromRGB(30, 48, 84),    -- #1E3054 Pill Hover
        InputBg         = Color3.fromRGB(6, 9, 15),      -- #06090F Input Well
        Accent          = Color3.fromRGB(147, 197, 253), -- #93C5FD Crisp Ice Blue
        AccentSecondary = Color3.fromRGB(59, 130, 246),  -- #3B82F6 Premiere Royal Blue
        TextPrimary     = Color3.fromRGB(248, 250, 252), -- #F8FAFC Pure Alabaster
        TextSecondary   = Color3.fromRGB(165, 180, 204), -- #A5B4CC Silver Slate
        TextMuted       = Color3.fromRGB(100, 116, 142), -- #64748E Muted Steel
        Stroke          = Color3.fromRGB(34, 50, 80),    -- #223250 Hairline Border
    },
    ["Monochrome Obsidian"] = {
        Name            = "Monochrome Obsidian Art",
        MainBg          = Color3.fromRGB(9, 9, 11),      -- #09090B Pure Carbon
        PanelBg         = Color3.fromRGB(15, 15, 18),    -- #0F0F12 Zinc Dark
        GradStart       = Color3.fromRGB(28, 28, 34),    -- #1C1C22 Charcoal Art
        GradMid         = Color3.fromRGB(16, 16, 20),    -- #101014 Deep Graphite
        GradEnd         = Color3.fromRGB(8, 8, 10),      -- #08080A Pitch Black
        CardBg          = Color3.fromRGB(20, 20, 24),    -- #141418
        CardHover       = Color3.fromRGB(28, 28, 34),    -- #1C1C22
        SelectorBg      = Color3.fromRGB(32, 32, 38),    -- #202026
        SelectorHover   = Color3.fromRGB(44, 44, 52),    -- #2C2C34
        InputBg         = Color3.fromRGB(7, 7, 9),       -- #070709
        Accent          = Color3.fromRGB(228, 228, 231), -- #E4E4E7 Platinum White
        AccentSecondary = Color3.fromRGB(140, 140, 152), -- #8C8C98 Silver Grey
        TextPrimary     = Color3.fromRGB(250, 250, 250),
        TextSecondary   = Color3.fromRGB(161, 161, 170),
        TextMuted       = Color3.fromRGB(105, 105, 115),
        Stroke          = Color3.fromRGB(45, 45, 54),
    },
    ["Abyssal Indigo"] = {
        Name            = "Abyssal Indigo Blue",
        MainBg          = Color3.fromRGB(8, 9, 20),
        PanelBg         = Color3.fromRGB(13, 15, 32),
        GradStart       = Color3.fromRGB(22, 26, 58),
        GradMid         = Color3.fromRGB(12, 15, 34),
        GradEnd         = Color3.fromRGB(7, 8, 18),
        CardBg          = Color3.fromRGB(17, 20, 42),
        CardHover       = Color3.fromRGB(24, 29, 58),
        SelectorBg      = Color3.fromRGB(28, 34, 70),
        SelectorHover   = Color3.fromRGB(38, 46, 92),
        InputBg         = Color3.fromRGB(6, 7, 15),
        Accent          = Color3.fromRGB(165, 180, 252), -- Soft Indigo Ice
        AccentSecondary = Color3.fromRGB(99, 102, 241),
        TextPrimary     = Color3.fromRGB(245, 247, 255),
        TextSecondary   = Color3.fromRGB(160, 168, 205),
        TextMuted       = Color3.fromRGB(102, 110, 145),
        Stroke          = Color3.fromRGB(40, 48, 88),
    },
    ["Arctic Silver Blue"] = {
        Name            = "Arctic Silver (Light Mono)",
        MainBg          = Color3.fromRGB(232, 238, 246),
        PanelBg         = Color3.fromRGB(244, 247, 252),
        GradStart       = Color3.fromRGB(218, 228, 244),
        GradMid         = Color3.fromRGB(238, 243, 250),
        GradEnd         = Color3.fromRGB(226, 234, 246),
        CardBg          = Color3.fromRGB(224, 232, 242),
        CardHover       = Color3.fromRGB(210, 220, 235),
        SelectorBg      = Color3.fromRGB(205, 218, 238),
        SelectorHover   = Color3.fromRGB(186, 204, 232),
        InputBg         = Color3.fromRGB(252, 254, 255),
        Accent          = Color3.fromRGB(15, 38, 74),    -- Deep Navy Ink
        AccentSecondary = Color3.fromRGB(37, 99, 235),
        TextPrimary     = Color3.fromRGB(12, 18, 30),
        TextSecondary   = Color3.fromRGB(68, 82, 105),
        TextMuted       = Color3.fromRGB(115, 128, 150),
        Stroke          = Color3.fromRGB(178, 192, 214),
    }
}

local ThemeOrder = {
    "Premiere Deep Blue",
    "Monochrome Obsidian",
    "Abyssal Indigo",
    "Arctic Silver Blue"
}

local FontPresets = {
    { Name = "Gotham Clean",   Bold = Enum.Font.GothamBold,      Medium = Enum.Font.GothamMedium, Regular = Enum.Font.Gotham },
    { Name = "Builder Modern", Bold = Enum.Font.BuilderSansBold, Medium = Enum.Font.BuilderSansMedium, Regular = Enum.Font.BuilderSans },
    { Name = "Jura Minimal",   Bold = Enum.Font.Jura,            Medium = Enum.Font.Jura,         Regular = Enum.Font.Jura },
    { Name = "Mono Technical", Bold = Enum.Font.RobotoMono,      Medium = Enum.Font.RobotoMono,   Regular = Enum.Font.RobotoMono },
}

local FontSizePresets = {
    { Name = "Small (90%)",   Scale = 0.90, CardHeight = 58, PillHeight = 30, PillMinW = 136 },
    { Name = "Normal (100%)", Scale = 1.00, CardHeight = 64, PillHeight = 34, PillMinW = 152 },
    { Name = "Large (112%)",  Scale = 1.12, CardHeight = 72, PillHeight = 38, PillMinW = 172 },
}

local LogoPresets = {
    { Name = "◈ Dry Crest",    Glyph = "◈" },
    { Name = "❖ Eclipse Mono", Glyph = "❖" },
    { Name = "⬢ Hexa Art",     Glyph = "⬢" },
    { Name = "✦ North Star",   Glyph = "✦" },
}

local MinimizeBtnColors = {
    BgDefault     = Color3.fromRGB(175, 24, 48),  -- Deep Crimson Red
    BgHover       = Color3.fromRGB(225, 40, 68),  -- Interactive Bright Red
    BgPress       = Color3.fromRGB(128, 16, 36),
    StrokeDefault = Color3.fromRGB(235, 110, 130),
    StrokeHover   = Color3.fromRGB(255, 225, 230),
}

-- Ukuran referensi kanvas utama (di-scale secara proporsional dengan UIScale)
local BASE_WIDTH  = 1060
local BASE_HEIGHT = 600

-- // STATE DATA
local State = {
    IsLoading       = true,
    IsMinimized     = false,
    ThemeIndex      = 1,
    FontIndex       = 1,
    FontSizeIndex   = 2,
    LogoIndex       = 1,
    CustomLogoAsset = "",
    LayoutMode      = "Tri-HUD", -- "Tri-HUD" | "Dock Kiri" | "Fokus Tengah" | "Dock Kanan"
    CurrentTab      = "General",
    -- Faktor skala dari layar (0.85 = 85% dari layar aktif; bisa ditarik lewat pojok kanan bawah 0.50 - 1.00)
    UserZoomFactor  = 0.85,
    MotionEnabled   = true,
    Gameplay = {
        FOV          = 80,
        SprintBoost  = true,
        SmoothCam    = true,
        RenderMode   = "Premiere Deep",
        ContrastLvl  = 65,
        MasterVolume = 85,
        PlayerTag    = LocalPlayer.DisplayName,
    }
}

-- // REGISTRY PEMBARUAN TEMA & FONT
local ThemeCallbacks: { (any) -> () } = {}
local FontCallbacks: { (any, any) -> () } = {}
local ShimmerGradients: { UIGradient } = {}

local function getTheme()
    return Themes[ThemeOrder[State.ThemeIndex]]
end

local function getFont()
    return FontPresets[State.FontIndex]
end

local function getFontSize()
    return FontSizePresets[State.FontSizeIndex]
end

local function registerThemeUpdater(fn: (any) -> ())
    table.insert(ThemeCallbacks, fn)
    fn(getTheme())
end

local function registerFontUpdater(fn: (any, any) -> ())
    table.insert(FontCallbacks, fn)
    fn(getFont(), getFontSize())
end

local function broadcastTheme()
    local t = getTheme()
    for _, fn in ipairs(ThemeCallbacks) do
        fn(t)
    end
end

local function broadcastFont()
    local f = getFont()
    local s = getFontSize()
    for _, fn in ipairs(FontCallbacks) do
        fn(f, s)
    end
end

-- // TWEEN PRESETS (Ringan & Responsif)
local TweenFast   = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenSmooth = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TweenSpring = TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TweenClose  = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

-- // HELPER FUNCTIONS
local function create(className: string, properties: { [string]: any }): any
    local inst = Instance.new(className)
    for k, v in pairs(properties) do
        (inst :: any)[k] = v
    end
    return inst
end

local function addCorner(parent: Instance, radius: number): UICorner
    return create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function addStroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
    return create("UIStroke", {
        Color = color,
        Thickness = thickness,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
end

local function addPadding(parent: Instance, top: number, bottom: number, left: number, right: number): UIPadding
    return create("UIPadding", {
        PaddingTop = UDim.new(0, top),
        PaddingBottom = UDim.new(0, bottom),
        PaddingLeft = UDim.new(0, left),
        PaddingRight = UDim.new(0, right),
        Parent = parent
    })
end

local function attachPremiereGradient(parent: GuiObject, rotation: number): UIGradient
    local grad = create("UIGradient", {
        Rotation = rotation,
        Parent = parent
    })
    registerThemeUpdater(function(theme)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, theme.GradStart),
            ColorSequenceKeypoint.new(0.55, theme.GradMid),
            ColorSequenceKeypoint.new(1.0, theme.GradEnd)
        })
    end)
    table.insert(ShimmerGradients, grad)
    return grad
end

-- Fungsi Menyembunyikan/Menampilkan CoreGui Roblox agar tidak menghalangi menu
local function setRobloxCoreGuiHidden(hidden: boolean)
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not hidden)
    end)
end

-- Fungsi Dragging Universal
local function makeDraggable(handle: GuiObject, target: GuiObject, onClick: (() -> ())?)
    local dragging = false
    local dragInput: InputObject? = nil
    local dragStart = Vector3.zero
    local startPos = UDim2.new()
    local movedDist = 0

    handle.InputBegan:Connect(function(input: InputObject)
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

    handle.InputChanged:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input: InputObject)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            movedDist = delta.Magnitude
            target.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ================================================================================
-- 2. SCREEN GUI PRIORITAS MAKSIMUM (MENUTUPI AREA TOPBAR & SEMUA UI LAIN)
-- ================================================================================
local ScreenGui = create("ScreenGui", {
    Name = "DryCursedHubUI",
    DisplayOrder = 2147483647, -- Nilai maksimum 32-bit agar selalu paling depan
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, -- Sibling memastikan semua teks selalu di depan parent-nya
    ResetOnSpawn = false,
    Parent = PlayerGui
})
pcall(function()
    ScreenGui.ScreenInsets = Enum.ScreenInsets.None
end)

local ModalBlur = create("BlurEffect", {
    Name = "DryCursedModalBlur",
    Size = 16,
    Parent = Lighting
})

-- MODAL SHIELD PENAHAN INPUT DI BELAKANG MENU (ZIndex = 10)
local ModalBlocker = create("TextButton", {
    Name = "ModalFocusShield",
    Size = UDim2.fromScale(1, 1),
    Position = UDim2.fromScale(0, 0),
    BackgroundColor3 = Color3.fromRGB(3, 5, 10),
    BackgroundTransparency = 0.22,
    Text = "",
    AutoButtonColor = false,
    Active = true,
    Modal = true,
    Selectable = false,
    ZIndex = 10,
    Parent = ScreenGui
})

-- TOP-LEFT ROBLOX LOGO COVER BAR (Menutupi area pojok kiri atas layar secara elegan)
local TopLeftCrownBar = create("Frame", {
    Name = "TopLeftCornerShield",
    Position = UDim2.fromOffset(10, 8),
    Size = UDim2.fromOffset(210, 40),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ZIndex = 150, -- Selalu di lapisan terdepan pojok kiri atas
    Parent = ScreenGui
})
addCorner(TopLeftCrownBar, 10)
attachPremiereGradient(TopLeftCrownBar, 25)
local crownStroke = addStroke(TopLeftCrownBar, Color3.new(1, 1, 1), 1.2, 0.2)

local CrownIcon = create("TextLabel", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 12, 0.5, 0),
    Size = UDim2.fromOffset(22, 22),
    BackgroundTransparency = 1,
    Text = "◈",
    ZIndex = 2,
    Parent = TopLeftCrownBar
})

local CrownTitle = create("TextLabel", {
    Position = UDim2.new(0, 38, 0, 5),
    Size = UDim2.new(1, -46, 0, 16),
    BackgroundTransparency = 1,
    Text = "Dry Cursed | Hub",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
    Parent = TopLeftCrownBar
})

local CrownSub = create("TextLabel", {
    Position = UDim2.new(0, 38, 0, 21),
    Size = UDim2.new(1, -46, 0, 13),
    BackgroundTransparency = 1,
    Text = "community • active",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
    Parent = TopLeftCrownBar
})

registerThemeUpdater(function(theme)
    crownStroke.Color = theme.Stroke
    CrownIcon.TextColor3 = theme.Accent
    CrownTitle.TextColor3 = theme.TextPrimary
    CrownSub.TextColor3 = theme.TextSecondary
end)

registerFontUpdater(function(font)
    CrownIcon.Font = font.Bold
    CrownIcon.TextSize = 15
    CrownTitle.Font = font.Bold
    CrownTitle.TextSize = 12
    CrownSub.Font = font.Regular
    CrownSub.TextSize = 10
end)

-- ================================================================================
-- 3. FLOATING SHORTCUT ICON (SAAT MENU DI-MINIMIZE, POSISI KIRI ATAS/TENGAH)
-- ================================================================================
local FloatingShortcut = create("TextButton", {
    Name = "FloatingShortcutButton",
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.fromOffset(10, 8), -- Tepat di pojok kiri atas menutupi area TopBar Roblox
    Size = UDim2.fromOffset(210, 44),
    BackgroundColor3 = Color3.new(1, 1, 1),
    Text = "",
    AutoButtonColor = false,
    Visible = false,
    Active = true,
    ZIndex = 200,
    Parent = ScreenGui
})
addCorner(FloatingShortcut, 11)
attachPremiereGradient(FloatingShortcut, 30)
local shortcutStroke = addStroke(FloatingShortcut, Color3.new(1, 1, 1), 1.5, 0.1)

local ShortcutLogoImg = create("ImageLabel", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 12, 0.5, 0),
    Size = UDim2.fromOffset(24, 24),
    BackgroundTransparency = 1,
    Image = "",
    Visible = false,
    ZIndex = 2,
    Parent = FloatingShortcut
})

local ShortcutGlyph = create("TextLabel", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 12, 0.5, 0),
    Size = UDim2.fromOffset(24, 24),
    BackgroundTransparency = 1,
    Text = "◈",
    ZIndex = 2,
    Parent = FloatingShortcut
})

local ShortcutMainTxt = create("TextLabel", {
    Position = UDim2.new(0, 42, 0, 6),
    Size = UDim2.new(1, -54, 0, 17),
    BackgroundTransparency = 1,
    Text = "Dry Cursed | Hub",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
    Parent = FloatingShortcut
})

local ShortcutSubTxt = create("TextLabel", {
    Position = UDim2.new(0, 42, 0, 23),
    Size = UDim2.new(1, -54, 0, 14),
    BackgroundTransparency = 1,
    Text = "community • klik buka",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
    Parent = FloatingShortcut
})

registerThemeUpdater(function(theme)
    shortcutStroke.Color = theme.Accent
    ShortcutGlyph.TextColor3 = theme.Accent
    ShortcutLogoImg.ImageColor3 = theme.Accent
    ShortcutMainTxt.TextColor3 = theme.TextPrimary
    ShortcutSubTxt.TextColor3 = theme.Accent
end)

registerFontUpdater(function(font)
    ShortcutGlyph.Font = font.Bold
    ShortcutGlyph.TextSize = 17
    ShortcutMainTxt.Font = font.Bold
    ShortcutMainTxt.TextSize = 13
    ShortcutSubTxt.Font = font.Regular
    ShortcutSubTxt.TextSize = 10
end)

-- ================================================================================
-- 4. STARTUP ILLUSTRATION SCREEN (MONOCHROME ECLIPSE ART SAAT PERTAMA DIMULAI)
-- ================================================================================
local StartupOverlay = create("Frame", {
    Name = "StartupIllustrationScreen",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ClipsDescendants = true,
    Active = true,
    ZIndex = 300,
    Parent = ScreenGui
})
addCorner(StartupOverlay, 16)
attachPremiereGradient(StartupOverlay, 135)
local startupStroke = addStroke(StartupOverlay, Color3.new(1, 1, 1), 1.5, 0.15)

local StartupUIScale = create("UIScale", {
    Scale = 1,
    Parent = StartupOverlay
})

-- Ilustrasi Monochrome Eclipse & Architectural Fine-Line Geometry di Tengah
local EclipseCanvas = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.42, 0),
    Size = UDim2.fromOffset(220, 220),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Parent = StartupOverlay
})

-- Garis Sumbu Tipis (Fine Architectural Crosshair)
local CrossH = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(320, 1),
    BackgroundTransparency = 0.72,
    BorderSizePixel = 0,
    Parent = EclipseCanvas
})
local CrossV = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(1, 260),
    BackgroundTransparency = 0.72,
    BorderSizePixel = 0,
    Parent = EclipseCanvas
})

-- Cincin Geometri Luar Tipis
local OuterMonoRing = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(190, 190),
    BackgroundTransparency = 1,
    Parent = EclipseCanvas
})
addCorner(OuterMonoRing, 999)
local outerMonoStroke = addStroke(OuterMonoRing, Color3.new(1, 1, 1), 1.2, 0.45)

-- Bingkai Persegi Miring Tipis (Monochrome Architectural Square)
local ArchSquare = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(134, 134),
    BackgroundTransparency = 1,
    Rotation = 45,
    Parent = EclipseCanvas
})
addCorner(ArchSquare, 8)
local archSquareStroke = addStroke(ArchSquare, Color3.new(1, 1, 1), 1.2, 0.35)

-- Lingkaran Gerhana Utama (Deep Blue Premiere Eclipse Sphere)
local EclipseSphere = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(96, 96),
    BackgroundColor3 = Color3.new(1, 1, 1),
    Parent = EclipseCanvas
})
addCorner(EclipseSphere, 999)
attachPremiereGradient(EclipseSphere, 45)
local eclipseStroke = addStroke(EclipseSphere, Color3.new(1, 1, 1), 1.8, 0.1)

local EclipseCenterGlyph = create("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "◈",
    ZIndex = 3,
    Parent = EclipseSphere
})

-- Judul Brand pada Layar Loading
local IntroBrandTitle = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.68, 0),
    Size = UDim2.fromOffset(420, 28),
    BackgroundTransparency = 1,
    Text = "Dry Cursed | Hub",
    ZIndex = 3,
    Parent = StartupOverlay
})

local IntroBrandSub = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.73, 0),
    Size = UDim2.fromOffset(420, 18),
    BackgroundTransparency = 1,
    Text = "community • monochrome premiere interface",
    ZIndex = 3,
    Parent = StartupOverlay
})

-- Progress Bar Minimalis
local IntroBarBg = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.81, 0),
    Size = UDim2.fromOffset(360, 4),
    BorderSizePixel = 0,
    ZIndex = 3,
    Parent = StartupOverlay
})
addCorner(IntroBarBg, 99)

local IntroBarFill = create("Frame", {
    Size = UDim2.fromScale(0, 1),
    BorderSizePixel = 0,
    ZIndex = 4,
    Parent = IntroBarBg
})
addCorner(IntroBarFill, 99)

local IntroStatusText = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.84, 0),
    Size = UDim2.fromOffset(360, 18),
    BackgroundTransparency = 1,
    Text = "Preparing workspace... 0%",
    ZIndex = 3,
    Parent = StartupOverlay
})

local SkipIntroBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -24, 1, -20),
    Size = UDim2.fromOffset(110, 32),
    Text = "Skip Intro ▸",
    AutoButtonColor = false,
    ZIndex = 5,
    Parent = StartupOverlay
})
addCorner(SkipIntroBtn, 8)
local skipBtnStroke = addStroke(SkipIntroBtn, Color3.new(1, 1, 1), 1, 0.25)

registerThemeUpdater(function(theme)
    startupStroke.Color = theme.Stroke
    CrossH.BackgroundColor3 = theme.Stroke
    CrossV.BackgroundColor3 = theme.Stroke
    outerMonoStroke.Color = theme.Accent
    archSquareStroke.Color = theme.AccentSecondary
    eclipseStroke.Color = theme.Accent
    EclipseCenterGlyph.TextColor3 = theme.TextPrimary
    IntroBrandTitle.TextColor3 = theme.TextPrimary
    IntroBrandSub.TextColor3 = theme.TextSecondary
    IntroBarBg.BackgroundColor3 = theme.InputBg
    IntroBarFill.BackgroundColor3 = theme.Accent
    IntroStatusText.TextColor3 = theme.TextMuted
    SkipIntroBtn.BackgroundColor3 = theme.SelectorBg
    SkipIntroBtn.TextColor3 = theme.TextPrimary
    skipBtnStroke.Color = theme.Stroke
end)

registerFontUpdater(function(font)
    EclipseCenterGlyph.Font = font.Bold
    EclipseCenterGlyph.TextSize = 32
    IntroBrandTitle.Font = font.Bold
    IntroBrandTitle.TextSize = 22
    IntroBrandSub.Font = font.Regular
    IntroBrandSub.TextSize = 13
    IntroStatusText.Font = font.Medium
    IntroStatusText.TextSize = 11
    SkipIntroBtn.Font = font.Medium
    SkipIntroBtn.TextSize = 12
end)

-- ================================================================================
-- 5. CONTAINER UTAMA PROPORSIONAL (UISCALE MENJAGA TEKS & TOMBOL IKUT MENGECIL)
-- ================================================================================
local HUDCanvas = create("Frame", {
    Name = "HUDCanvasProportional",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.52),
    Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT), -- Kanvas referensi tetap agar TIDAK PERNAH CROP
    BackgroundTransparency = 1,
    Visible = false,
    Active = true,
    ZIndex = 50,
    Parent = ScreenGui
})

-- UIScale Utama yang mengecilkan/membesarkan SELURUH teks, kartu, dan tombol secara proporsional
local ProportionalUIScale = create("UIScale", {
    Scale = 1,
    Parent = HUDCanvas
})

local ResizeHintLabel: TextLabel? = nil
local HeaderScaleBadge: TextLabel? = nil

local function computeAndApplyProportionalScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    -- Skala dasar agar BASE_WIDTH x BASE_HEIGHT tepat memenuhi UserZoomFactor (default 85%) dari layar
    local fitScaleX = (vp.X * State.UserZoomFactor) / BASE_WIDTH
    local fitScaleY = (vp.Y * State.UserZoomFactor) / BASE_HEIGHT
    local finalScale = math.clamp(math.min(fitScaleX, fitScaleY), 0.38, 1.45)

    ProportionalUIScale.Scale = finalScale
    StartupUIScale.Scale = finalScale

    local pct = math.round(State.UserZoomFactor * 100)
    if ResizeHintLabel then
        ResizeHintLabel.Text = string.format("⇲ Scale %d%%", pct)
    end
    if HeaderScaleBadge then
        HeaderScaleBadge.Text = string.format("%d%% View", pct)
    end
end

if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(computeAndApplyProportionalScale)
end
computeAndApplyProportionalScale()

-- ================================================================================
-- 6. TOP BAR MENU (KIRI ATAS: LOGO + "Dry Cursed | Hub" + "community")
-- ================================================================================
local TopBar = create("Frame", {
    Name = "TopBar",
    Size = UDim2.fromOffset(BASE_WIDTH, 62),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    Active = true,
    ZIndex = 2,
    Parent = HUDCanvas
})
addCorner(TopBar, 14)
attachPremiereGradient(TopBar, 18)
local topBarStroke = addStroke(TopBar, Color3.new(1, 1, 1), 1.2, 0.15)

-- KIRI ATAS: POD LOGO + JUDUL "Dry Cursed | Hub" & SUB-JUDUL "community"
local BrandLogoPod = create("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 16, 0.5, 0),
    Size = UDim2.fromOffset(40, 40),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ZIndex = 3,
    Parent = TopBar
})
addCorner(BrandLogoPod, 10)
attachPremiereGradient(BrandLogoPod, 135)
local brandPodStroke = addStroke(BrandLogoPod, Color3.new(1, 1, 1), 1.2, 0.2)

local HeaderLogoGlyph = create("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "◈",
    ZIndex = 4,
    Parent = BrandLogoPod
})

local HeaderLogoImage = create("ImageLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(26, 26),
    BackgroundTransparency = 1,
    Image = "",
    Visible = false,
    ZIndex = 4,
    Parent = BrandLogoPod
})

local MainBrandTitle = create("TextLabel", {
    Position = UDim2.fromOffset(68, 11),
    Size = UDim2.fromOffset(220, 22),
    BackgroundTransparency = 1,
    Text = "Dry Cursed | Hub",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
    Parent = TopBar
})

local SubBrandCommunity = create("TextLabel", {
    Position = UDim2.fromOffset(68, 33),
    Size = UDim2.fromOffset(220, 16),
    BackgroundTransparency = 1,
    Text = "community",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
    Parent = TopBar
})

-- TENGAH TOPBAR: PEMILIH POSISI LAYOUT (Tri-HUD | Dock Kiri | Fokus Tengah | Dock Kanan)
local DockSwitchContainer = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.49, 0, 0.5, 0),
    Size = UDim2.fromOffset(348, 36),
    ZIndex = 3,
    Parent = TopBar
})
addCorner(DockSwitchContainer, 9)
local dockContainerStroke = addStroke(DockSwitchContainer, Color3.new(1, 1, 1), 1, 0.3)

-- KANAN TENGAH: KOTAK PENCARIAN KARTU
local SearchBoxFrame = create("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -138, 0.5, 0),
    Size = UDim2.fromOffset(180, 36),
    ZIndex = 3,
    Parent = TopBar
})
addCorner(SearchBoxFrame, 9)
local searchBoxStroke = addStroke(SearchBoxFrame, Color3.new(1, 1, 1), 1, 0.3)

local SearchInput = create("TextBox", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, -20, 1, -6),
    BackgroundTransparency = 1,
    Text = "",
    PlaceholderText = "⌕ Cari fitur...",
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    ZIndex = 4,
    Parent = SearchBoxFrame
})

-- KANAN ATAS: TOMBOL MINIMIZE MERAH INTERAKTIF (DENGAN HOVER)
local MinimizeRedBtn = create("TextButton", {
    Name = "MinimizeRedButton",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -16, 0.5, 0),
    Size = UDim2.fromOffset(110, 36),
    BackgroundColor3 = MinimizeBtnColors.BgDefault,
    Text = "— Minimize",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    AutoButtonColor = false,
    ZIndex = 4,
    Parent = TopBar
})
addCorner(MinimizeRedBtn, 9)
local minRedStroke = addStroke(MinimizeRedBtn, MinimizeBtnColors.StrokeDefault, 1.2, 0.15)

MinimizeRedBtn.MouseEnter:Connect(function()
    TweenService:Create(MinimizeRedBtn, TweenFast, {
        BackgroundColor3 = MinimizeBtnColors.BgHover,
        Size = UDim2.fromOffset(114, 38),
        Text = "▼ Hide Menu"
    }):Play()
    TweenService:Create(minRedStroke, TweenFast, {
        Color = MinimizeBtnColors.StrokeHover,
        Thickness = 1.8,
        Transparency = 0
    }):Play()
end)

MinimizeRedBtn.MouseLeave:Connect(function()
    TweenService:Create(MinimizeRedBtn, TweenFast, {
        BackgroundColor3 = MinimizeBtnColors.BgDefault,
        Size = UDim2.fromOffset(110, 36),
        Text = "— Minimize"
    }):Play()
    TweenService:Create(minRedStroke, TweenFast, {
        Color = MinimizeBtnColors.StrokeDefault,
        Thickness = 1.2,
        Transparency = 0.15
    }):Play()
end)

MinimizeRedBtn.MouseButton1Down:Connect(function()
    TweenService:Create(MinimizeRedBtn, TweenInfo.new(0.08), {
        BackgroundColor3 = MinimizeBtnColors.BgPress,
        Size = UDim2.fromOffset(106, 34)
    }):Play()
end)

registerThemeUpdater(function(theme)
    topBarStroke.Color = theme.Stroke
    brandPodStroke.Color = theme.Accent
    HeaderLogoGlyph.TextColor3 = theme.Accent
    HeaderLogoImage.ImageColor3 = theme.Accent
    MainBrandTitle.TextColor3 = theme.TextPrimary
    SubBrandCommunity.TextColor3 = theme.Accent
    DockSwitchContainer.BackgroundColor3 = theme.InputBg
    dockContainerStroke.Color = theme.Stroke
    SearchBoxFrame.BackgroundColor3 = theme.InputBg
    searchBoxStroke.Color = theme.Stroke
    SearchInput.TextColor3 = theme.TextPrimary
    SearchInput.PlaceholderColor3 = theme.TextMuted
end)

registerFontUpdater(function(font, fSize)
    HeaderLogoGlyph.Font = font.Bold
    HeaderLogoGlyph.TextSize = math.round(19 * fSize.Scale)
    MainBrandTitle.Font = font.Bold
    MainBrandTitle.TextSize = math.round(16 * fSize.Scale)
    SubBrandCommunity.Font = font.Medium
    SubBrandCommunity.TextSize = math.round(12 * fSize.Scale)
    SearchInput.Font = font.Regular
    SearchInput.TextSize = math.round(12 * fSize.Scale)
    MinimizeRedBtn.Font = font.Bold
    MinimizeRedBtn.TextSize = math.round(12 * fSize.Scale)
end)

local function updateLogoVisuals()
    local preset = LogoPresets[State.LogoIndex]
    if State.CustomLogoAsset ~= "" then
        HeaderLogoGlyph.Visible = false
        ShortcutGlyph.Visible = false
        HeaderLogoImage.Visible = true
        ShortcutLogoImg.Visible = true
        HeaderLogoImage.Image = State.CustomLogoAsset
        ShortcutLogoImg.Image = State.CustomLogoAsset
    else
        HeaderLogoImage.Visible = false
        ShortcutLogoImg.Visible = false
        HeaderLogoGlyph.Visible = true
        ShortcutGlyph.Visible = true
        HeaderLogoGlyph.Text = preset.Glyph
        ShortcutGlyph.Text = preset.Glyph
        CrownIcon.Text = preset.Glyph
        EclipseCenterGlyph.Text = preset.Glyph
    end
end

-- ================================================================================
-- 7. BODY WORKSPACE (3 ZONA RESPONSIF DALAM KANVAS 1060 x 526)
-- ================================================================================
local BodyArea = create("Frame", {
    Name = "BodyArea",
    Position = UDim2.fromOffset(0, 72),
    Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT - 72),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Parent = HUDCanvas
})

-- [PANEL KIRI: SIDE MENU NAVIGATION]
local SideMenuPanel = create("Frame", {
    Name = "SideMenuPanel",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromOffset(220, BASE_HEIGHT - 72),
    BackgroundColor3 = Color3.new(1, 1, 1),
    Active = true,
    ZIndex = 2,
    Parent = BodyArea
})
addCorner(SideMenuPanel, 14)
attachPremiereGradient(SideMenuPanel, 140)
local sideStroke = addStroke(SideMenuPanel, Color3.new(1, 1, 1), 1.2, 0.15)

local SideSectionTitle = create("TextLabel", {
    Position = UDim2.fromOffset(18, 16),
    Size = UDim2.fromOffset(184, 16),
    BackgroundTransparency = 1,
    Text = "CATEGORIES",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
    Parent = SideMenuPanel
})

local SideTabList = create("Frame", {
    Position = UDim2.fromOffset(12, 40),
    Size = UDim2.fromOffset(196, BASE_HEIGHT - 196),
    BackgroundTransparency = 1,
    ZIndex = 3,
    Parent = SideMenuPanel
})

create("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = SideTabList
})

-- Kartu Profil di Bawah SideMenu
local UserFooterCard = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -12),
    Size = UDim2.new(1, -24, 0, 62),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ZIndex = 3,
    Parent = SideMenuPanel
})
addCorner(UserFooterCard, 10)
attachPremiereGradient(UserFooterCard, 35)
local footerStroke = addStroke(UserFooterCard, Color3.new(1, 1, 1), 1, 0.25)

local FooterUserText = create("TextLabel", {
    Position = UDim2.fromOffset(12, 10),
    Size = UDim2.new(1, -24, 0, 20),
    BackgroundTransparency = 1,
    Text = "@" .. LocalPlayer.Name,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 4,
    Parent = UserFooterCard
})

local FooterShortcutText = create("TextLabel", {
    Position = UDim2.fromOffset(12, 32),
    Size = UDim2.new(1, -24, 0, 18),
    BackgroundTransparency = 1,
    Text = "Toggle: [RightCtrl]",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
    Parent = UserFooterCard
})

-- [PANEL TENGAH: MAIN INPUT CARDS MATRIX]
local CenterContentPanel = create("Frame", {
    Name = "CenterContentPanel",
    Position = UDim2.fromOffset(232, 0),
    Size = UDim2.fromOffset(536, BASE_HEIGHT - 72),
    BackgroundColor3 = Color3.new(1, 1, 1),
    Active = true,
    ZIndex = 2,
    Parent = BodyArea
})
addCorner(CenterContentPanel, 14)
attachPremiereGradient(CenterContentPanel, 155)
local centerStroke = addStroke(CenterContentPanel, Color3.new(1, 1, 1), 1.2, 0.15)

local CenterCategoryHeader = create("TextLabel", {
    Position = UDim2.fromOffset(22, 16),
    Size = UDim2.new(0.58, 0, 0, 22),
    BackgroundTransparency = 1,
    Text = "General & Character",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
    Parent = CenterContentPanel
})

local StatusFeedbackLabel = create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -22, 0, 18),
    Size = UDim2.new(0.38, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = "● Ready",
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 3,
    Parent = CenterContentPanel
})

local function showStatus(msg: string)
    StatusFeedbackLabel.Text = "◈ " .. msg
end

local PagesHolder = create("Frame", {
    Position = UDim2.fromOffset(0, 48),
    Size = UDim2.new(1, 0, 1, -54),
    BackgroundTransparency = 1,
    ZIndex = 3,
    Parent = CenterContentPanel
})

-- [PANEL KANAN: THEME, FONT & APPEARANCE STUDIO]
local RightStudioPanel = create("Frame", {
    Name = "RightStudioPanel",
    Position = UDim2.fromOffset(780, 0),
    Size = UDim2.fromOffset(280, BASE_HEIGHT - 72),
    BackgroundColor3 = Color3.new(1, 1, 1),
    Active = true,
    ZIndex = 2,
    Parent = BodyArea
})
addCorner(RightStudioPanel, 14)
attachPremiereGradient(RightStudioPanel, 165)
local rightStroke = addStroke(RightStudioPanel, Color3.new(1, 1, 1), 1.2, 0.15)

local RightStudioTitle = create("TextLabel", {
    Position = UDim2.fromOffset(18, 16),
    Size = UDim2.new(0.65, 0, 0, 22),
    BackgroundTransparency = 1,
    Text = "Appearance Studio",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
    Parent = RightStudioPanel
})

HeaderScaleBadge = create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -18, 0, 18),
    Size = UDim2.fromOffset(76, 18),
    BackgroundTransparency = 1,
    Text = "85% View",
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 3,
    Parent = RightStudioPanel
})

local RightStudioScroll = create("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 48),
    Size = UDim2.new(1, 0, 1, -96), -- Ruang bersih di bawah agar tidak bertabrakan dengan Grip Pojok Kanan Bawah
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 3,
    Parent = RightStudioPanel
})
addPadding(RightStudioScroll, 4, 16, 14, 14)

create("UIListLayout", {
    Padding = UDim.new(0, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = RightStudioScroll
})

registerThemeUpdater(function(theme)
    sideStroke.Color = theme.Stroke
    SideSectionTitle.TextColor3 = theme.TextMuted
    footerStroke.Color = theme.Stroke
    FooterUserText.TextColor3 = theme.TextPrimary
    FooterShortcutText.TextColor3 = theme.Accent

    centerStroke.Color = theme.Stroke
    CenterCategoryHeader.TextColor3 = theme.TextPrimary
    StatusFeedbackLabel.TextColor3 = theme.Accent

    rightStroke.Color = theme.Stroke
    RightStudioTitle.TextColor3 = theme.TextPrimary
    if HeaderScaleBadge then
        HeaderScaleBadge.TextColor3 = theme.Accent
    end
    RightStudioScroll.ScrollBarImageColor3 = theme.Accent
end)

registerFontUpdater(function(font, fSize)
    SideSectionTitle.Font = font.Bold
    SideSectionTitle.TextSize = math.round(10 * fSize.Scale)
    FooterUserText.Font = font.Bold
    FooterUserText.TextSize = math.round(12 * fSize.Scale)
    FooterShortcutText.Font = font.Regular
    FooterShortcutText.TextSize = math.round(11 * fSize.Scale)
    CenterCategoryHeader.Font = font.Bold
    CenterCategoryHeader.TextSize = math.round(15 * fSize.Scale)
    StatusFeedbackLabel.Font = font.Medium
    StatusFeedbackLabel.TextSize = math.round(11 * fSize.Scale)
    RightStudioTitle.Font = font.Bold
    RightStudioTitle.TextSize = math.round(14 * fSize.Scale)
    if HeaderScaleBadge then
        HeaderScaleBadge.Font = font.Bold
        HeaderScaleBadge.TextSize = math.round(11 * fSize.Scale)
    end
end)

-- ================================================================================
-- 8. POJOK KANAN BAWAH: SHAPE RESIZE PROPORSIONAL (TEKS & BUTTON IKUT MENGECIL)
-- ================================================================================
local ResizeGripPod = create("TextButton", {
    Name = "BottomRightResizeHandle",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -8, 1, -8),
    Size = UDim2.fromOffset(148, 34),
    BackgroundColor3 = Color3.new(1, 1, 1),
    Text = "",
    AutoButtonColor = false,
    Active = true,
    ZIndex = 20,
    Parent = HUDCanvas
})
addCorner(ResizeGripPod, 9)
attachPremiereGradient(ResizeGripPod, 35)
local resizeGripStroke = addStroke(ResizeGripPod, Color3.new(1, 1, 1), 1.4, 0.1)

ResizeHintLabel = create("TextLabel", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 12, 0.5, 0),
    Size = UDim2.new(1, -42, 1, 0),
    BackgroundTransparency = 1,
    Text = "⇲ Scale 85%",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
    Parent = ResizeGripPod
})

-- Shape Sudut Siku & 3 Garis Diagonal di Pojok Kanan Bawah
local GripArtFrame = create("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -6, 1, -6),
    Size = UDim2.fromOffset(22, 22),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Parent = ResizeGripPod
})

local CornerLineH = create("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.fromScale(1, 1),
    Size = UDim2.fromOffset(16, 2),
    BorderSizePixel = 0,
    Parent = GripArtFrame
})
local CornerLineV = create("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.fromScale(1, 1),
    Size = UDim2.fromOffset(2, 16),
    BorderSizePixel = 0,
    Parent = GripArtFrame
})
local DiagBar1 = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(1, -5, 1, -5),
    Size = UDim2.fromOffset(7, 2),
    Rotation = -45,
    BorderSizePixel = 0,
    Parent = GripArtFrame
})
local DiagBar2 = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(1, -10, 1, -10),
    Size = UDim2.fromOffset(13, 2),
    Rotation = -45,
    BorderSizePixel = 0,
    Parent = GripArtFrame
})
local DiagBar3 = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(1, -15, 1, -15),
    Size = UDim2.fromOffset(18, 2),
    Rotation = -45,
    BorderSizePixel = 0,
    Parent = GripArtFrame
})

registerThemeUpdater(function(theme)
    resizeGripStroke.Color = theme.Accent
    if ResizeHintLabel then
        ResizeHintLabel.TextColor3 = theme.TextPrimary
    end
    CornerLineH.BackgroundColor3 = theme.Accent
    CornerLineV.BackgroundColor3 = theme.Accent
    DiagBar1.BackgroundColor3 = theme.TextPrimary
    DiagBar2.BackgroundColor3 = theme.Accent
    DiagBar3.BackgroundColor3 = theme.AccentSecondary
end)

registerFontUpdater(function(font, fSize)
    if ResizeHintLabel then
        ResizeHintLabel.Font = font.Bold
        ResizeHintLabel.TextSize = math.round(11 * fSize.Scale)
    end
end)

ResizeGripPod.MouseEnter:Connect(function()
    TweenService:Create(ResizeGripPod, TweenFast, { Size = UDim2.fromOffset(160, 36) }):Play()
    if ResizeHintLabel then
        ResizeHintLabel.Text = "⇲ Tarik Ukuran"
    end
end)

ResizeGripPod.MouseLeave:Connect(function()
    TweenService:Create(ResizeGripPod, TweenFast, { Size = UDim2.fromOffset(148, 34) }):Play()
    if ResizeHintLabel then
        ResizeHintLabel.Text = string.format("⇲ Scale %d%%", math.round(State.UserZoomFactor * 100))
    end
end)

-- Logika Tarik Pojok Kanan Bawah -> Mengubah UIScale Secara Proporsional (Bukan Crop!)
do
    local isResizing = false
    local startMouse = Vector3.zero
    local startZoom = State.UserZoomFactor
    local lastClick = 0

    ResizeGripPod.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local now = tick()
            if (now - lastClick) < 0.32 then
                State.UserZoomFactor = 0.85
                computeAndApplyProportionalScale()
                showStatus("Reset Scale ke 85%")
                return
            end
            lastClick = now
            isResizing = true
            startMouse = input.Position
            startZoom = State.UserZoomFactor
        end
    end)

    UserInputService.InputChanged:Connect(function(input: InputObject)
        if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local cam = workspace.CurrentCamera
            if not cam then return end
            local vp = cam.ViewportSize
            local delta = input.Position - startMouse
            local deltaRatio = ((delta.X / math.max(vp.X, 1)) + (delta.Y / math.max(vp.Y, 1))) * 0.85
            State.UserZoomFactor = math.clamp(startZoom + deltaRatio, 0.50, 0.96)
            computeAndApplyProportionalScale()
        end
    end)

    UserInputService.InputEnded:Connect(function(input: InputObject)
        if isResizing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isResizing = false
            showStatus(string.format("Proportional Scale: %d%%", math.round(State.UserZoomFactor * 100)))
        end
    end)
end

-- ================================================================================
-- 9. SISTEM PERPINDAHAN POSISI MENU (TRI-HUD / DOCK KIRI / TENGAH / KANAN)
-- ================================================================================
local DockModeButtons: { [string]: TextButton } = {}
local H_BODY = BASE_HEIGHT - 72

local function applyLayoutMode(mode: string)
    State.LayoutMode = mode
    local theme = getTheme()
    for mName, btn in pairs(DockModeButtons) do
        local active = (mName == mode)
        TweenService:Create(btn, TweenFast, {
            BackgroundColor3 = active and theme.Accent or theme.SelectorBg,
            TextColor3 = active and theme.MainBg or theme.TextPrimary
        }):Play()
    end

    if mode == "Tri-HUD" then
        SideMenuPanel.Visible = true
        RightStudioPanel.Visible = true
        TweenService:Create(SideMenuPanel, TweenSmooth, {
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromOffset(220, H_BODY)
        }):Play()
        TweenService:Create(CenterContentPanel, TweenSmooth, {
            Position = UDim2.fromOffset(232, 0),
            Size = UDim2.fromOffset(536, H_BODY)
        }):Play()
        TweenService:Create(RightStudioPanel, TweenSmooth, {
            Position = UDim2.fromOffset(780, 0),
            Size = UDim2.fromOffset(280, H_BODY)
        }):Play()
    elseif mode == "Dock Kiri" then
        SideMenuPanel.Visible = true
        RightStudioPanel.Visible = false
        TweenService:Create(SideMenuPanel, TweenSmooth, {
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromOffset(240, H_BODY)
        }):Play()
        TweenService:Create(CenterContentPanel, TweenSmooth, {
            Position = UDim2.fromOffset(252, 0),
            Size = UDim2.fromOffset(808, H_BODY)
        }):Play()
    elseif mode == "Fokus Tengah" then
        SideMenuPanel.Visible = true
        RightStudioPanel.Visible = true
        TweenService:Create(RightStudioPanel, TweenSmooth, {
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromOffset(270, H_BODY)
        }):Play()
        TweenService:Create(CenterContentPanel, TweenSmooth, {
            Position = UDim2.fromOffset(282, 0),
            Size = UDim2.fromOffset(546, H_BODY)
        }):Play()
        TweenService:Create(SideMenuPanel, TweenSmooth, {
            Position = UDim2.fromOffset(840, 0),
            Size = UDim2.fromOffset(220, H_BODY)
        }):Play()
    elseif mode == "Dock Kanan" then
        SideMenuPanel.Visible = true
        RightStudioPanel.Visible = false
        TweenService:Create(CenterContentPanel, TweenSmooth, {
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromOffset(808, H_BODY)
        }):Play()
        TweenService:Create(SideMenuPanel, TweenSmooth, {
            Position = UDim2.fromOffset(820, 0),
            Size = UDim2.fromOffset(240, H_BODY)
        }):Play()
    end
    showStatus("Layout: " .. mode)
end

local dockModes = { "Tri-HUD", "Dock Kiri", "Fokus Tengah", "Dock Kanan" }
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 5),
    Parent = DockSwitchContainer
})

for i, mName in ipairs(dockModes) do
    local dBtn = create("TextButton", {
        LayoutOrder = i,
        Size = UDim2.fromOffset(80, 28),
        Text = mName,
        AutoButtonColor = false,
        ZIndex = 4,
        Parent = DockSwitchContainer
    })
    addCorner(dBtn, 6)
    DockModeButtons[mName] = dBtn

    dBtn.MouseButton1Click:Connect(function()
        applyLayoutMode(mName)
    end)

    registerThemeUpdater(function(theme)
        local active = (State.LayoutMode == mName)
        dBtn.BackgroundColor3 = active and theme.Accent or theme.SelectorBg
        dBtn.TextColor3 = active and theme.MainBg or theme.TextPrimary
    end)

    registerFontUpdater(function(font, fSize)
        dBtn.Font = font.Bold
        dBtn.TextSize = math.clamp(math.round(11 * fSize.Scale), 9, 13)
    end)
end

-- ================================================================================
-- 10. KOMPONEN TAB & INPUT CARDS (SEMUA TEKS TERLIHAT JELAS & RESPONSIF)
-- ================================================================================
local Tabs: { [string]: { Button: TextButton, Indicator: Frame, Page: ScrollingFrame, Title: string, CardScales: { UIScale } } } = {}
local SearchableCards: { { Frame: Frame, Keywords: string, TabId: string } } = {}

local function animateTabCards(tabId: string)
    local data = Tabs[tabId]
    if not data or not State.MotionEnabled then return end
    for idx, cs in ipairs(data.CardScales) do
        cs.Scale = 0.94
        task.delay((idx - 1) * 0.025, function()
            TweenService:Create(cs, TweenSmooth, { Scale = 1 }):Play()
        end)
    end
end

local function selectTab(tabId: string)
    State.CurrentTab = tabId
    local theme = getTheme()
    for id, data in pairs(Tabs) do
        local isCurrent = (id == tabId)
        data.Page.Visible = isCurrent
        if isCurrent then
            CenterCategoryHeader.Text = data.Title
            TweenService:Create(data.Button, TweenFast, {
                BackgroundColor3 = theme.SelectorBg,
                TextColor3 = theme.TextPrimary
            }):Play()
            TweenService:Create(data.Indicator, TweenFast, {
                Size = UDim2.new(0, 3, 0.6, 0),
                BackgroundTransparency = 0
            }):Play()
            animateTabCards(id)
        else
            TweenService:Create(data.Button, TweenFast, {
                BackgroundColor3 = theme.CardBg,
                TextColor3 = theme.TextSecondary
            }):Play()
            TweenService:Create(data.Indicator, TweenFast, {
                Size = UDim2.new(0, 3, 0, 0),
                BackgroundTransparency = 1
            }):Play()
        end
    end
end

local function createSideTab(tabId: string, icon: string, label: string, headerTitle: string, order: number): ScrollingFrame
    local btn = create("TextButton", {
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 40),
        Text = "     " .. icon .. "   " .. label,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        ZIndex = 4,
        Parent = SideTabList
    })
    addCorner(btn, 9)
    local tabStroke = addStroke(btn, Color3.new(1, 1, 1), 1, 0.35)

    local ind = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 5, 0.5, 0),
        Size = UDim2.new(0, 3, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 5,
        Parent = btn
    })
    addCorner(ind, 99)

    local page = create("ScrollingFrame", {
        Name = tabId .. "Page",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        ZIndex = 4,
        Parent = PagesHolder
    })
    addPadding(page, 4, 24, 18, 18)

    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page
    })

    btn.MouseButton1Click:Connect(function()
        SearchInput.Text = ""
        selectTab(tabId)
    end)

    registerThemeUpdater(function(theme)
        local isCurrent = (State.CurrentTab == tabId)
        btn.BackgroundColor3 = isCurrent and theme.SelectorBg or theme.CardBg
        btn.TextColor3 = isCurrent and theme.TextPrimary or theme.TextSecondary
        tabStroke.Color = isCurrent and theme.Accent or theme.Stroke
        ind.BackgroundColor3 = theme.Accent
        page.ScrollBarImageColor3 = theme.Accent
    end)

    registerFontUpdater(function(font, fSize)
        btn.Font = font.Bold
        btn.TextSize = math.round(13 * fSize.Scale)
        btn.Size = UDim2.new(1, 0, 0, math.round(38 * fSize.Scale))
    end)

    Tabs[tabId] = { Button = btn, Indicator = ind, Page = page, Title = headerTitle, CardScales = {} }
    return page
end

-- Kerangka Kartu Input (Mendukung Kartu Lebar di Tengah & Kartu Kompak di Studio Kanan)
local function createCardShell(parent: ScrollingFrame, tabId: string, title: string, desc: string, isCompact: boolean, extraH: number, order: number): Frame
    local baseH = isCompact and 82 or 64
    local card = create("Frame", {
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, baseH + extraH),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 4,
        Parent = parent
    })
    addCorner(card, 10)
    local cStroke = addStroke(card, Color3.new(1, 1, 1), 1, 0.22)

    local cardGrad = create("UIGradient", {
        Rotation = 25,
        Parent = card
    })

    local cScale = create("UIScale", {
        Scale = 1,
        Parent = card
    })
    if tabId ~= "" and Tabs[tabId] then
        table.insert(Tabs[tabId].CardScales, cScale)
    end

    local titleLbl = create("TextLabel", {
        Position = UDim2.fromOffset(14, 9),
        Size = isCompact and UDim2.new(1, -28, 0, 18) or UDim2.new(0.55, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = title,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5,
        Parent = card
    })

    local descLbl = create("TextLabel", {
        Position = UDim2.fromOffset(14, 29),
        Size = isCompact and UDim2.new(1, -28, 0, 15) or UDim2.new(0.55, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = desc,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = not isCompact,
        ZIndex = 5,
        Parent = card
    })

    card.MouseEnter:Connect(function()
        local theme = getTheme()
        TweenService:Create(cStroke, TweenFast, { Color = theme.Accent, Transparency = 0 }):Play()
    end)
    card.MouseLeave:Connect(function()
        local theme = getTheme()
        TweenService:Create(cStroke, TweenFast, { Color = theme.Stroke, Transparency = 0.22 }):Play()
    end)

    registerThemeUpdater(function(theme)
        cardGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, theme.CardBg),
            ColorSequenceKeypoint.new(0.65, theme.PanelBg),
            ColorSequenceKeypoint.new(1.0, theme.GradStart)
        })
        cStroke.Color = theme.Stroke
        titleLbl.TextColor3 = theme.TextPrimary
        descLbl.TextColor3 = theme.TextSecondary
    end)

    registerFontUpdater(function(font, fSize)
        titleLbl.Font = font.Bold
        titleLbl.TextSize = math.round((isCompact and 12 or 13) * fSize.Scale)
        descLbl.Font = font.Regular
        descLbl.TextSize = math.round(11 * fSize.Scale)
        local targetH = (isCompact and math.round(74 * fSize.Scale) or fSize.CardHeight) + extraH
        card.Size = UDim2.new(1, 0, 0, targetH)
    end)

    if tabId ~= "" then
        table.insert(SearchableCards, {
            Frame = card,
            Keywords = string.lower(title .. " " .. desc),
            TabId = tabId
        })
    end

    return card
end

-- 1. SELECTOR CARD (BG Pilihan menyesuaikan Ukuran Font & semua teks terlihat utuh)
local function addSelectorCard(parent: ScrollingFrame, tabId: string, title: string, desc: string, isCompact: boolean, options: { string }, defaultIdx: number, order: number, onSelect: (string, number) -> ())
    local card = createCardShell(parent, tabId, title, desc, isCompact, 0, order)
    local currentIdx = defaultIdx

    local choicePill = create("TextButton", {
        AnchorPoint = isCompact and Vector2.new(0.5, 1) or Vector2.new(1, 0.5),
        Position = isCompact and UDim2.new(0.5, 0, 1, -8) or UDim2.new(1, -14, 0.5, 0),
        Size = isCompact and UDim2.new(1, -24, 0, 30) or UDim2.fromOffset(176, 34),
        Text = "◂  " .. options[currentIdx] .. "  ▸",
        AutoButtonColor = false,
        ZIndex = 6,
        Parent = card
    })
    addCorner(choicePill, 8)
    local pillStroke = addStroke(choicePill, Color3.new(1, 1, 1), 1, 0.2)

    local function updatePillSize()
        local fSize = getFontSize()
        if isCompact then
            choicePill.Size = UDim2.new(1, -24, 0, math.round(30 * fSize.Scale))
        else
            local textLen = string.len(choicePill.Text)
            local dynamicW = math.clamp(math.round(textLen * 7.5 * fSize.Scale), fSize.PillMinW, 220)
            choicePill.Size = UDim2.fromOffset(dynamicW, fSize.PillHeight)
        end
    end

    choicePill.MouseButton1Click:Connect(function()
        currentIdx = (currentIdx % #options) + 1
        choicePill.Text = "◂  " .. options[currentIdx] .. "  ▸"
        updatePillSize()
        onSelect(options[currentIdx], currentIdx)
    end)

    registerThemeUpdater(function(theme)
        choicePill.BackgroundColor3 = theme.SelectorBg
        choicePill.TextColor3 = theme.Accent
        pillStroke.Color = theme.Accent
    end)

    registerFontUpdater(function(font, fSize)
        choicePill.Font = font.Bold
        choicePill.TextSize = math.round(11 * fSize.Scale)
        updatePillSize()
    end)
end

-- 2. TOGGLE SWITCH CARD
local function addToggleCard(parent: ScrollingFrame, tabId: string, title: string, desc: string, defaultState: boolean, order: number, onToggle: (boolean) -> ())
    local card = createCardShell(parent, tabId, title, desc, false, 0, order)
    local state = defaultState

    local statusPill = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(96, 34),
        Text = state and "Enabled ●" or "Disabled ○",
        AutoButtonColor = false,
        ZIndex = 6,
        Parent = card
    })
    addCorner(statusPill, 8)
    local toggleStroke = addStroke(statusPill, Color3.new(1, 1, 1), 1, 0.2)

    local function syncVisual()
        local theme = getTheme()
        statusPill.Text = state and "Enabled ●" or "Disabled ○"
        TweenService:Create(statusPill, TweenFast, {
            BackgroundColor3 = state and theme.SelectorBg or theme.InputBg,
            TextColor3 = state and theme.Accent or theme.TextMuted
        }):Play()
        TweenService:Create(toggleStroke, TweenFast, {
            Color = state and theme.Accent or theme.Stroke
        }):Play()
    end

    statusPill.MouseButton1Click:Connect(function()
        state = not state
        syncVisual()
        onToggle(state)
        showStatus(title .. ": " .. (state and "ON" or "OFF"))
    end)

    registerThemeUpdater(function()
        syncVisual()
    end)

    registerFontUpdater(function(font, fSize)
        statusPill.Font = font.Bold
        statusPill.TextSize = math.round(11 * fSize.Scale)
        statusPill.Size = UDim2.fromOffset(math.round(108 * fSize.Scale), fSize.PillHeight)
    end)
end

-- 3. SLIDER BAR CARD
local function addSliderCard(parent: ScrollingFrame, tabId: string, title: string, desc: string, minVal: number, maxVal: number, defaultVal: number, suffix: string, order: number, onSlide: (number) -> ())
    local card = createCardShell(parent, tabId, title, desc, false, 16, order)
    local val = math.clamp(defaultVal, minVal, maxVal)

    local valuePill = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 10),
        Size = UDim2.fromOffset(76, 24),
        ZIndex = 5,
        Parent = card
    })
    addCorner(valuePill, 6)
    local valStroke = addStroke(valuePill, Color3.new(1, 1, 1), 1, 0.25)

    local valLabel = create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = tostring(val) .. suffix,
        ZIndex = 6,
        Parent = valuePill
    })

    local track = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -11),
        Size = UDim2.new(1, -28, 0, 7),
        ZIndex = 5,
        Parent = card
    })
    addCorner(track, 99)

    local fillRatio = (val - minVal) / (maxVal - minVal)
    local fill = create("Frame", {
        Size = UDim2.new(fillRatio, 0, 1, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 6,
        Parent = track
    })
    addCorner(fill, 99)
    local fillGrad = create("UIGradient", { Parent = fill })

    local sliding = false
    local function updateFromX(screenX: number)
        local x0 = track.AbsolutePosition.X
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local r = math.clamp((screenX - x0) / w, 0, 1)
        val = math.round(minVal + (maxVal - minVal) * r)
        valLabel.Text = tostring(val) .. suffix
        fill.Size = UDim2.new(r, 0, 1, 0)
        onSlide(val)
    end

    track.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateFromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input: InputObject)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input: InputObject)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            sliding = false
            showStatus(title .. ": " .. tostring(val) .. suffix)
        end
    end)

    registerThemeUpdater(function(theme)
        valuePill.BackgroundColor3 = theme.SelectorBg
        valStroke.Color = theme.Accent
        valLabel.TextColor3 = theme.Accent
        track.BackgroundColor3 = theme.InputBg
        fillGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.AccentSecondary),
            ColorSequenceKeypoint.new(1, theme.Accent)
        })
    end)

    registerFontUpdater(function(font, fSize)
        valLabel.Font = font.Bold
        valLabel.TextSize = math.round(11 * fSize.Scale)
        valuePill.Size = UDim2.fromOffset(math.round(78 * fSize.Scale), math.round(24 * fSize.Scale))
    end)
end

-- 4. TEXT INPUT CARD
local function addInputCard(parent: ScrollingFrame, tabId: string, title: string, desc: string, isCompact: boolean, defaultText: string, placeholder: string, order: number, onEnter: (string) -> ())
    local card = createCardShell(parent, tabId, title, desc, isCompact, 0, order)

    local box = create("TextBox", {
        AnchorPoint = isCompact and Vector2.new(0.5, 1) or Vector2.new(1, 0.5),
        Position = isCompact and UDim2.new(0.5, 0, 1, -8) or UDim2.new(1, -14, 0.5, 0),
        Size = isCompact and UDim2.new(1, -24, 0, 30) or UDim2.fromOffset(168, 34),
        Text = defaultText,
        PlaceholderText = placeholder,
        ClearTextOnFocus = false,
        ZIndex = 6,
        Parent = card
    })
    addCorner(box, 8)
    local bStroke = addStroke(box, Color3.new(1, 1, 1), 1, 0.25)

    box.FocusLost:Connect(function()
        onEnter(box.Text)
        showStatus(title .. " disimpan")
    end)

    registerThemeUpdater(function(theme)
        box.BackgroundColor3 = theme.SelectorBg
        box.TextColor3 = theme.TextPrimary
        box.PlaceholderColor3 = theme.TextMuted
        bStroke.Color = theme.Accent
    end)

    registerFontUpdater(function(font, fSize)
        box.Font = font.Medium
        box.TextSize = math.round(11 * fSize.Scale)
        if isCompact then
            box.Size = UDim2.new(1, -24, 0, math.round(30 * fSize.Scale))
        else
            box.Size = UDim2.fromOffset(fSize.PillMinW, fSize.PillHeight)
        end
    end)
end

-- 5. ACTION BUTTON CARD
local function addActionCard(parent: ScrollingFrame, tabId: string, title: string, desc: string, btnLabel: string, order: number, onClick: () -> ())
    local card = createCardShell(parent, tabId, title, desc, false, 0, order)

    local actBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(148, 34),
        Text = btnLabel,
        AutoButtonColor = false,
        ZIndex = 6,
        Parent = card
    })
    addCorner(actBtn, 8)
    local aStroke = addStroke(actBtn, Color3.new(1, 1, 1), 1, 0.15)

    actBtn.MouseButton1Click:Connect(function()
        onClick()
    end)

    registerThemeUpdater(function(theme)
        actBtn.BackgroundColor3 = theme.SelectorBg
        actBtn.TextColor3 = theme.Accent
        aStroke.Color = theme.Accent
    end)

    registerFontUpdater(function(font, fSize)
        actBtn.Font = font.Bold
        actBtn.TextSize = math.round(11 * fSize.Scale)
        actBtn.Size = UDim2.fromOffset(math.round(150 * fSize.Scale), fSize.PillHeight)
    end)
end

-- ================================================================================
-- 11. ANIMASI STARTUP ILLUSTRATION (OTOMATIS SAAT PERTAMA KALI DIMULAI)
-- ================================================================================
local skipIntro = false

SkipIntroBtn.MouseButton1Click:Connect(function()
    skipIntro = true
end)

local function playStartupIllustration()
    State.IsLoading = true
    skipIntro = false

    setRobloxCoreGuiHidden(true)
    HUDCanvas.Visible = false
    FloatingShortcut.Visible = false
    TopLeftCrownBar.Visible = true
    ModalBlocker.Visible = true
    ModalBlocker.BackgroundTransparency = 0.18
    ModalBlur.Size = 18

    StartupOverlay.Visible = true
    IntroBarFill.Size = UDim2.fromScale(0, 1)

    local stages = {
        { Pct = 0.35, Label = "Loading Dry Cursed | Hub monochrome shaders..." },
        { Pct = 0.70, Label = "Calibrating proportional UIScale & layout..." },
        { Pct = 1.00, Label = "Welcome to Dry Cursed | Hub community" },
    }

    for _, st in ipairs(stages) do
        if skipIntro then break end
        TweenService:Create(IntroBarFill, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.fromScale(st.Pct, 1)
        }):Play()
        for i = 1, 8 do
            if skipIntro then break end
            local p = math.clamp(math.round((st.Pct - 0.3 * (1 - i / 8)) * 100), 1, 100)
            IntroStatusText.Text = string.format("%s (%d%%)", st.Label, p)
            task.wait(0.035)
        end
    end

    IntroBarFill.Size = UDim2.fromScale(1, 1)
    IntroStatusText.Text = "Ready • 100%"
    if not skipIntro then
        task.wait(0.18)
    end

    StartupOverlay.Visible = false
    State.IsLoading = false
    HUDCanvas.Visible = true
    animateTabCards(State.CurrentTab)
end

-- ================================================================================
-- 12. POPULASI KATEGORI & PANEL STUDIO
-- ================================================================================
local PageGeneral = createSideTab("General", "◈", "General",     "General & Character",       1)
local PageVisual  = createSideTab("Visual",  "❖", "Visuals",     "Monochrome & Deep Blue GFX",2)
local PageTheme   = createSideTab("Theme",   "⬢", "Theme & Font","Theme, Font & Logo Studio", 3)
local PageSystem  = createSideTab("System",  "⚙", "Scale & Layout","Proportional Scale & Intro",4)

-- [TAB 1: GENERAL]
addInputCard(PageGeneral, "General", "Community Display Tag", "Nama panggilan di dalam Dry Cursed | Hub", false, State.Gameplay.PlayerTag, "Ketik tag...", 1, function(val)
    State.Gameplay.PlayerTag = val
end)

addSliderCard(PageGeneral, "General", "Camera Field of View", "Sesuaikan jarak pandang kamera (60° - 110°)", 60, 110, State.Gameplay.FOV, "°", 2, function(val)
    State.Gameplay.FOV = val
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = val
    end
end)

addToggleCard(PageGeneral, "General", "Auto Sprint Movement", "Tingkatkan kecepatan gerak karakter secara halus", State.Gameplay.SprintBoost, 3, function(on)
    State.Gameplay.SprintBoost = on
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = on and 24 or 16
    end
end)

addToggleCard(PageGeneral, "General", "Smooth Camera Stabilizer", "Redam guncangan kamera saat berpindah arah", State.Gameplay.SmoothCam, 4, function(on)
    State.Gameplay.SmoothCam = on
end)

-- [TAB 2: VISUALS]
addToggleCard(PageVisual, "Visual", "Lightweight Motion Graphics", "Animasi pergeseran gradien halus & ramah FPS", State.MotionEnabled, 1, function(on)
    State.MotionEnabled = on
end)

addSelectorCard(PageVisual, "Visual", "Gradient Render Profile", "Pilih kedalaman gradien Premiere pada panel", false, { "Premiere Deep", "Monochrome Soft", "High Contrast" }, 1, 2, function(choice)
    State.Gameplay.RenderMode = choice
end)

addSliderCard(PageVisual, "Visual", "Deep Blue Ambient Contrast", "Tingkat kepekatan bayangan panel utama", 0, 100, State.Gameplay.ContrastLvl, "%", 3, function(val)
    State.Gameplay.ContrastLvl = val
end)

addToggleCard(PageVisual, "Visual", "Background Focus Blur", "Aktifkan efek blur dunia belakang saat menu tampil", true, 4, function(on)
    ModalBlur.Enabled = on
end)

-- [TAB 3: THEME, FONT & LOGO STUDIO (Tampil di Tab Tengah & Panel Kanan)]
local function populateAppearanceCards(container: ScrollingFrame, tabTag: string, compact: boolean)
    addSelectorCard(container, tabTag, "Color Theme", "Pilih tema Monochrome & Deep Blue", compact, ThemeOrder, State.ThemeIndex, 1, function(_, idx)
        State.ThemeIndex = idx
        broadcastTheme()
        showStatus("Theme: " .. ThemeOrder[idx])
    end)

    addSelectorCard(container, tabTag, "Font Family", "Pilih jenis huruf seluruh teks", compact, { "Gotham Clean", "Builder Modern", "Jura Minimal", "Mono Technical" }, State.FontIndex, 2, function(fName, idx)
        State.FontIndex = idx
        broadcastFont()
        showStatus("Font: " .. fName)
    end)

    addSelectorCard(container, tabTag, "Text & Button Size", "Ukuran teks & tombol ikut menyesuaikan", compact, { "Small (90%)", "Normal (100%)", "Large (112%)" }, State.FontSizeIndex, 3, function(sName, idx)
        State.FontSizeIndex = idx
        broadcastFont()
        showStatus("Size: " .. sName)
    end)

    addSelectorCard(container, tabTag, "Custom Emblem", "Pilih simbol logo kiri atas", compact, { "◈ Dry Crest", "❖ Eclipse Mono", "⬢ Hexa Art", "✦ North Star" }, State.LogoIndex, 4, function(lName, idx)
        State.LogoIndex = idx
        State.CustomLogoAsset = ""
        updateLogoVisuals()
        showStatus("Logo: " .. lName)
    end)

    addInputCard(container, tabTag, "Custom Logo ID", "Masukkan rbxassetid:// gambar", compact, "", "rbxassetid://...", 5, function(text)
        local trimmed = string.gsub(text, "^%s*(.-)%s*$", "%1")
        if trimmed ~= "" and not string.find(trimmed, "rbxassetid://") and tonumber(trimmed) then
            trimmed = "rbxassetid://" .. trimmed
        end
        State.CustomLogoAsset = trimmed
        updateLogoVisuals()
    end)
end

populateAppearanceCards(PageTheme, "Theme", false)
populateAppearanceCards(RightStudioScroll, "", true)

-- [TAB 4: SCALE & LAYOUT]
addActionCard(PageSystem, "System", "Replay Startup Illustration", "Putar ulang ilustrasi Monochrome Eclipse saat mulai", "▶ Replay Intro", 1, function()
    task.spawn(playStartupIllustration)
end)

addSelectorCard(PageSystem, "System", "Panel Dock Position", "Atur tata letak di Kiri, Tengah, atau Kanan", false, dockModes, 1, 2, function(mode)
    applyLayoutMode(mode)
end)

addSliderCard(PageSystem, "System", "Proportional Window Scale", "Kecilkan/besarkan seluruh menu + teks tanpa crop", 55, 95, math.round(State.UserZoomFactor * 100), "%", 3, function(val)
    State.UserZoomFactor = val / 100
    computeAndApplyProportionalScale()
end)

addSliderCard(PageSystem, "System", "Master Audio Volume", "Volume utama suara antarmuka dan efek", 0, 100, State.Gameplay.MasterVolume, "%", 4, function(val)
    State.Gameplay.MasterVolume = val
end)

selectTab("General")
applyLayoutMode("Tri-HUD")
updateLogoVisuals()

-- ================================================================================
-- 13. LIGHTWEIGHT MOTION GRAPHICS (RINGAN, HALUS, HEMAT CPU/GPU)
-- ================================================================================
local motionTime = 0

RunService.RenderStepped:Connect(function(dt: number)
    if not State.MotionEnabled then return end
    motionTime += dt

    -- Saat layar Startup Loading aktif, putar perlahan cincin Monochrome Eclipse
    if State.IsLoading and StartupOverlay.Visible then
        OuterMonoRing.Rotation = (motionTime * 14) % 360
        ArchSquare.Rotation = 45 - (motionTime * 10) % 360
        return
    end

    -- Pergeseran Offset gradien Premiere yang sangat ringan & tenang
    local gentleShift = math.sin(motionTime * 0.9) * 0.08
    for _, grad in ipairs(ShimmerGradients) do
        grad.Offset = Vector2.new(gentleShift, 0)
    end
end)

-- ================================================================================
-- 14. FILTER PENCARIAN KARTU REAL-TIME
-- ================================================================================
SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local q = string.lower(string.gsub(SearchInput.Text, "^%s*(.-)%s*$", "%1"))
    if q == "" then
        for _, item in ipairs(SearchableCards) do
            item.Frame.Visible = true
        end
        selectTab(State.CurrentTab)
        return
    end

    CenterCategoryHeader.Text = 'Filter: "' .. SearchInput.Text .. '"'
    local shownTab: string? = nil
    for _, item in ipairs(SearchableCards) do
        local matched = string.find(item.Keywords, q, 1, true) ~= nil
        item.Frame.Visible = matched
        if matched and not shownTab then
            shownTab = item.TabId
        end
    end

    for id, data in pairs(Tabs) do
        data.Page.Visible = (id == (shownTab or State.CurrentTab))
    end
end)

-- ================================================================================
-- 15. MINIMIZE & MAXIMIZE (MENUTUPI ROBLOX TOPBAR & BUKA KEMBALI DENGAN CEPAT)
-- ================================================================================
local isTransitioning = false

local function setMinimizedState(minimize: boolean)
    if isTransitioning or State.IsLoading or State.IsMinimized == minimize then return end
    isTransitioning = true
    State.IsMinimized = minimize

    if minimize then
        setRobloxCoreGuiHidden(false)
        TweenService:Create(ModalBlur, TweenClose, { Size = 0 }):Play()
        TweenService:Create(ModalBlocker, TweenClose, { BackgroundTransparency = 1 }):Play()

        HUDCanvas.Visible = false
        ModalBlocker.Visible = false
        TopLeftCrownBar.Visible = false

        FloatingShortcut.Visible = true
    else
        setRobloxCoreGuiHidden(true)
        FloatingShortcut.Visible = false
        TopLeftCrownBar.Visible = true

        ModalBlocker.Visible = true
        ModalBlocker.BackgroundTransparency = 0.22
        HUDCanvas.Visible = true
        TweenService:Create(ModalBlur, TweenSmooth, { Size = 16 }):Play()
        computeAndApplyProportionalScale()
        animateTabCards(State.CurrentTab)
    end

    task.wait(0.08)
    isTransitioning = false
end

MinimizeRedBtn.MouseButton1Click:Connect(function()
    setMinimizedState(true)
end)

makeDraggable(TopBar, HUDCanvas, nil)
makeDraggable(FloatingShortcut, FloatingShortcut, function()
    setMinimizedState(false)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        setMinimizedState(not State.IsMinimized)
    end
end)

-- // MULAI DENGAN ILUSTRASI MONOCHROME ECLIPSE SAAT PERTAMA KALI DIJALANKAN
task.spawn(playStartupIllustration)
