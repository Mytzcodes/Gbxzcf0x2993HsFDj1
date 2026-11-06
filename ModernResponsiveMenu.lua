--[[
    ================================================================================
    FUTURE HUAXIA // PREMIERE MOTION-GRAPHIC HUD — v5.0 (STARTUP ILLUSTRATION EDITION)
    ================================================================================
    Penempatan   : StarterPlayer -> StarterPlayerScripts (LocalScript)
    Fitur Utama & Pembaruan v5.0 :
      1. Cinematic Startup Illustration & Boot Loader (Aktif Otomatis Saat Pertama Dimulai):
         - Menampilkan ilustrasi vektor prosedural "Celestial Cyber-Astrolabe" berlapis:
           * Cincin Orbit Luar & Dalam yang berputar berlawanan arah (Counter-Rotating Rings)
           * Bingkai Oktagonal Berlian Huaxia (Dual 45°/0° Mecha Frames)
           * Inti Reaktor Hologram dengan gelombang kejut (Core Pulse & Orbital Nodes)
           * Pita Pemindai Laser (Holographic Horizon Laser Scan)
           * Progress Bar Gradien Premiere (0% -> 100%) + Log Tahapan Booting Real-Time
           * Tombol [SKIP INTRO ▸] & Transisi Iris Membuka HUD Utama 85% Layar.
      2. Premiere Multi-Stop Luxury Gradients (UIGradient di dalam semua panel & kartu)
      3. Interactive Bottom-Right Resize Handle Shape (Pojok Kanan Bawah: Tarik 55%-95%)
      4. Procedural Motion Graphics Engine (RenderStepped: Shimmer, Scanline, Equalizer)
      5. Index Paling Depan (DisplayOrder = 999999) + Modal Focus Blocker + Blur Kamera
      6. Tombol Minimize Merah Interaktif + 5 Tema Warna + 4 Font + Custom Logo
    ================================================================================
]]

-- // SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- // Bersihkan UI & Blur lama bila script dijalankan ulang
local oldGui = PlayerGui:FindFirstChild("FutureHuaxiaHUD")
if oldGui then
    oldGui:Destroy()
end
local oldBlur = Lighting:FindFirstChild("FutureHUDModalBlur")
if oldBlur then
    oldBlur:Destroy()
end

-- ================================================================================
-- 1. KONFIGURASI TEMA PREMIERE GRADIENT, FONT, & LOGO
-- ================================================================================
local Themes = {
    ["Premiere Violet-Cyan"] = {
        Name            = "Premiere Pro (Deep Violet & Cyan)",
        MainBg          = Color3.fromRGB(12, 14, 24),
        PanelBg         = Color3.fromRGB(18, 20, 36),
        GradStart       = Color3.fromRGB(28, 22, 54),
        GradMid         = Color3.fromRGB(16, 24, 42),
        GradEnd         = Color3.fromRGB(10, 34, 46),
        CardBg          = Color3.fromRGB(24, 28, 48),
        CardHover       = Color3.fromRGB(34, 40, 68),
        SelectorBg      = Color3.fromRGB(26, 38, 66),
        SelectorHover   = Color3.fromRGB(36, 54, 92),
        InputBg         = Color3.fromRGB(9, 11, 20),
        Accent          = Color3.fromRGB(0, 240, 255),
        AccentSecondary = Color3.fromRGB(168, 85, 247),
        TextPrimary     = Color3.fromRGB(245, 250, 255),
        TextSecondary   = Color3.fromRGB(160, 175, 205),
        TextMuted       = Color3.fromRGB(100, 115, 145),
        Stroke          = Color3.fromRGB(52, 65, 105),
    },
    ["Neo-Shenzhen Jade"] = {
        Name            = "Neo-Shenzhen (Jade Cyber)",
        MainBg          = Color3.fromRGB(10, 15, 22),
        PanelBg         = Color3.fromRGB(15, 22, 32),
        GradStart       = Color3.fromRGB(12, 38, 44),
        GradMid         = Color3.fromRGB(14, 22, 34),
        GradEnd         = Color3.fromRGB(20, 18, 38),
        CardBg          = Color3.fromRGB(20, 30, 44),
        CardHover       = Color3.fromRGB(28, 42, 60),
        SelectorBg      = Color3.fromRGB(14, 44, 52),
        SelectorHover   = Color3.fromRGB(20, 64, 74),
        InputBg         = Color3.fromRGB(8, 12, 18),
        Accent          = Color3.fromRGB(0, 245, 212),
        AccentSecondary = Color3.fromRGB(56, 189, 248),
        TextPrimary     = Color3.fromRGB(240, 253, 250),
        TextSecondary   = Color3.fromRGB(148, 168, 184),
        TextMuted       = Color3.fromRGB(94, 112, 130),
        Stroke          = Color3.fromRGB(36, 62, 78),
    },
    ["Huaxia Dynasty Gold"] = {
        Name            = "Huaxia Gold (Dynasty Sci-Fi)",
        MainBg          = Color3.fromRGB(16, 13, 18),
        PanelBg         = Color3.fromRGB(24, 19, 28),
        GradStart       = Color3.fromRGB(46, 30, 20),
        GradMid         = Color3.fromRGB(24, 19, 28),
        GradEnd         = Color3.fromRGB(36, 16, 24),
        CardBg          = Color3.fromRGB(34, 27, 38),
        CardHover       = Color3.fromRGB(48, 38, 52),
        SelectorBg      = Color3.fromRGB(52, 38, 18),
        SelectorHover   = Color3.fromRGB(74, 54, 24),
        InputBg         = Color3.fromRGB(11, 9, 14),
        Accent          = Color3.fromRGB(255, 190, 11),
        AccentSecondary = Color3.fromRGB(239, 68, 68),
        TextPrimary     = Color3.fromRGB(255, 250, 240),
        TextSecondary   = Color3.fromRGB(190, 175, 155),
        TextMuted       = Color3.fromRGB(125, 112, 98),
        Stroke          = Color3.fromRGB(78, 60, 34),
    },
    ["Crimson Protocol"] = {
        Name            = "Crimson Protocol (Mecha Red)",
        MainBg          = Color3.fromRGB(16, 10, 14),
        PanelBg         = Color3.fromRGB(24, 14, 20),
        GradStart       = Color3.fromRGB(48, 16, 28),
        GradMid         = Color3.fromRGB(22, 13, 20),
        GradEnd         = Color3.fromRGB(32, 18, 14),
        CardBg          = Color3.fromRGB(34, 20, 28),
        CardHover       = Color3.fromRGB(48, 28, 38),
        SelectorBg      = Color3.fromRGB(58, 18, 30),
        SelectorHover   = Color3.fromRGB(82, 24, 42),
        InputBg         = Color3.fromRGB(10, 6, 9),
        Accent          = Color3.fromRGB(255, 42, 85),
        AccentSecondary = Color3.fromRGB(251, 146, 60),
        TextPrimary     = Color3.fromRGB(255, 241, 242),
        TextSecondary   = Color3.fromRGB(195, 160, 170),
        TextMuted       = Color3.fromRGB(130, 98, 108),
        Stroke          = Color3.fromRGB(84, 34, 48),
    },
    ["Aero Glass Light"] = {
        Name            = "Aero Porcelain (Future Light)",
        MainBg          = Color3.fromRGB(234, 240, 248),
        PanelBg         = Color3.fromRGB(246, 249, 253),
        GradStart       = Color3.fromRGB(224, 236, 255),
        GradMid         = Color3.fromRGB(244, 247, 252),
        GradEnd         = Color3.fromRGB(232, 226, 255),
        CardBg          = Color3.fromRGB(226, 234, 244),
        CardHover       = Color3.fromRGB(210, 222, 238),
        SelectorBg      = Color3.fromRGB(214, 230, 255),
        SelectorHover   = Color3.fromRGB(188, 214, 255),
        InputBg         = Color3.fromRGB(255, 255, 255),
        Accent          = Color3.fromRGB(37, 99, 235),
        AccentSecondary = Color3.fromRGB(124, 58, 237),
        TextPrimary     = Color3.fromRGB(15, 23, 42),
        TextSecondary   = Color3.fromRGB(71, 85, 105),
        TextMuted       = Color3.fromRGB(120, 135, 155),
        Stroke          = Color3.fromRGB(180, 196, 218),
    }
}

local ThemeOrder = {
    "Premiere Violet-Cyan",
    "Neo-Shenzhen Jade",
    "Huaxia Dynasty Gold",
    "Crimson Protocol",
    "Aero Glass Light"
}

local FontPresets = {
    { Name = "Sci-Fi Future", Bold = Enum.Font.SciFi,       Medium = Enum.Font.Jura,         Regular = Enum.Font.Jura },
    { Name = "Modern Gotham", Bold = Enum.Font.GothamBold,  Medium = Enum.Font.GothamMedium, Regular = Enum.Font.Gotham },
    { Name = "Tactical Code", Bold = Enum.Font.RobotoMono,  Medium = Enum.Font.Code,         Regular = Enum.Font.RobotoMono },
    { Name = "Cyber Michroma",Bold = Enum.Font.Michroma,    Medium = Enum.Font.GothamMedium, Regular = Enum.Font.Gotham },
}

local FontSizePresets = {
    { Name = "Compact (Kecil)", Scale = 0.88, CardPad = 58, PillHeight = 30, PillWidth = 152 },
    { Name = "Standard (Ideal)",Scale = 1.00, CardPad = 66, PillHeight = 36, PillWidth = 174 },
    { Name = "Large (Besar)",   Scale = 1.15, CardPad = 76, PillHeight = 42, PillWidth = 198 },
}

local LogoPresets = {
    { Name = "❖ Premiere Core", Glyph = "❖" },
    { Name = "⬢ Hexa Matrix",   Glyph = "⬢" },
    { Name = "✦ Astral Nova",   Glyph = "✦" },
    { Name = "⚡ Cyber Pulse",   Glyph = "⚡" },
}

local MinimizeColors = {
    BgDefault     = Color3.fromRGB(195, 22, 54),
    BgHover       = Color3.fromRGB(255, 48, 88),
    BgPress       = Color3.fromRGB(136, 16, 40),
    StrokeDefault = Color3.fromRGB(255, 120, 145),
    StrokeHover   = Color3.fromRGB(255, 235, 240),
}

-- // STATE DATA
local State = {
    IsLoading       = true,
    IsMinimized     = false,
    ThemeIndex      = 1,
    FontIndex       = 1,
    FontSizeIndex   = 2,
    LogoIndex       = 1,
    CustomLogoAsset = "",
    LayoutMode      = "Tri-HUD",
    CurrentTab      = "Combat",
    WindowScaleX    = 0.85,
    WindowScaleY    = 0.85,
    UIScalePercent  = 100,
    MotionEnabled   = true,
    Gameplay = {
        FOV          = 80,
        SprintBoost  = true,
        LockOnTarget = true,
        RenderMode   = "Premiere Ultra",
        BloomLevel   = 70,
        MasterVolume = 85,
        PlayerTag    = LocalPlayer.DisplayName,
    }
}

-- // REGISTRY TEMA, FONT, & MOTION GRAPHICS
local ThemeCallbacks: { (any) -> () } = {}
local FontCallbacks: { (any, any) -> () } = {}
local RotatingGradients: { { Grad: UIGradient, Speed: number } } = {}

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

-- // TWEEN PRESETS
local TweenFast   = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenSmooth = TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TweenSpring = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TweenClose  = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

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

local function attachPremierePanelGradient(parent: GuiObject, rotation: number): UIGradient
    local grad = create("UIGradient", {
        Rotation = rotation,
        Parent = parent
    })
    registerThemeUpdater(function(theme)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, theme.GradStart),
            ColorSequenceKeypoint.new(0.52, theme.GradMid),
            ColorSequenceKeypoint.new(1.0, theme.GradEnd)
        })
    end)
    return grad
end

local function attachAnimatedBorderGradient(stroke: UIStroke, speed: number): UIGradient
    local grad = create("UIGradient", {
        Rotation = 0,
        Parent = stroke
    })
    registerThemeUpdater(function(theme)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, theme.Accent),
            ColorSequenceKeypoint.new(0.5, theme.Stroke),
            ColorSequenceKeypoint.new(1.0, theme.AccentSecondary)
        })
    end)
    table.insert(RotatingGradients, { Grad = grad, Speed = speed })
    return grad
end

local function addCyberCornerAccents(parent: GuiObject, zIndex: number)
    local topL = create("Frame", {
        Size = UDim2.fromOffset(18, 2),
        Position = UDim2.fromOffset(8, 6),
        BorderSizePixel = 0,
        ZIndex = zIndex,
        Parent = parent
    })
    local topLVert = create("Frame", {
        Size = UDim2.fromOffset(2, 12),
        Position = UDim2.fromOffset(8, 6),
        BorderSizePixel = 0,
        ZIndex = zIndex,
        Parent = parent
    })
    registerThemeUpdater(function(theme)
        topL.BackgroundColor3 = theme.Accent
        topLVert.BackgroundColor3 = theme.Accent
    end)
end

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
            TweenService:Create(target, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            }):Play()
        end
    end)
end

-- ================================================================================
-- 2. SCREEN GUI PRIORITAS TERTINGGI & MODAL INPUT BLOCKER
-- ================================================================================
local ScreenGui = create("ScreenGui", {
    Name = "FutureHuaxiaHUD",
    DisplayOrder = 999999,
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    Parent = PlayerGui
})

local ModalBlur = create("BlurEffect", {
    Name = "FutureHUDModalBlur",
    Size = 18,
    Parent = Lighting
})

local GlobalUIScale = create("UIScale", {
    Scale = 1,
    Parent = ScreenGui
})

local function updateViewportScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local ratio = math.min(vp.X / 1440, vp.Y / 810)
    local userMul = State.UIScalePercent / 100
    GlobalUIScale.Scale = math.clamp(ratio * userMul, 0.62, 1.35)
end

if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateViewportScale)
end
updateViewportScale()

-- MODAL SHIELD PENAHAN INPUT DI BELAKANG MENU
local ModalBlocker = create("TextButton", {
    Name = "ModalFocusShield",
    Size = UDim2.fromScale(1, 1),
    Position = UDim2.fromScale(0, 0),
    BackgroundColor3 = Color3.fromRGB(4, 6, 14),
    BackgroundTransparency = 0.35,
    Text = "",
    AutoButtonColor = false,
    Active = true,
    Modal = true,
    Selectable = false,
    ZIndex = 1000,
    Parent = ScreenGui
})

create("ScrollingFrame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    CanvasSize = UDim2.fromScale(1, 2),
    ScrollingEnabled = true,
    Active = true,
    ZIndex = 1001,
    Parent = ModalBlocker
})

-- ================================================================================
-- 3. STARTUP LOADING ILLUSTRATION SCREEN (TAMPIL SAAT SCRIPT PERTAMA DIMULAI)
-- ================================================================================
-- Desain Ilustrasi Vektor Prosedural "Celestial Cyber-Astrolabe" di Tengah Layar
local StartupOverlay = create("Frame", {
    Name = "StartupLoadingIllustration",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromScale(0.85, 0.85),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ClipsDescendants = true,
    Active = true,
    ZIndex = 6000, -- Berada di atas seluruh panel saat loading
    Parent = ScreenGui
})
addCorner(StartupOverlay, 16)
attachPremierePanelGradient(StartupOverlay, 135)
local startupStroke = addStroke(StartupOverlay, Color3.new(1, 1, 1), 2, 0.05)
attachAnimatedBorderGradient(startupStroke, 45)
addCyberCornerAccents(StartupOverlay, 6005)

local StartupScale = create("UIScale", {
    Scale = 1,
    Parent = StartupOverlay
})

-- Kanvas Ilustrasi Pusat (Celestial Cyber-Astrolabe Vector Illustration)
local IllustrationArtBox = create("Frame", {
    Name = "IllustrationVectorCanvas",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.42, 0),
    Size = UDim2.fromOffset(230, 230),
    BackgroundTransparency = 1,
    ZIndex = 6010,
    Parent = StartupOverlay
})

-- Lapis 1: Aura Glow Gradien Radial di belakang ilustrasi
local ArtAura = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(220, 220),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.72,
    ZIndex = 6011,
    Parent = IllustrationArtBox
})
addCorner(ArtAura, 999)
attachPremierePanelGradient(ArtAura, 45)

-- Lapis 2: Cincin Orbit Luar (Outer Astrolabe Ring) + 8 Titik Kompas Orbital
local OuterOrbitRing = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(196, 196),
    BackgroundTransparency = 1,
    ZIndex = 6012,
    Parent = IllustrationArtBox
})
addCorner(OuterOrbitRing, 999)
local outerRingStroke = addStroke(OuterOrbitRing, Color3.new(1, 1, 1), 1.8, 0.25)
attachAnimatedBorderGradient(outerRingStroke, 60)

for deg = 0, 315, 45 do
    local rad = math.rad(deg)
    local nx = 0.5 + math.cos(rad) * 0.5
    local ny = 0.5 + math.sin(rad) * 0.5
    local dot = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(nx, ny),
        Size = (deg % 90 == 0) and UDim2.fromOffset(8, 8) or UDim2.fromOffset(5, 5),
        Rotation = 45,
        BorderSizePixel = 0,
        ZIndex = 6013,
        Parent = OuterOrbitRing
    })
    addCorner(dot, 2)
    registerThemeUpdater(function(theme)
        dot.BackgroundColor3 = (deg % 90 == 0) and theme.Accent or theme.AccentSecondary
    end)
end

-- Lapis 3: Bingkai Berlian Ganda (Dual Octagonal Bagua / Cyber Rhombus)
local DiamondFrameA = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(132, 132),
    BackgroundTransparency = 0.85,
    Rotation = 45,
    ZIndex = 6014,
    Parent = IllustrationArtBox
})
addCorner(DiamondFrameA, 14)
local diaStrokeA = addStroke(DiamondFrameA, Color3.new(1, 1, 1), 2, 0.15)

local DiamondFrameB = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(132, 132),
    BackgroundTransparency = 0.88,
    Rotation = 0,
    ZIndex = 6014,
    Parent = IllustrationArtBox
})
addCorner(DiamondFrameB, 14)
local diaStrokeB = addStroke(DiamondFrameB, Color3.new(1, 1, 1), 1.5, 0.35)

-- Lapis 4: Cincin Dalam Berputar Berlawanan (Inner Chrono Ring)
local InnerChronoRing = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(96, 96),
    BackgroundTransparency = 1,
    ZIndex = 6015,
    Parent = IllustrationArtBox
})
addCorner(InnerChronoRing, 999)
local innerRingStroke = addStroke(InnerChronoRing, Color3.new(1, 1, 1), 2.2, 0.1)
attachAnimatedBorderGradient(innerRingStroke, -90)

-- Palang Sumbu Horizon & Vertikal di dalam Ilustrasi
local AxisHoriz = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(220, 1),
    BackgroundTransparency = 0.6,
    BorderSizePixel = 0,
    ZIndex = 6012,
    Parent = IllustrationArtBox
})
local AxisVert = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(1, 220),
    BackgroundTransparency = 0.6,
    BorderSizePixel = 0,
    ZIndex = 6012,
    Parent = IllustrationArtBox
})

-- Lapis 5: Inti Emblem Pusat (Core Crest Emblem)
local CoreEmblemPod = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(64, 64),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ZIndex = 6016,
    Parent = IllustrationArtBox
})
addCorner(CoreEmblemPod, 16)
attachPremierePanelGradient(CoreEmblemPod, 45)
local corePodStroke = addStroke(CoreEmblemPod, Color3.new(1, 1, 1), 2, 0)

local CoreEmblemGlyph = create("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "❖",
    ZIndex = 6017,
    Parent = CoreEmblemPod
})

-- Garis Pemindai Laser Horizontal pada Ilustrasi
local IllustrationLaserScan = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.1, 0),
    Size = UDim2.new(1.15, 0, 0, 3),
    BorderSizePixel = 0,
    ZIndex = 6018,
    Parent = IllustrationArtBox
})
create("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 1)
    }),
    Parent = IllustrationLaserScan
})

-- Tipografi Judul & Status Tahapan Booting di Bawah Ilustrasi
local BootTitleLabel = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.71, 0),
    Size = UDim2.new(0.8, 0, 0, 26),
    BackgroundTransparency = 1,
    Text = "HUAXIA // PREMIERE OS v5.0",
    ZIndex = 6015,
    Parent = StartupOverlay
})

local BootStageLabel = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.77, 0),
    Size = UDim2.new(0.8, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = "[01/04] INITIALIZING CELESTIAL VECTOR ENGINE...",
    ZIndex = 6015,
    Parent = StartupOverlay
})

-- Progress Bar Gradien Premiere + Persentase
local BootBarTrack = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.83, 0),
    Size = UDim2.new(0.52, 0, 0, 10),
    ZIndex = 6015,
    Parent = StartupOverlay
})
addCorner(BootBarTrack, 99)
local bootTrackStroke = addStroke(BootBarTrack, Color3.new(1, 1, 1), 1, 0.3)

local BootBarFill = create("Frame", {
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ZIndex = 6016,
    Parent = BootBarTrack
})
addCorner(BootBarFill, 99)
local bootFillGrad = create("UIGradient", {
    Parent = BootBarFill
})

local BootPercentLabel = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.865, 0),
    Size = UDim2.new(0.3, 0, 0, 20),
    BackgroundTransparency = 1,
    Text = "0%",
    ZIndex = 6015,
    Parent = StartupOverlay
})

-- Tombol [SKIP INTRO ▸] di Pojok Kanan Bawah Layar Loading
local SkipIntroBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -20, 1, -18),
    Size = UDim2.fromOffset(124, 34),
    Text = "SKIP INTRO ▸",
    AutoButtonColor = false,
    ZIndex = 6020,
    Parent = StartupOverlay
})
addCorner(SkipIntroBtn, 8)
local skipStroke = addStroke(SkipIntroBtn, Color3.new(1, 1, 1), 1.2, 0.2)

registerThemeUpdater(function(theme)
    DiamondFrameA.BackgroundColor3 = theme.SelectorBg
    DiamondFrameB.BackgroundColor3 = theme.CardBg
    diaStrokeA.Color = theme.Accent
    diaStrokeB.Color = theme.AccentSecondary
    AxisHoriz.BackgroundColor3 = theme.Accent
    AxisVert.BackgroundColor3 = theme.AccentSecondary
    corePodStroke.Color = theme.Accent
    CoreEmblemGlyph.TextColor3 = theme.Accent
    IllustrationLaserScan.BackgroundColor3 = theme.Accent
    BootTitleLabel.TextColor3 = theme.TextPrimary
    BootStageLabel.TextColor3 = theme.Accent
    BootBarTrack.BackgroundColor3 = theme.InputBg
    bootTrackStroke.Color = theme.Stroke
    bootFillGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, theme.AccentSecondary),
        ColorSequenceKeypoint.new(1, theme.Accent)
    })
    BootPercentLabel.TextColor3 = theme.TextSecondary
    SkipIntroBtn.BackgroundColor3 = theme.SelectorBg
    SkipIntroBtn.TextColor3 = theme.Accent
    skipStroke.Color = theme.Accent
end)

registerFontUpdater(function(font, fSize)
    CoreEmblemGlyph.Font = font.Bold
    CoreEmblemGlyph.TextSize = math.round(30 * fSize.Scale)
    BootTitleLabel.Font = font.Bold
    BootTitleLabel.TextSize = math.round(18 * fSize.Scale)
    BootStageLabel.Font = font.Medium
    BootStageLabel.TextSize = math.round(12 * fSize.Scale)
    BootPercentLabel.Font = font.Bold
    BootPercentLabel.TextSize = math.round(13 * fSize.Scale)
    SkipIntroBtn.Font = font.Bold
    SkipIntroBtn.TextSize = math.round(11 * fSize.Scale)
end)

-- ================================================================================
-- 4. FLOATING SHORTCUT ICON (ZINDEX 5000+ DENGAN PREMIERE GRADIENT & PULSE RING)
-- ================================================================================
local FloatingShortcut = create("Frame", {
    Name = "FloatingShortcutPod",
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0.018, 0, 0.5, 0),
    Size = UDim2.fromOffset(68, 68),
    BackgroundColor3 = Color3.new(1, 1, 1),
    Visible = false,
    Active = true,
    ZIndex = 5000,
    Parent = ScreenGui
})
addCorner(FloatingShortcut, 16)
attachPremierePanelGradient(FloatingShortcut, 45)
local shortcutStroke = addStroke(FloatingShortcut, Color3.new(1, 1, 1), 2.2, 0)
attachAnimatedBorderGradient(shortcutStroke, 65)

local ShortcutPulseRing = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ZIndex = 4999,
    Parent = FloatingShortcut
})
addCorner(ShortcutPulseRing, 18)
local pulseRingStroke = addStroke(ShortcutPulseRing, Color3.new(1, 1, 1), 1.5, 0.3)

local ShortcutLogoImage = create("ImageLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.42, 0),
    Size = UDim2.fromOffset(30, 30),
    BackgroundTransparency = 1,
    Image = "",
    Visible = false,
    ZIndex = 5002,
    Parent = FloatingShortcut
})

local ShortcutGlyph = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.40, 0),
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    Text = "❖",
    ZIndex = 5002,
    Parent = FloatingShortcut
})

local ShortcutBadgeText = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -6),
    Size = UDim2.new(1, -6, 0, 14),
    BackgroundTransparency = 1,
    Text = "OPEN HUD",
    ZIndex = 5002,
    Parent = FloatingShortcut
})

registerThemeUpdater(function(theme)
    ShortcutGlyph.TextColor3 = theme.Accent
    ShortcutLogoImage.ImageColor3 = theme.Accent
    ShortcutBadgeText.TextColor3 = theme.TextPrimary
    pulseRingStroke.Color = theme.Accent
end)

registerFontUpdater(function(font, fSize)
    ShortcutGlyph.Font = font.Bold
    ShortcutGlyph.TextSize = math.round(24 * fSize.Scale)
    ShortcutBadgeText.Font = font.Bold
    ShortcutBadgeText.TextSize = math.round(9 * fSize.Scale)
end)

-- ================================================================================
-- 5. CONTAINER UTAMA 85% DARI LAYAR (DENGAN MOTION GRAPHICS & RESIZE GRIP)
-- ================================================================================
local HUDCanvas = create("Frame", {
    Name = "HUDCanvas85Percent",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromScale(State.WindowScaleX, State.WindowScaleY),
    BackgroundTransparency = 1,
    Visible = false, -- Muncul setelah Startup Loading Illustration selesai
    Active = true,
    ZIndex = 2000,
    Parent = ScreenGui
})

local HUDAnimScale = create("UIScale", {
    Scale = 1,
    Parent = HUDCanvas
})

-- ================================================================================
-- 6. TOP COMMAND BAR (DENGAN PREMIERE GRADIENT, MOTION EQUALIZER, & RED MINIMIZE)
-- ================================================================================
local TopCommandBar = create("Frame", {
    Name = "TopCommandBar",
    Size = UDim2.new(1, 0, 0.105, -6),
    Position = UDim2.fromScale(0, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ClipsDescendants = true,
    Active = true,
    ZIndex = 2100,
    Parent = HUDCanvas
})
addCorner(TopCommandBar, 12)
attachPremierePanelGradient(TopCommandBar, 15)
local topBarStroke = addStroke(TopCommandBar, Color3.new(1, 1, 1), 1.6, 0.1)
attachAnimatedBorderGradient(topBarStroke, 25)
addCyberCornerAccents(TopCommandBar, 2105)

local TopShimmerBar = create("Frame", {
    Size = UDim2.new(0.35, 0, 0, 2),
    Position = UDim2.new(0, 0, 0, 0),
    BorderSizePixel = 0,
    ZIndex = 2106,
    Parent = TopCommandBar
})
create("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 1)
    }),
    Parent = TopShimmerBar
})

local LogoPod = create("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 14, 0.5, 0),
    Size = UDim2.fromOffset(42, 42),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ZIndex = 2102,
    Parent = TopCommandBar
})
addCorner(LogoPod, 10)
attachPremierePanelGradient(LogoPod, 135)
local logoPodStroke = addStroke(LogoPod, Color3.new(1, 1, 1), 1.5, 0.15)
attachAnimatedBorderGradient(logoPodStroke, 55)

local HeaderLogoGlyph = create("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "❖",
    ZIndex = 2103,
    Parent = LogoPod
})

local HeaderLogoImage = create("ImageLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(28, 28),
    BackgroundTransparency = 1,
    Image = "",
    Visible = false,
    ZIndex = 2103,
    Parent = LogoPod
})

local HeaderTitle = create("TextLabel", {
    Position = UDim2.new(0, 64, 0.15, 0),
    Size = UDim2.new(0.22, 0, 0.40, 0),
    BackgroundTransparency = 1,
    Text = "HUAXIA // PREMIERE HUD",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2102,
    Parent = TopCommandBar
})

local HeaderSubTitle = create("TextLabel", {
    Position = UDim2.new(0, 64, 0.55, 0),
    Size = UDim2.new(0.22, 0, 0.30, 0),
    BackgroundTransparency = 1,
    Text = "SCALE: 85%x85% • MOTION ON",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2102,
    Parent = TopCommandBar
})

local EqualizerPod = create("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0.26, 0, 0.5, 0),
    Size = UDim2.fromOffset(44, 26),
    BackgroundTransparency = 1,
    ZIndex = 2103,
    Parent = TopCommandBar
})
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    Padding = UDim.new(0, 3),
    Parent = EqualizerPod
})

local EqBars: { Frame } = {}
for i = 1, 6 do
    local bar = create("Frame", {
        LayoutOrder = i,
        Size = UDim2.fromOffset(4, 12),
        BorderSizePixel = 0,
        ZIndex = 2104,
        Parent = EqualizerPod
    })
    addCorner(bar, 99)
    table.insert(EqBars, bar)
    registerThemeUpdater(function(theme)
        bar.BackgroundColor3 = (i % 2 == 0) and theme.Accent or theme.AccentSecondary
    end)
end

local DockSwitchBar = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.50, 0, 0.5, 0),
    Size = UDim2.fromOffset(316, 36),
    ZIndex = 2102,
    Parent = TopCommandBar
})
addCorner(DockSwitchBar, 9)
local dockBarStroke = addStroke(DockSwitchBar, Color3.new(1, 1, 1), 1, 0.25)

local TopSearchFrame = create("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -136, 0.5, 0),
    Size = UDim2.fromOffset(168, 36),
    ZIndex = 2102,
    Parent = TopCommandBar
})
addCorner(TopSearchFrame, 9)
local searchStroke = addStroke(TopSearchFrame, Color3.new(1, 1, 1), 1, 0.25)

local SearchInput = create("TextBox", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, -20, 1, -6),
    BackgroundTransparency = 1,
    Text = "",
    PlaceholderText = "⌕ Filter kartu...",
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    ZIndex = 2103,
    Parent = TopSearchFrame
})

local MinimizeRedBtn = create("TextButton", {
    Name = "InteractiveRedMinimizeBtn",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0.5, 0),
    Size = UDim2.fromOffset(112, 36),
    BackgroundColor3 = MinimizeColors.BgDefault,
    Text = "— MINIMIZE",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    AutoButtonColor = false,
    ZIndex = 2105,
    Parent = TopCommandBar
})
addCorner(MinimizeRedBtn, 9)
local minRedStroke = addStroke(MinimizeRedBtn, MinimizeColors.StrokeDefault, 1.5, 0.1)

create("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(195, 180, 190))
    }),
    Rotation = 90,
    Parent = MinimizeRedBtn
})

MinimizeRedBtn.MouseEnter:Connect(function()
    TweenService:Create(MinimizeRedBtn, TweenFast, {
        BackgroundColor3 = MinimizeColors.BgHover,
        Size = UDim2.fromOffset(116, 38),
        Text = "▼ HIDE HUD"
    }):Play()
    TweenService:Create(minRedStroke, TweenFast, {
        Color = MinimizeColors.StrokeHover,
        Thickness = 2.2,
        Transparency = 0
    }):Play()
end)

MinimizeRedBtn.MouseLeave:Connect(function()
    TweenService:Create(MinimizeRedBtn, TweenFast, {
        BackgroundColor3 = MinimizeColors.BgDefault,
        Size = UDim2.fromOffset(112, 36),
        Text = "— MINIMIZE"
    }):Play()
    TweenService:Create(minRedStroke, TweenFast, {
        Color = MinimizeColors.StrokeDefault,
        Thickness = 1.5,
        Transparency = 0.1
    }):Play()
end)

MinimizeRedBtn.MouseButton1Down:Connect(function()
    TweenService:Create(MinimizeRedBtn, TweenInfo.new(0.08), {
        BackgroundColor3 = MinimizeColors.BgPress,
        Size = UDim2.fromOffset(108, 34)
    }):Play()
end)

registerThemeUpdater(function(theme)
    TopShimmerBar.BackgroundColor3 = theme.Accent
    HeaderLogoGlyph.TextColor3 = theme.Accent
    HeaderLogoImage.ImageColor3 = theme.Accent
    HeaderTitle.TextColor3 = theme.TextPrimary
    HeaderSubTitle.TextColor3 = theme.Accent
    DockSwitchBar.BackgroundColor3 = theme.InputBg
    dockBarStroke.Color = theme.Stroke
    TopSearchFrame.BackgroundColor3 = theme.InputBg
    searchStroke.Color = theme.Stroke
    SearchInput.TextColor3 = theme.TextPrimary
    SearchInput.PlaceholderColor3 = theme.TextMuted
end)

registerFontUpdater(function(font, fSize)
    HeaderLogoGlyph.Font = font.Bold
    HeaderLogoGlyph.TextSize = math.round(20 * fSize.Scale)
    HeaderTitle.Font = font.Bold
    HeaderTitle.TextSize = math.round(14 * fSize.Scale)
    HeaderSubTitle.Font = font.Medium
    HeaderSubTitle.TextSize = math.round(10 * fSize.Scale)
    SearchInput.Font = font.Regular
    SearchInput.TextSize = math.round(12 * fSize.Scale)
    MinimizeRedBtn.Font = font.Bold
    MinimizeRedBtn.TextSize = math.round(11 * fSize.Scale)
end)

local function updateLogoVisuals()
    local preset = LogoPresets[State.LogoIndex]
    if State.CustomLogoAsset ~= "" then
        HeaderLogoGlyph.Visible = false
        ShortcutGlyph.Visible = false
        HeaderLogoImage.Visible = true
        ShortcutLogoImage.Visible = true
        HeaderLogoImage.Image = State.CustomLogoAsset
        ShortcutLogoImage.Image = State.CustomLogoAsset
    else
        HeaderLogoImage.Visible = false
        ShortcutLogoImage.Visible = false
        HeaderLogoGlyph.Visible = true
        ShortcutGlyph.Visible = true
        HeaderLogoGlyph.Text = preset.Glyph
        ShortcutGlyph.Text = preset.Glyph
        CoreEmblemGlyph.Text = preset.Glyph
    end
end

-- ================================================================================
-- 7. BODY WORKSPACE (3 PANEL DENGAN PREMIERE INTERIOR GRADIENT & MOTION SCANLINE)
-- ================================================================================
local WorkspaceZone = create("Frame", {
    Name = "WorkspaceZone",
    Position = UDim2.new(0, 0, 0.115, 0),
    Size = UDim2.new(1, 0, 0.885, 0),
    BackgroundTransparency = 1,
    ZIndex = 2050,
    Parent = HUDCanvas
})

local MotionScanlines: { Frame } = {}
local MotionNodes: { { Node: Frame, BaseX: number, BaseY: number, Phase: number, Speed: number } } = {}

local function attachInteriorMotionGraphics(panel: GuiObject, nodeCount: number)
    local scanline = create("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.new(0, 0, -0.2, 0),
        BackgroundTransparency = 0.88,
        BorderSizePixel = 0,
        ZIndex = 2101,
        Parent = panel
    })
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.65),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Parent = scanline
    })
    table.insert(MotionScanlines, scanline)

    for i = 1, nodeCount do
        local bx = (i / (nodeCount + 1))
        local by = ((i * 0.37) % 0.8) + 0.1
        local sz = (i % 2 == 0) and 6 or 10
        local node = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(bx, by),
            Size = UDim2.fromOffset(sz, sz),
            BackgroundTransparency = 0.82,
            Rotation = 45,
            BorderSizePixel = 0,
            ZIndex = 2101,
            Parent = panel
        })
        addCorner(node, 2)
        table.insert(MotionNodes, {
            Node = node,
            BaseX = bx,
            BaseY = by,
            Phase = i * 1.4,
            Speed = 0.8 + (i * 0.25)
        })
        registerThemeUpdater(function(theme)
            node.BackgroundColor3 = (i % 2 == 0) and theme.Accent or theme.AccentSecondary
        end)
    end

    registerThemeUpdater(function(theme)
        scanline.BackgroundColor3 = theme.Accent
    end)
end

-- [PANEL 1: SIDE NAVIGATION DOCK]
local SideNavPanel = create("Frame", {
    Name = "SideNavPanel",
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.new(0.21, -8, 1, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ClipsDescendants = true,
    Active = true,
    ZIndex = 2100,
    Parent = WorkspaceZone
})
addCorner(SideNavPanel, 12)
attachPremierePanelGradient(SideNavPanel, 125)
local sideNavStroke = addStroke(SideNavPanel, Color3.new(1, 1, 1), 1.5, 0.15)
attachAnimatedBorderGradient(sideNavStroke, 32)
addCyberCornerAccents(SideNavPanel, 2105)
attachInteriorMotionGraphics(SideNavPanel, 4)

local SideNavTitle = create("TextLabel", {
    Position = UDim2.new(0, 16, 0, 14),
    Size = UDim2.new(1, -32, 0, 18),
    BackgroundTransparency = 1,
    Text = "NAVIGATION MATRIX",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2102,
    Parent = SideNavPanel
})

local SideTabList = create("Frame", {
    Position = UDim2.new(0, 12, 0, 40),
    Size = UDim2.new(1, -24, 1, -116),
    BackgroundTransparency = 1,
    ZIndex = 2102,
    Parent = SideNavPanel
})

create("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = SideTabList
})

local OperatorPod = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -12),
    Size = UDim2.new(1, -24, 0, 62),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ZIndex = 2102,
    Parent = SideNavPanel
})
addCorner(OperatorPod, 10)
attachPremierePanelGradient(OperatorPod, 45)
local opPodStroke = addStroke(OperatorPod, Color3.new(1, 1, 1), 1.2, 0.2)

local OperatorName = create("TextLabel", {
    Position = UDim2.new(0, 12, 0, 10),
    Size = UDim2.new(1, -24, 0, 20),
    BackgroundTransparency = 1,
    Text = "OP // @" .. LocalPlayer.Name,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 2103,
    Parent = OperatorPod
})

local OperatorHint = create("TextLabel", {
    Position = UDim2.new(0, 12, 0, 32),
    Size = UDim2.new(1, -24, 0, 18),
    BackgroundTransparency = 1,
    Text = "Key: [RightCtrl] • Drag ◢",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2103,
    Parent = OperatorPod
})

-- [PANEL 2: CENTER INPUT CARDS MATRIX]
local CenterMatrixPanel = create("Frame", {
    Name = "CenterMatrixPanel",
    Position = UDim2.new(0.21, 4, 0, 0),
    Size = UDim2.new(0.51, -8, 1, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ClipsDescendants = true,
    Active = true,
    ZIndex = 2100,
    Parent = WorkspaceZone
})
addCorner(CenterMatrixPanel, 12)
attachPremierePanelGradient(CenterMatrixPanel, 145)
local centerStroke = addStroke(CenterMatrixPanel, Color3.new(1, 1, 1), 1.5, 0.15)
attachAnimatedBorderGradient(centerStroke, 20)
addCyberCornerAccents(CenterMatrixPanel, 2105)
attachInteriorMotionGraphics(CenterMatrixPanel, 6)

local CenterHeaderTitle = create("TextLabel", {
    Position = UDim2.new(0, 20, 0, 14),
    Size = UDim2.new(0.55, 0, 0, 24),
    BackgroundTransparency = 1,
    Text = "COMBAT & TELEMETRY",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2102,
    Parent = CenterMatrixPanel
})

local StatusToast = create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -20, 0, 16),
    Size = UDim2.new(0.42, 0, 0, 20),
    BackgroundTransparency = 1,
    Text = "● PREMIERE MOTION READY",
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 2102,
    Parent = CenterMatrixPanel
})

local function notifyStatus(msg: string)
    StatusToast.Text = "◈ " .. msg
end

local PagesContainer = create("Frame", {
    Position = UDim2.new(0, 0, 0, 46),
    Size = UDim2.new(1, 0, 1, -52),
    BackgroundTransparency = 1,
    ZIndex = 2102,
    Parent = CenterMatrixPanel
})

-- [PANEL 3: RIGHT QUICK CUSTOMIZER & STUDIO]
local RightStudioPanel = create("Frame", {
    Name = "RightStudioPanel",
    Position = UDim2.new(0.72, 4, 0, 0),
    Size = UDim2.new(0.28, -4, 1, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ClipsDescendants = true,
    Active = true,
    ZIndex = 2100,
    Parent = WorkspaceZone
})
addCorner(RightStudioPanel, 12)
attachPremierePanelGradient(RightStudioPanel, 160)
local rightStroke = addStroke(RightStudioPanel, Color3.new(1, 1, 1), 1.5, 0.15)
attachAnimatedBorderGradient(rightStroke, 38)
addCyberCornerAccents(RightStudioPanel, 2105)
attachInteriorMotionGraphics(RightStudioPanel, 4)

local RightHeaderTitle = create("TextLabel", {
    Position = UDim2.new(0, 16, 0, 14),
    Size = UDim2.new(1, -32, 0, 22),
    BackgroundTransparency = 1,
    Text = "PREMIERE STUDIO",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2102,
    Parent = RightStudioPanel
})

local RightScroll = create("ScrollingFrame", {
    Position = UDim2.new(0, 0, 0, 44),
    Size = UDim2.new(1, 0, 1, -64),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 2102,
    Parent = RightStudioPanel
})
addPadding(RightScroll, 4, 18, 14, 14)

create("UIListLayout", {
    Padding = UDim.new(0, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = RightScroll
})

registerThemeUpdater(function(theme)
    SideNavTitle.TextColor3 = theme.TextMuted
    opPodStroke.Color = theme.Accent
    OperatorName.TextColor3 = theme.TextPrimary
    OperatorHint.TextColor3 = theme.Accent

    CenterHeaderTitle.TextColor3 = theme.TextPrimary
    StatusToast.TextColor3 = theme.Accent

    RightHeaderTitle.TextColor3 = theme.Accent
    RightScroll.ScrollBarImageColor3 = theme.Accent
end)

registerFontUpdater(function(font, fSize)
    SideNavTitle.Font = font.Bold
    SideNavTitle.TextSize = math.round(10 * fSize.Scale)
    OperatorName.Font = font.Bold
    OperatorName.TextSize = math.round(12 * fSize.Scale)
    OperatorHint.Font = font.Regular
    OperatorHint.TextSize = math.round(11 * fSize.Scale)
    CenterHeaderTitle.Font = font.Bold
    CenterHeaderTitle.TextSize = math.round(15 * fSize.Scale)
    StatusToast.Font = font.Bold
    StatusToast.TextSize = math.round(11 * fSize.Scale)
    RightHeaderTitle.Font = font.Bold
    RightHeaderTitle.TextSize = math.round(13 * fSize.Scale)
end)

-- ================================================================================
-- 8. POJOK KANAN BAWAH: INTERACTIVE RESIZE GRIP SHAPE (TARIK UNTUK UBAH UKURAN)
-- ================================================================================
local ResizeCornerPod = create("TextButton", {
    Name = "BottomRightResizeGrip",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, 4, 1, 4),
    Size = UDim2.fromOffset(146, 36),
    BackgroundColor3 = Color3.new(1, 1, 1),
    Text = "",
    AutoButtonColor = false,
    Active = true,
    ZIndex = 3200,
    Parent = HUDCanvas
})
addCorner(ResizeCornerPod, 10)
attachPremierePanelGradient(ResizeCornerPod, 35)
local resizePodStroke = addStroke(ResizeCornerPod, Color3.new(1, 1, 1), 1.8, 0.05)
attachAnimatedBorderGradient(resizePodStroke, 75)

local ResizeHintText = create("TextLabel", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 10, 0.5, 0),
    Size = UDim2.new(1, -44, 1, 0),
    BackgroundTransparency = 1,
    Text = "⇲ RESIZE 85%",
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3202,
    Parent = ResizeCornerPod
})

local GripShapeBox = create("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -6, 1, -6),
    Size = UDim2.fromOffset(26, 24),
    BackgroundTransparency = 1,
    ZIndex = 3202,
    Parent = ResizeCornerPod
})

local CornerBracketH = create("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, 0, 1, 0),
    Size = UDim2.fromOffset(18, 3),
    BorderSizePixel = 0,
    ZIndex = 3203,
    Parent = GripShapeBox
})
addCorner(CornerBracketH, 99)

local CornerBracketV = create("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, 0, 1, 0),
    Size = UDim2.fromOffset(3, 18),
    BorderSizePixel = 0,
    ZIndex = 3203,
    Parent = GripShapeBox
})
addCorner(CornerBracketV, 99)

local GripDiag1 = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(1, -6, 1, -6),
    Size = UDim2.fromOffset(8, 2),
    Rotation = -45,
    BorderSizePixel = 0,
    ZIndex = 3203,
    Parent = GripShapeBox
})
local GripDiag2 = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(1, -11, 1, -11),
    Size = UDim2.fromOffset(14, 2),
    Rotation = -45,
    BorderSizePixel = 0,
    ZIndex = 3203,
    Parent = GripShapeBox
})
local GripDiag3 = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(1, -16, 1, -16),
    Size = UDim2.fromOffset(20, 2),
    Rotation = -45,
    BorderSizePixel = 0,
    ZIndex = 3203,
    Parent = GripShapeBox
})

registerThemeUpdater(function(theme)
    ResizeHintText.TextColor3 = theme.Accent
    CornerBracketH.BackgroundColor3 = theme.Accent
    CornerBracketV.BackgroundColor3 = theme.Accent
    GripDiag1.BackgroundColor3 = theme.TextPrimary
    GripDiag2.BackgroundColor3 = theme.Accent
    GripDiag3.BackgroundColor3 = theme.AccentSecondary
end)

registerFontUpdater(function(font, fSize)
    ResizeHintText.Font = font.Bold
    ResizeHintText.TextSize = math.round(11 * fSize.Scale)
end)

ResizeCornerPod.MouseEnter:Connect(function()
    TweenService:Create(ResizeCornerPod, TweenFast, {
        Size = UDim2.fromOffset(162, 40)
    }):Play()
    ResizeHintText.Text = "⇲ TARIK SUDUT"
end)

ResizeCornerPod.MouseLeave:Connect(function()
    local pctX = math.round(State.WindowScaleX * 100)
    local pctY = math.round(State.WindowScaleY * 100)
    TweenService:Create(ResizeCornerPod, TweenFast, {
        Size = UDim2.fromOffset(146, 36)
    }):Play()
    ResizeHintText.Text = string.format("⇲ %d%% × %d%%", pctX, pctY)
end)

do
    local isResizing = false
    local resizeStartPos = Vector3.zero
    local startScaleX = State.WindowScaleX
    local startScaleY = State.WindowScaleY
    local lastClickTick = 0

    ResizeCornerPod.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local now = tick()
            if (now - lastClickTick) < 0.32 then
                State.WindowScaleX = 0.85
                State.WindowScaleY = 0.85
                TweenService:Create(HUDCanvas, TweenSpring, {
                    Size = UDim2.fromScale(0.85, 0.85)
                }):Play()
                ResizeHintText.Text = "⇲ RESET 85%"
                HeaderSubTitle.Text = "SCALE: 85%x85% • MOTION ON"
                notifyStatus("Ukuran di-reset ke 85% layar")
                return
            end
            lastClickTick = now

            isResizing = true
            resizeStartPos = input.Position
            startScaleX = State.WindowScaleX
            startScaleY = State.WindowScaleY
        end
    end)

    UserInputService.InputChanged:Connect(function(input: InputObject)
        if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local cam = workspace.CurrentCamera
            if not cam then return end
            local vp = cam.ViewportSize
            local delta = input.Position - resizeStartPos

            local dScaleX = (delta.X * 1.6) / math.max(vp.X, 1)
            local dScaleY = (delta.Y * 1.6) / math.max(vp.Y, 1)

            State.WindowScaleX = math.clamp(startScaleX + dScaleX, 0.55, 0.95)
            State.WindowScaleY = math.clamp(startScaleY + dScaleY, 0.55, 0.95)

            HUDCanvas.Size = UDim2.fromScale(State.WindowScaleX, State.WindowScaleY)

            local pctX = math.round(State.WindowScaleX * 100)
            local pctY = math.round(State.WindowScaleY * 100)
            ResizeHintText.Text = string.format("⇲ %d%% × %d%%", pctX, pctY)
            HeaderSubTitle.Text = string.format("SCALE: %d%%x%d%% • MOTION ON", pctX, pctY)
        end
    end)

    UserInputService.InputEnded:Connect(function(input: InputObject)
        if isResizing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isResizing = false
            local pctX = math.round(State.WindowScaleX * 100)
            local pctY = math.round(State.WindowScaleY * 100)
            notifyStatus(string.format("Ukuran HUD: %d%% × %d%%", pctX, pctY))
        end
    end)
end

-- ================================================================================
-- 9. SISTEM PERPINDAHAN POSISI MENU (TRI-HUD / DOCK KIRI / TENGAH / KANAN)
-- ================================================================================
local DockModeButtons: { [string]: TextButton } = {}

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
        SideNavPanel.Visible = true
        RightStudioPanel.Visible = true
        TweenService:Create(SideNavPanel, TweenSmooth, {
            Position = UDim2.fromScale(0, 0),
            Size = UDim2.new(0.21, -8, 1, 0)
        }):Play()
        TweenService:Create(CenterMatrixPanel, TweenSmooth, {
            Position = UDim2.new(0.21, 4, 0, 0),
            Size = UDim2.new(0.51, -8, 1, 0)
        }):Play()
        TweenService:Create(RightStudioPanel, TweenSmooth, {
            Position = UDim2.new(0.72, 4, 0, 0),
            Size = UDim2.new(0.28, -4, 1, 0)
        }):Play()
    elseif mode == "Dock Kiri" then
        SideNavPanel.Visible = true
        RightStudioPanel.Visible = false
        TweenService:Create(SideNavPanel, TweenSmooth, {
            Position = UDim2.fromScale(0, 0),
            Size = UDim2.new(0.24, -8, 1, 0)
        }):Play()
        TweenService:Create(CenterMatrixPanel, TweenSmooth, {
            Position = UDim2.new(0.24, 4, 0, 0),
            Size = UDim2.new(0.76, -4, 1, 0)
        }):Play()
    elseif mode == "Fokus Tengah" then
        SideNavPanel.Visible = true
        RightStudioPanel.Visible = true
        TweenService:Create(RightStudioPanel, TweenSmooth, {
            Position = UDim2.fromScale(0, 0),
            Size = UDim2.new(0.25, -8, 1, 0)
        }):Play()
        TweenService:Create(CenterMatrixPanel, TweenSmooth, {
            Position = UDim2.new(0.25, 4, 0, 0),
            Size = UDim2.new(0.50, -8, 1, 0)
        }):Play()
        TweenService:Create(SideNavPanel, TweenSmooth, {
            Position = UDim2.new(0.75, 4, 0, 0),
            Size = UDim2.new(0.25, -4, 1, 0)
        }):Play()
    elseif mode == "Dock Kanan" then
        SideNavPanel.Visible = true
        RightStudioPanel.Visible = false
        TweenService:Create(CenterMatrixPanel, TweenSmooth, {
            Position = UDim2.fromScale(0, 0),
            Size = UDim2.new(0.76, -8, 1, 0)
        }):Play()
        TweenService:Create(SideNavPanel, TweenSmooth, {
            Position = UDim2.new(0.76, 4, 0, 0),
            Size = UDim2.new(0.24, -4, 1, 0)
        }):Play()
    end
    notifyStatus("Mode Posisi: " .. mode)
end

local dockModes = { "Tri-HUD", "Dock Kiri", "Fokus Tengah", "Dock Kanan" }
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 4),
    Parent = DockSwitchBar
})

for i, mName in ipairs(dockModes) do
    local dBtn = create("TextButton", {
        LayoutOrder = i,
        Size = UDim2.fromOffset(74, 28),
        Text = mName,
        AutoButtonColor = false,
        ZIndex = 2104,
        Parent = DockSwitchBar
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
        dBtn.TextSize = math.clamp(math.round(10 * fSize.Scale), 9, 12)
    end)
end

-- ================================================================================
-- 10. BUILDER TAB & INPUT CARDS (DENGAN PREMIERE CARD GRADIENT & CASCADE MOTION)
-- ================================================================================
local Tabs: { [string]: { Button: TextButton, Bar: Frame, Page: ScrollingFrame, Title: string, Cards: { UIScale } } } = {}
local SearchableCards: { { Frame: Frame, Keywords: string, TabId: string } } = {}

local function playTabCascadeMotion(tabId: string)
    local data = Tabs[tabId]
    if not data or not State.MotionEnabled then return end
    for idx, cScale in ipairs(data.Cards) do
        cScale.Scale = 0.88
        task.delay((idx - 1) * 0.035, function()
            TweenService:Create(cScale, TweenSpring, { Scale = 1 }):Play()
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
            CenterHeaderTitle.Text = data.Title
            TweenService:Create(data.Button, TweenFast, {
                BackgroundColor3 = theme.SelectorBg,
                TextColor3 = theme.Accent
            }):Play()
            TweenService:Create(data.Bar, TweenFast, {
                Size = UDim2.new(0, 4, 0.65, 0),
                BackgroundTransparency = 0
            }):Play()
            playTabCascadeMotion(id)
        else
            TweenService:Create(data.Button, TweenFast, {
                BackgroundColor3 = theme.CardBg,
                TextColor3 = theme.TextSecondary
            }):Play()
            TweenService:Create(data.Bar, TweenFast, {
                Size = UDim2.new(0, 4, 0, 0),
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
        ZIndex = 2103,
        Parent = SideTabList
    })
    addCorner(btn, 9)
    local tabStroke = addStroke(btn, Color3.new(1, 1, 1), 1, 0.35)

    local bar = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 5, 0.5, 0),
        Size = UDim2.new(0, 4, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 2104,
        Parent = btn
    })
    addCorner(bar, 99)

    local page = create("ScrollingFrame", {
        Name = tabId .. "Page",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        ZIndex = 2103,
        Parent = PagesContainer
    })
    addPadding(page, 4, 22, 18, 18)

    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page
    })

    btn.MouseButton1Click:Connect(function()
        SearchInput.Text = ""
        selectTab(tabId)
    end)

    btn.MouseEnter:Connect(function()
        if State.CurrentTab ~= tabId then
            local theme = getTheme()
            TweenService:Create(btn, TweenFast, { BackgroundColor3 = theme.CardHover }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if State.CurrentTab ~= tabId then
            local theme = getTheme()
            TweenService:Create(btn, TweenFast, { BackgroundColor3 = theme.CardBg }):Play()
        end
    end)

    registerThemeUpdater(function(theme)
        local isCurrent = (State.CurrentTab == tabId)
        btn.BackgroundColor3 = isCurrent and theme.SelectorBg or theme.CardBg
        btn.TextColor3 = isCurrent and theme.Accent or theme.TextSecondary
        tabStroke.Color = isCurrent and theme.Accent or theme.Stroke
        bar.BackgroundColor3 = theme.Accent
        page.ScrollBarImageColor3 = theme.Accent
    end)

    registerFontUpdater(function(font, fSize)
        btn.Font = font.Bold
        btn.TextSize = math.round(13 * fSize.Scale)
        btn.Size = UDim2.new(1, 0, 0, math.round(38 * fSize.Scale))
    end)

    Tabs[tabId] = { Button = btn, Bar = bar, Page = page, Title = headerTitle, Cards = {} }
    return page
end

local function createCardShell(parent: ScrollingFrame, tabId: string, title: string, desc: string, extraHeight: number, order: number): Frame
    local card = create("Frame", {
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 66 + extraHeight),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 2104,
        Parent = parent
    })
    addCorner(card, 10)
    local cStroke = addStroke(card, Color3.new(1, 1, 1), 1, 0.2)

    local cardGrad = create("UIGradient", {
        Rotation = 20,
        Parent = card
    })

    local cScale = create("UIScale", {
        Scale = 1,
        Parent = card
    })
    if tabId ~= "" and Tabs[tabId] then
        table.insert(Tabs[tabId].Cards, cScale)
    end

    local accentTick = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 3, 0.55, 0),
        BorderSizePixel = 0,
        ZIndex = 2105,
        Parent = card
    })
    addCorner(accentTick, 99)

    local titleLbl = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 10),
        Size = UDim2.new(0.54, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = title,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2105,
        Parent = card
    })

    local descLbl = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 32),
        Size = UDim2.new(0.54, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = desc,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2105,
        Parent = card
    })

    card.MouseEnter:Connect(function()
        local theme = getTheme()
        TweenService:Create(cStroke, TweenFast, { Color = theme.Accent, Transparency = 0 }):Play()
        if State.MotionEnabled then
            TweenService:Create(cScale, TweenFast, { Scale = 1.015 }):Play()
        end
    end)
    card.MouseLeave:Connect(function()
        local theme = getTheme()
        TweenService:Create(cStroke, TweenFast, { Color = theme.Stroke, Transparency = 0.2 }):Play()
        TweenService:Create(cScale, TweenFast, { Scale = 1 }):Play()
    end)

    registerThemeUpdater(function(theme)
        cardGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, theme.CardBg),
            ColorSequenceKeypoint.new(0.65, theme.PanelBg),
            ColorSequenceKeypoint.new(1.0, theme.GradStart)
        })
        cStroke.Color = theme.Stroke
        accentTick.BackgroundColor3 = theme.Accent
        titleLbl.TextColor3 = theme.TextPrimary
        descLbl.TextColor3 = theme.TextSecondary
    end)

    registerFontUpdater(function(font, fSize)
        titleLbl.Font = font.Bold
        titleLbl.TextSize = math.round(13 * fSize.Scale)
        descLbl.Font = font.Regular
        descLbl.TextSize = math.round(11 * fSize.Scale)
        descLbl.Position = UDim2.new(0, 16, 0, math.round(31 * fSize.Scale))
        card.Size = UDim2.new(1, 0, 0, fSize.CardPad + extraHeight)
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

local function addSelectorCard(parent: ScrollingFrame, tabId: string, title: string, desc: string, options: { string }, defaultIdx: number, order: number, onSelect: (string, number) -> ())
    local card = createCardShell(parent, tabId, title, desc, 0, order)
    local currentIdx = defaultIdx

    local choicePill = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(174, 36),
        Text = "◂  " .. options[currentIdx] .. "  ▸",
        AutoButtonColor = false,
        ZIndex = 2106,
        Parent = card
    })
    addCorner(choicePill, 8)
    local pillStroke = addStroke(choicePill, Color3.new(1, 1, 1), 1.2, 0.15)

    choicePill.MouseButton1Click:Connect(function()
        currentIdx = (currentIdx % #options) + 1
        choicePill.Text = "◂  " .. options[currentIdx] .. "  ▸"
        onSelect(options[currentIdx], currentIdx)
    end)

    choicePill.MouseEnter:Connect(function()
        local theme = getTheme()
        TweenService:Create(choicePill, TweenFast, { BackgroundColor3 = theme.SelectorHover }):Play()
        TweenService:Create(pillStroke, TweenFast, { Color = theme.Accent, Thickness = 1.8 }):Play()
    end)
    choicePill.MouseLeave:Connect(function()
        local theme = getTheme()
        TweenService:Create(choicePill, TweenFast, { BackgroundColor3 = theme.SelectorBg }):Play()
        TweenService:Create(pillStroke, TweenFast, { Color = theme.Accent, Thickness = 1.2 }):Play()
    end)

    registerThemeUpdater(function(theme)
        choicePill.BackgroundColor3 = theme.SelectorBg
        choicePill.TextColor3 = theme.Accent
        pillStroke.Color = theme.Accent
    end)

    registerFontUpdater(function(font, fSize)
        choicePill.Font = font.Bold
        choicePill.TextSize = math.round(12 * fSize.Scale)
        local textLen = string.len(choicePill.Text)
        local dynamicWidth = math.max(fSize.PillWidth, math.round(textLen * 7.5 * fSize.Scale))
        choicePill.Size = UDim2.fromOffset(math.min(dynamicWidth, 230), fSize.PillHeight)
    end)
end

local function addToggleCard(parent: ScrollingFrame, tabId: string, title: string, desc: string, defaultState: boolean, order: number, onToggle: (boolean) -> ())
    local card = createCardShell(parent, tabId, title, desc, 0, order)
    local state = defaultState

    local statusPill = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(96, 34),
        Text = state and "ONLINE ●" or "OFFLINE ○",
        AutoButtonColor = false,
        ZIndex = 2106,
        Parent = card
    })
    addCorner(statusPill, 8)
    local toggleStroke = addStroke(statusPill, Color3.new(1, 1, 1), 1.2, 0.15)

    local function syncToggleVisual()
        local theme = getTheme()
        statusPill.Text = state and "ONLINE ●" or "OFFLINE ○"
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
        syncToggleVisual()
        onToggle(state)
        notifyStatus(title .. " -> " .. (state and "ON" or "OFF"))
    end)

    registerThemeUpdater(function()
        syncToggleVisual()
    end)

    registerFontUpdater(function(font, fSize)
        statusPill.Font = font.Bold
        statusPill.TextSize = math.round(11 * fSize.Scale)
        statusPill.Size = UDim2.fromOffset(math.round(104 * fSize.Scale), fSize.PillHeight)
    end)
end

local function addSliderCard(parent: ScrollingFrame, tabId: string, title: string, desc: string, minVal: number, maxVal: number, defaultVal: number, suffix: string, order: number, onSlide: (number) -> ())
    local card = createCardShell(parent, tabId, title, desc, 16, order)
    local val = math.clamp(defaultVal, minVal, maxVal)

    local valuePill = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 10),
        Size = UDim2.fromOffset(78, 26),
        ZIndex = 2105,
        Parent = card
    })
    addCorner(valuePill, 6)
    local valStroke = addStroke(valuePill, Color3.new(1, 1, 1), 1, 0.25)

    local valLabel = create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = tostring(val) .. suffix,
        ZIndex = 2106,
        Parent = valuePill
    })

    local track = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -12),
        Size = UDim2.new(1, -32, 0, 8),
        ZIndex = 2105,
        Parent = card
    })
    addCorner(track, 99)

    local fillRatio = (val - minVal) / (maxVal - minVal)
    local fill = create("Frame", {
        Size = UDim2.new(fillRatio, 0, 1, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 2106,
        Parent = track
    })
    addCorner(fill, 99)

    local fillGrad = create("UIGradient", {
        Parent = fill
    })

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
            notifyStatus(title .. ": " .. tostring(val) .. suffix)
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
        valLabel.TextSize = math.round(12 * fSize.Scale)
        valuePill.Size = UDim2.fromOffset(math.round(82 * fSize.Scale), math.round(26 * fSize.Scale))
    end)
end

local function addInputCard(parent: ScrollingFrame, tabId: string, title: string, desc: string, defaultText: string, placeholder: string, order: number, onEnter: (string) -> ())
    local card = createCardShell(parent, tabId, title, desc, 0, order)

    local box = create("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(174, 34),
        Text = defaultText,
        PlaceholderText = placeholder,
        ClearTextOnFocus = false,
        ZIndex = 2106,
        Parent = card
    })
    addCorner(box, 8)
    local bStroke = addStroke(box, Color3.new(1, 1, 1), 1.2, 0.2)

    box.FocusLost:Connect(function()
        onEnter(box.Text)
        notifyStatus(title .. " disimpan")
    end)

    registerThemeUpdater(function(theme)
        box.BackgroundColor3 = theme.SelectorBg
        box.TextColor3 = theme.TextPrimary
        box.PlaceholderColor3 = theme.TextMuted
        bStroke.Color = theme.Accent
    end)

    registerFontUpdater(function(font, fSize)
        box.Font = font.Medium
        box.TextSize = math.round(12 * fSize.Scale)
        box.Size = UDim2.fromOffset(fSize.PillWidth, fSize.PillHeight)
    end)
end

local function addActionCard(parent: ScrollingFrame, tabId: string, title: string, desc: string, btnLabel: string, order: number, onClick: () -> ())
    local card = createCardShell(parent, tabId, title, desc, 0, order)

    local actBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(154, 34),
        Text = btnLabel,
        AutoButtonColor = false,
        ZIndex = 2106,
        Parent = card
    })
    addCorner(actBtn, 8)
    local aStroke = addStroke(actBtn, Color3.new(1, 1, 1), 1.2, 0.1)

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
        actBtn.Size = UDim2.fromOffset(math.round(156 * fSize.Scale), fSize.PillHeight)
    end)
end

-- ================================================================================
-- 11. LOGIKA ANIMASI STARTUP ILLUSTRATION (DIPUTAR SAAT PERTAMA KALI DIMULAI)
-- ================================================================================
local skipRequested = false

SkipIntroBtn.MouseButton1Click:Connect(function()
    skipRequested = true
end)

local function runStartupIllustrationSequence()
    State.IsLoading = true
    skipRequested = false

    HUDCanvas.Visible = false
    FloatingShortcut.Visible = false
    ModalBlocker.Visible = true
    ModalBlocker.BackgroundTransparency = 0.25
    ModalBlur.Size = 18

    StartupOverlay.Visible = true
    StartupScale.Scale = 0.86
    BootBarFill.Size = UDim2.new(0, 0, 1, 0)
    BootPercentLabel.Text = "0%"

    TweenService:Create(StartupScale, TweenSpring, { Scale = 1 }):Play()

    local stages = {
        { Pct = 0.28, Text = "[01/04] INITIALIZING CELESTIAL VECTOR ENGINE..." },
        { Pct = 0.56, Text = "[02/04] LOADING PREMIERE MULTI-STOP SHADERS..." },
        { Pct = 0.84, Text = "[03/04] CALIBRATING 85% VIEWPORT & MODAL SHIELD..." },
        { Pct = 1.00, Text = "[04/04] HUAXIA CYBER-HUD READY // WELCOME OPERATOR" },
    }

    for _, stage in ipairs(stages) do
        if skipRequested then break end
        BootStageLabel.Text = stage.Text
        TweenService:Create(BootBarFill, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(stage.Pct, 0, 1, 0)
        }):Play()

        local steps = 12
        for s = 1, steps do
            if skipRequested then break end
            local displayPct = math.round((stage.Pct - 0.25 * (1 - s / steps)) * 100)
            BootPercentLabel.Text = tostring(math.clamp(displayPct, 1, 100)) .. "%"
            task.wait(0.038)
        end
    end

    BootBarFill.Size = UDim2.new(1, 0, 1, 0)
    BootPercentLabel.Text = "100%"
    BootStageLabel.Text = "◈ SYSTEM ONLINE // LAUNCHING HUD MATRIX"
    if not skipRequested then
        task.wait(0.25)
    end

    -- Transisi Keluar Ilustrasi Loading & Membuka 3-Zone HUD Utama
    local exitTw = TweenService:Create(StartupScale, TweenClose, { Scale = 1.12 })
    TweenService:Create(StartupOverlay, TweenClose, { BackgroundTransparency = 1 }):Play()
    exitTw:Play()
    exitTw.Completed:Wait()

    StartupOverlay.Visible = false
    StartupOverlay.BackgroundTransparency = 0
    State.IsLoading = false

    HUDCanvas.Visible = true
    HUDAnimScale.Scale = 0.78
    TweenService:Create(ModalBlur, TweenSmooth, { Size = 14 }):Play()
    TweenService:Create(ModalBlocker, TweenSmooth, { BackgroundTransparency = 0.35 }):Play()
    TweenService:Create(HUDAnimScale, TweenSpring, { Scale = 1 }):Play()
    playTabCascadeMotion(State.CurrentTab)
end

-- ================================================================================
-- 12. POPULASI KATEGORI & PANEL STUDIO
-- ================================================================================
local PageCombat = createSideTab("Combat", "❖", "Combat & HUD",  "COMBAT & CHARACTER MATRIX", 1)
local PageVisual = createSideTab("Visual", "✦", "Motion & GFX",  "PREMIERE MOTION & SHADERS", 2)
local PageTheme  = createSideTab("Theme",  "⬢", "Theme & Font",  "THEME, FONT & LOGO STUDIO", 3)
local PageSystem = createSideTab("System", "⚙", "Resize & Intro","VIEWPORT, RESIZE & INTRO",  4)

-- [TAB 1: COMBAT & HUD]
addInputCard(PageCombat, "Combat", "Operator Callsign Tag", "Label identitas karakter pada HUD utama", State.Gameplay.PlayerTag, "Ketik callsign...", 1, function(val)
    State.Gameplay.PlayerTag = val
end)

addSliderCard(PageCombat, "Combat", "Tactical Camera FOV", "Sudut pandang kamera (60° - 110°) secara real-time", 60, 110, State.Gameplay.FOV, "°", 2, function(val)
    State.Gameplay.FOV = val
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = val
    end
end)

addToggleCard(PageCombat, "Combat", "Hyper-Sprint Thruster", "Tingkatkan kecepatan gerak karakter secara otomatis", State.Gameplay.SprintBoost, 3, function(on)
    State.Gameplay.SprintBoost = on
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = on and 24 or 16
    end
end)

addToggleCard(PageCombat, "Combat", "Smart Target Lock-On", "Stabilisasi fokus kamera saat mengunci musuh", State.Gameplay.LockOnTarget, 4, function(on)
    State.Gameplay.LockOnTarget = on
end)

-- [TAB 2: MOTION & GFX]
addToggleCard(PageVisual, "Visual", "Premiere Motion Graphics", "Aktifkan scanline, equalizer, partikel & rotasi gradien", State.MotionEnabled, 1, function(on)
    State.MotionEnabled = on
    for _, sc in ipairs(MotionScanlines) do
        sc.Visible = on
    end
    for _, nd in ipairs(MotionNodes) do
        nd.Node.Visible = on
    end
end)

addSelectorCard(PageVisual, "Visual", "Premiere Shader Profile", "Pilih profil gradien dan pencahayaan antarmuka", { "Premiere Ultra", "Cyber Balanced", "Low Latency" }, 1, 2, function(choice)
    State.Gameplay.RenderMode = choice
end)

addSliderCard(PageVisual, "Visual", "Neon Shimmer Intensity", "Kekuatan kilau gradien dan elemen hologram", 0, 100, State.Gameplay.BloomLevel, "%", 3, function(val)
    State.Gameplay.BloomLevel = val
end)

addToggleCard(PageVisual, "Visual", "Modal Background Blur", "Aktifkan blur latar belakang saat menu sedang aktif", true, 4, function(on)
    ModalBlur.Enabled = on
end)

-- [TAB 3: THEME, FONT & LOGO STUDIO]
local function populateThemeStudioCards(targetContainer: ScrollingFrame, tabTag: string)
    addSelectorCard(targetContainer, tabTag, "Premiere Color Theme", "Ganti suasana gradien Premiere & aksen panel", ThemeOrder, State.ThemeIndex, 1, function(_, idx)
        State.ThemeIndex = idx
        broadcastTheme()
        notifyStatus("Tema: " .. ThemeOrder[idx])
    end)

    addSelectorCard(targetContainer, tabTag, "Typography Font Family", "Ubah jenis huruf di seluruh menu & kartu input", { "Sci-Fi Future", "Modern Gotham", "Tactical Code", "Cyber Michroma" }, State.FontIndex, 2, function(fName, idx)
        State.FontIndex = idx
        broadcastFont()
        notifyStatus("Font: " .. fName)
    end)

    addSelectorCard(targetContainer, tabTag, "Font & Selection Scale", "BG pilihan & tinggi kartu menyesuaikan ukuran font", { "Compact (Kecil)", "Standard (Ideal)", "Large (Besar)" }, State.FontSizeIndex, 3, function(sName, idx)
        State.FontSizeIndex = idx
        broadcastFont()
        notifyStatus("Ukuran Font: " .. sName)
    end)

    addSelectorCard(targetContainer, tabTag, "Custom Emblem Logo", "Pilih ikon logo untuk Header, Intro & Shortcut", { "❖ Premiere Core", "⬢ Hexa Matrix", "✦ Astral Nova", "⚡ Cyber Pulse" }, State.LogoIndex, 4, function(lName, idx)
        State.LogoIndex = idx
        State.CustomLogoAsset = ""
        updateLogoVisuals()
        notifyStatus("Logo: " .. lName)
    end)

    addInputCard(targetContainer, tabTag, "Custom Logo Asset ID", "Isi rbxassetid://123456 (kosongkan untuk simbol)", "", "rbxassetid://...", 5, function(text)
        local trimmed = string.gsub(text, "^%s*(.-)%s*$", "%1")
        if trimmed ~= "" and not string.find(trimmed, "rbxassetid://") and tonumber(trimmed) then
            trimmed = "rbxassetid://" .. trimmed
        end
        State.CustomLogoAsset = trimmed
        updateLogoVisuals()
    end)
end

populateThemeStudioCards(PageTheme, "Theme")
populateThemeStudioCards(RightScroll, "")

-- [TAB 4: RESIZE & INTRO]
addActionCard(PageSystem, "System", "Replay Startup Illustration", "Putar ulang animasi ilustrasi loading saat awal mulai", "▶ REPLAY INTRO", 1, function()
    task.spawn(runStartupIllustrationSequence)
end)

addSelectorCard(PageSystem, "System", "Menu Dock Position", "Pindahkan posisi panel ke Kiri, Tengah, atau Kanan", dockModes, 1, 2, function(mode)
    applyLayoutMode(mode)
end)

addSliderCard(PageSystem, "System", "Global UI Scale Multiplier", "Kalibrasi proporsi di atas ukuran sudut kanan bawah", 80, 115, State.UIScalePercent, "%", 3, function(val)
    State.UIScalePercent = val
    updateViewportScale()
end)

addSliderCard(PageSystem, "System", "Master Audio Output", "Tingkat volume utama efek antarmuka dan sekitar", 0, 100, State.Gameplay.MasterVolume, "%", 4, function(val)
    State.Gameplay.MasterVolume = val
end)

selectTab("Combat")
applyLayoutMode("Tri-HUD")
updateLogoVisuals()

-- ================================================================================
-- 13. PROCEDURAL MOTION GRAPHICS ENGINE (RENDERSTEPPED LOOP)
-- ================================================================================
local motionClock = 0

RunService.RenderStepped:Connect(function(dt: number)
    if not State.MotionEnabled then return end
    motionClock += dt

    -- 1. Putar UIGradient pada Border & Logo untuk kesan Premiere Shimmer
    for _, item in ipairs(RotatingGradients) do
        item.Grad.Rotation = (item.Grad.Rotation + dt * item.Speed) % 360
    end

    -- 2. Animasi Ilustrasi Startup Loading jika sedang dalam fase Booting Awal
    if State.IsLoading and StartupOverlay.Visible then
        OuterOrbitRing.Rotation = (motionClock * 24) % 360
        InnerChronoRing.Rotation = -(motionClock * 42) % 360
        DiamondFrameA.Rotation = 45 + math.sin(motionClock * 2.2) * 12
        DiamondFrameB.Rotation = -math.sin(motionClock * 2.2) * 12

        local pulse = (math.sin(motionClock * 4.5) + 1) * 0.5
        ArtAura.Size = UDim2.fromOffset(math.round(195 + pulse * 38), math.round(195 + pulse * 38))
        local laserY = ((motionClock * 0.65) % 1.0)
        IllustrationLaserScan.Position = UDim2.fromScale(0.5, laserY)
        return
    end

    -- 3. Jika Menu Diminimize, jalankan efek Pulse Ring pada Floating Shortcut Icon
    if State.IsMinimized then
        local pulse = (math.sin(motionClock * 3.5) + 1) * 0.5
        ShortcutPulseRing.Size = UDim2.new(1, math.round(pulse * 14), 1, math.round(pulse * 14))
        pulseRingStroke.Transparency = 0.25 + (pulse * 0.7)
        return
    end

    -- 4. Animasi Kilau Garis Atas (TopBar Shimmer Sweep)
    local sweepX = ((motionClock * 0.28) % 1.4) - 0.35
    TopShimmerBar.Position = UDim2.fromScale(sweepX, 0)

    -- 5. Animasi Live Telemetry Equalizer Bars di TopBar
    for idx, bar in ipairs(EqBars) do
        local wave = (math.sin(motionClock * 6.5 + idx * 0.9) + 1) * 0.5
        local h = math.round(6 + wave * 18)
        bar.Size = UDim2.fromOffset(4, h)
    end

    -- 6. Animasi Holographic Scanline di dalam Panel
    local scanY = ((motionClock * 0.22) % 1.3) - 0.15
    for _, sc in ipairs(MotionScanlines) do
        sc.Position = UDim2.fromScale(0, scanY)
    end

    -- 7. Animasi Floating Cyber Geo-Nodes di dalam Panel
    for _, nd in ipairs(MotionNodes) do
        local offsetY = math.sin(motionClock * nd.Speed + nd.Phase) * 0.035
        local offsetX = math.cos(motionClock * (nd.Speed * 0.7) + nd.Phase) * 0.015
        nd.Node.Position = UDim2.fromScale(nd.BaseX + offsetX, nd.BaseY + offsetY)
        nd.Node.Rotation = (motionClock * 28 * nd.Speed) % 360
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

    CenterHeaderTitle.Text = 'FILTER // "' .. SearchInput.Text .. '"'
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
-- 15. ANIMASI MINIMIZE & MAXIMIZE (FOKUS MODAL <-> FLOATING SHORTCUT DEPAN)
-- ================================================================================
local busyAnim = false

local function setHUDMinimized(minimize: boolean)
    if busyAnim or State.IsLoading or State.IsMinimized == minimize then return end
    busyAnim = true
    State.IsMinimized = minimize

    if minimize then
        TweenService:Create(ModalBlur, TweenClose, { Size = 0 }):Play()
        TweenService:Create(ModalBlocker, TweenClose, { BackgroundTransparency = 1 }):Play()
        local closeTw = TweenService:Create(HUDAnimScale, TweenClose, { Scale = 0 })
        closeTw:Play()
        closeTw.Completed:Wait()

        HUDCanvas.Visible = false
        ModalBlocker.Visible = false

        FloatingShortcut.Visible = true
        FloatingShortcut.Size = UDim2.fromOffset(12, 12)
        TweenService:Create(FloatingShortcut, TweenSpring, { Size = UDim2.fromOffset(68, 68) }):Play()
    else
        local hideShort = TweenService:Create(FloatingShortcut, TweenFast, { Size = UDim2.fromOffset(12, 12) })
        hideShort:Play()
        hideShort.Completed:Wait()
        FloatingShortcut.Visible = false

        ModalBlocker.Visible = true
        ModalBlocker.BackgroundTransparency = 1
        HUDCanvas.Visible = true
        HUDAnimScale.Scale = 0.72

        TweenService:Create(ModalBlur, TweenSmooth, { Size = 14 }):Play()
        TweenService:Create(ModalBlocker, TweenSmooth, { BackgroundTransparency = 0.35 }):Play()
        TweenService:Create(HUDAnimScale, TweenSpring, { Scale = 1 }):Play()
        playTabCascadeMotion(State.CurrentTab)
    end

    task.wait(0.08)
    busyAnim = false
end

MinimizeRedBtn.MouseButton1Click:Connect(function()
    setHUDMinimized(true)
end)

FloatingShortcut.MouseEnter:Connect(function()
    TweenService:Create(FloatingShortcut, TweenFast, { Size = UDim2.fromOffset(74, 74) }):Play()
end)
FloatingShortcut.MouseLeave:Connect(function()
    TweenService:Create(FloatingShortcut, TweenFast, { Size = UDim2.fromOffset(68, 68) }):Play()
end)

makeDraggable(TopCommandBar, HUDCanvas, nil)
makeDraggable(FloatingShortcut, FloatingShortcut, function()
    setHUDMinimized(false)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        setHUDMinimized(not State.IsMinimized)
    end
end)

-- // JALANKAN ILUSTRASI LOADING OTOMATIS SAAT SCRIPT PERTAMA KALI DIMULAI
task.spawn(runStartupIllustrationSequence)
