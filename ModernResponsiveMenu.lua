--[[
    ================================================================================
    MODERN RESPONSIVE ROBLOX UI MENU — "AETHER OBSIDIAN" THEME
    ================================================================================
    Arsitektur   : 100% Procedural Luau LocalScript (Tanpa perlu membuat objek manual)
    Penempatan   : StarterPlayer -> StarterPlayerScripts (atau StarterGui)
    Fitur Utama  :
      1. Auto-Responsive Scale (UIScale dinamis + UIAspectRatioConstraint + UDim2 Scale)
         Menyesuaikan layar PC (1080p/4K), Tablet, dan Smartphone secara proporsional.
      2. Minimize & Maximize ke Floating Popup Icon (Draggable + Spring/Back Tweening)
         Pintasan Keyboard: Tombol [RightControl] atau klik tombol "-" / ikon mengambang.
      3. Modern Top Bar Menu (Judul, Subtitle Badge, Search Filter Real-time, Minimize)
      4. Modern Side Menu Navigation (Tab Kategori dengan indikator pill aktif & hover)
      5. Interactive Input Cards di dalam ScrollingFrame:
         - Toggle Switch Card (On/Off dengan animasi knob)
         - Interactive Slider Bar Card (Drag nilai min-max secara real-time)
         - Text / Number Input Card (TextBox dengan fokus stroke & validasi)
         - Cycle / Preset Selector Card (Pilihan mode dengan klik berputar)
         - Action Button Card (Tombol eksekusi cepat dengan ripple/press feedback)
    ================================================================================
]]

-- // SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- // Hapus UI lama jika script dijalankan ulang
local existingGui = PlayerGui:FindFirstChild("AetherResponsiveMenu")
if existingGui then
    existingGui:Destroy()
end

-- // THEME CONFIGURATION ("Aether Obsidian" - Modern Dark Slate & Electric Cyan)
local Theme = {
    Background      = Color3.fromRGB(15, 18, 26),    -- #0F121A Utama
    Sidebar         = Color3.fromRGB(20, 24, 34),    -- #141822 Panel Samping & Topbar
    Card            = Color3.fromRGB(26, 32, 44),    -- #1A202C Kartu Input Default
    CardHover       = Color3.fromRGB(32, 39, 54),    -- #202736 Kartu Saat Disorot
    InputBg         = Color3.fromRGB(13, 16, 23),    -- #0D1017 Latar Input & Slider Track
    Accent          = Color3.fromRGB(56, 189, 248),  -- #38BDF8 Electric Sky Cyan
    AccentSecondary = Color3.fromRGB(99, 102, 241),  -- #6366F1 Indigo Glow
    Success         = Color3.fromRGB(52, 211, 153),  -- #34D399 Emerald
    Warning         = Color3.fromRGB(251, 191, 36),  -- #FBBF24 Amber
    TextPrimary     = Color3.fromRGB(248, 250, 252), -- #F8FAFC Teks Utama
    TextSecondary   = Color3.fromRGB(148, 163, 184), -- #94A3B8 Teks Deskripsi
    TextMuted       = Color3.fromRGB(100, 116, 139), -- #64748B Teks Placeholder
    Stroke          = Color3.fromRGB(45, 55, 72),    -- #2D3748 Garis Tepi Halus
    FontBold        = Enum.Font.GothamBold,
    FontMedium      = Enum.Font.GothamMedium,
    FontRegular     = Enum.Font.Gotham,
}

-- // TWEEN PRESETS
local TweenFast   = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenSmooth = TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TweenOpen   = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TweenClose  = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

-- // STATE DATA (Menyimpan nilai seluruh input agar mudah dihubungkan ke sistem game)
local MenuState = {
    IsMinimized = false,
    CurrentTab  = "General",
    Settings    = {
        -- General
        PlayerNameTag   = LocalPlayer.DisplayName,
        FOVValue        = 75,
        SprintToggle    = true,
        CameraMode      = "Default (Smooth)",
        -- Graphics
        ShadowQuality   = "High",
        BloomIntensity  = 60,
        DynamicLighting = true,
        MaxFPSCap       = "120",
        -- Audio & UI
        MasterVolume    = 80,
        SFXVolume       = 70,
        MuteOnMinimize  = false,
        UIScaleOverride = 100,
        -- Controls
        MouseSens       = 45,
        AutoJumpMobile  = true,
        CustomBindCode  = "RightControl",
    }
}

-- // HELPER FUNCTIONS
local function create(className: string, properties: { [string]: any }, children: { Instance }?): any
    local inst = Instance.new(className)
    for prop, val in pairs(properties) do
        (inst :: any)[prop] = val
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    return inst
end

local function addCorner(parent: Instance, radius: number): UICorner
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius),
        Parent = parent
    })
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

-- // DRAGGABLE CONTROLLER (Mendukung Mouse PC & Touch Mobile)
local function makeDraggable(dragHandle: GuiObject, targetFrame: GuiObject, onClickCallback: (() -> ())?)
    local dragging = false
    local dragInput: InputObject? = nil
    local dragStart = Vector3.zero
    local startPos = UDim2.new()
    local movedDistance = 0

    dragHandle.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
            movedDistance = 0

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if movedDistance < 6 and onClickCallback then
                        onClickCallback()
                    end
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input: InputObject)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            movedDistance = delta.Magnitude
            local targetPos = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
            TweenService:Create(targetFrame, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = targetPos
            }):Play()
        end
    end)
end

-- ================================================================================
-- 1. SCREEN GUI & RESPONSIVE SCALE ENGINE
-- ================================================================================
local ScreenGui = create("ScreenGui", {
    Name = "AetherResponsiveMenu",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = PlayerGui
})

-- UIScale Global yang dihitung secara dinamis berdasarkan resolusi layar
local ResponsiveScale = create("UIScale", {
    Name = "ResponsiveUIScale",
    Scale = 1,
    Parent = ScreenGui
})

local function updateResponsiveScale()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    -- Basis desain referensi: 1366 x 768
    local scaleX = viewport.X / 1366
    local scaleY = viewport.Y / 768
    local rawScale = math.min(scaleX, scaleY)
    -- Clamp agar di HP kecil tidak terlalu mungil (min 0.62) dan di monitor 4K tidak raksasa (max 1.35)
    local userFactor = (MenuState.Settings.UIScaleOverride or 100) / 100
    ResponsiveScale.Scale = math.clamp(rawScale * userFactor, 0.58, 1.4)
end

if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
end
updateResponsiveScale()

-- ================================================================================
-- 2. FLOATING POPUP ICON (TAMPIL SAAT MENU DI-MINIMIZE)
-- ================================================================================
local FloatingPopup = create("Frame", {
    Name = "FloatingPopupIcon",
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0.02, 0, 0.5, 0),
    Size = UDim2.fromOffset(58, 58),
    BackgroundColor3 = Theme.Sidebar,
    Visible = false,
    Parent = ScreenGui
})
addCorner(FloatingPopup, 16)
local popupStroke = addStroke(FloatingPopup, Theme.Accent, 2, 0.15)

-- Efek Gradien Halus pada Popup Icon
create("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 45, 65)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 22, 32))
    }),
    Rotation = 45,
    Parent = FloatingPopup
})

-- Ikon Menu di dalam Floating Popup
local PopupIconLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0.68, 0),
    Position = UDim2.new(0, 0, 0.04, 0),
    BackgroundTransparency = 1,
    Text = "❖",
    TextColor3 = Theme.Accent,
    Font = Theme.FontBold,
    TextSize = 26,
    Parent = FloatingPopup
})

local PopupSubLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0.28, 0),
    Position = UDim2.new(0, 0, 0.66, 0),
    BackgroundTransparency = 1,
    Text = "MENU",
    TextColor3 = Theme.TextSecondary,
    Font = Theme.FontBold,
    TextSize = 10,
    Parent = FloatingPopup
})

-- Indikator Titik Online/Aktif pada Pojok Popup
local PopupBadge = create("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -4, 0, 4),
    Size = UDim2.fromOffset(10, 10),
    BackgroundColor3 = Theme.Success,
    Parent = FloatingPopup
})
addCorner(PopupBadge, 99)

-- ================================================================================
-- 3. MAIN WINDOW CONTAINER (PANEL UTAMA)
-- ================================================================================
local MainWindow = create("Frame", {
    Name = "MainWindow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(760, 470),
    BackgroundColor3 = Theme.Background,
    ClipsDescendants = true,
    Parent = ScreenGui
})
addCorner(MainWindow, 14)
addStroke(MainWindow, Theme.Stroke, 1.5, 0)

-- Menjaga proporsi rasio aspek di berbagai layar
create("UIAspectRatioConstraint", {
    AspectRatio = 760 / 470,
    AspectType = Enum.AspectType.FitWithinMaxSize,
    DominantAxis = Enum.DominantAxis.Width,
    Parent = MainWindow
})

-- UIScale internal khusus animasi Minimize/Maximize
local WindowScale = create("UIScale", {
    Scale = 1,
    Parent = MainWindow
})

-- ================================================================================
-- 4. MODERN TOP BAR MENU (HEADER, SEARCH BAR, MINIMIZE BUTTON)
-- ================================================================================
local TopBar = create("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 56),
    BackgroundColor3 = Theme.Sidebar,
    BorderSizePixel = 0,
    Parent = MainWindow
})
addCorner(TopBar, 14)

-- Penutup sudut bawah TopBar agar menyatu rapi dengan body
create("Frame", {
    Size = UDim2.new(1, 0, 0, 14),
    Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = Theme.Sidebar,
    BorderSizePixel = 0,
    Parent = TopBar
})

-- Garis pemisah bawah TopBar
create("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = Theme.Stroke,
    BorderSizePixel = 0,
    Parent = TopBar
})

-- Brand Logo & Judul
local BrandBadge = create("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 16, 0.5, 0),
    Size = UDim2.fromOffset(34, 34),
    BackgroundColor3 = Theme.Card,
    Parent = TopBar
})
addCorner(BrandBadge, 9)
addStroke(BrandBadge, Theme.Accent, 1.2, 0.3)

create("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "❖",
    TextColor3 = Theme.Accent,
    Font = Theme.FontBold,
    TextSize = 18,
    Parent = BrandBadge
})

create("TextLabel", {
    Position = UDim2.new(0, 60, 0, 10),
    Size = UDim2.fromOffset(200, 20),
    BackgroundTransparency = 1,
    Text = "AETHER CONTROL HUB",
    TextColor3 = Theme.TextPrimary,
    Font = Theme.FontBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = TopBar
})

create("TextLabel", {
    Position = UDim2.new(0, 60, 0, 29),
    Size = UDim2.fromOffset(220, 16),
    BackgroundTransparency = 1,
    Text = "v2.4 • Responsive Scale UI",
    TextColor3 = Theme.TextSecondary,
    Font = Theme.FontRegular,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = TopBar
})

-- Top Bar Search Input Card (Filter kartu secara real-time)
local SearchContainer = create("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -110, 0.5, 0),
    Size = UDim2.fromOffset(220, 34),
    BackgroundColor3 = Theme.InputBg,
    Parent = TopBar
})
addCorner(SearchContainer, 8)
local searchStroke = addStroke(SearchContainer, Theme.Stroke, 1, 0)

create("TextLabel", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 10, 0.5, 0),
    Size = UDim2.fromOffset(18, 18),
    BackgroundTransparency = 1,
    Text = "⌕",
    TextColor3 = Theme.TextSecondary,
    Font = Theme.FontBold,
    TextSize = 16,
    Parent = SearchContainer
})

local SearchBox = create("TextBox", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 32, 0.5, 0),
    Size = UDim2.new(1, -40, 1, -6),
    BackgroundTransparency = 1,
    Text = "",
    PlaceholderText = "Cari pengaturan...",
    PlaceholderColor3 = Theme.TextMuted,
    TextColor3 = Theme.TextPrimary,
    Font = Theme.FontRegular,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    Parent = SearchContainer
})

SearchBox.Focused:Connect(function()
    TweenService:Create(searchStroke, TweenFast, { Color = Theme.Accent }):Play()
end)
SearchBox.FocusLost:Connect(function()
    TweenService:Create(searchStroke, TweenFast, { Color = Theme.Stroke }):Play()
end)

-- Tombol Minimize (Mengecilkan menu ke Floating Icon Popup)
local MinimizeBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -16, 0.5, 0),
    Size = UDim2.fromOffset(82, 34),
    BackgroundColor3 = Theme.Card,
    Text = "—  Minimize",
    TextColor3 = Theme.TextPrimary,
    Font = Theme.FontMedium,
    TextSize = 12,
    AutoButtonColor = false,
    Parent = TopBar
})
addCorner(MinimizeBtn, 8)
local minBtnStroke = addStroke(MinimizeBtn, Theme.Stroke, 1, 0)

MinimizeBtn.MouseEnter:Connect(function()
    TweenService:Create(MinimizeBtn, TweenFast, { BackgroundColor3 = Theme.CardHover }):Play()
    TweenService:Create(minBtnStroke, TweenFast, { Color = Theme.Accent }):Play()
end)
MinimizeBtn.MouseLeave:Connect(function()
    TweenService:Create(MinimizeBtn, TweenFast, { BackgroundColor3 = Theme.Card }):Play()
    TweenService:Create(minBtnStroke, TweenFast, { Color = Theme.Stroke }):Play()
end)

-- ================================================================================
-- 5. BODY LAYOUT: SIDE MENU + CONTENT AREA
-- ================================================================================
local BodyFrame = create("Frame", {
    Name = "BodyFrame",
    Position = UDim2.new(0, 0, 0, 56),
    Size = UDim2.new(1, 0, 1, -56),
    BackgroundTransparency = 1,
    Parent = MainWindow
})

-- SIDE MENU PANEL (Kiri)
local SideMenu = create("Frame", {
    Name = "SideMenu",
    Size = UDim2.new(0, 195, 1, 0),
    BackgroundColor3 = Theme.Sidebar,
    BorderSizePixel = 0,
    Parent = BodyFrame
})

-- Garis pemisah kanan SideMenu
create("Frame", {
    Position = UDim2.new(1, -1, 0, 0),
    Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = Theme.Stroke,
    BorderSizePixel = 0,
    Parent = SideMenu
})

-- Header Kategori di SideMenu
create("TextLabel", {
    Position = UDim2.new(0, 16, 0, 14),
    Size = UDim2.new(1, -32, 0, 16),
    BackgroundTransparency = 1,
    Text = "CATEGORIES",
    TextColor3 = Theme.TextMuted,
    Font = Theme.FontBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = SideMenu
})

local TabListContainer = create("Frame", {
    Position = UDim2.new(0, 12, 0, 36),
    Size = UDim2.new(1, -24, 1, -110),
    BackgroundTransparency = 1,
    Parent = SideMenu
})

create("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = TabListContainer
})

-- Footer Info User & Shortcut di bagian bawah SideMenu
local ProfileCard = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -12),
    Size = UDim2.new(1, -24, 0, 56),
    BackgroundColor3 = Theme.Card,
    Parent = SideMenu
})
addCorner(ProfileCard, 10)
addStroke(ProfileCard, Theme.Stroke, 1, 0.2)

create("TextLabel", {
    Position = UDim2.new(0, 12, 0, 10),
    Size = UDim2.new(1, -24, 0, 18),
    BackgroundTransparency = 1,
    Text = "@" .. LocalPlayer.Name,
    TextColor3 = Theme.TextPrimary,
    Font = Theme.FontBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = ProfileCard
})

local StatusFooterLabel = create("TextLabel", {
    Position = UDim2.new(0, 12, 0, 29),
    Size = UDim2.new(1, -24, 0, 16),
    BackgroundTransparency = 1,
    Text = "Keybind: [RightCtrl]",
    TextColor3 = Theme.Accent,
    Font = Theme.FontRegular,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = ProfileCard
})

-- CONTENT AREA (Kanan)
local ContentPanel = create("Frame", {
    Name = "ContentPanel",
    Position = UDim2.new(0, 195, 0, 0),
    Size = UDim2.new(1, -195, 1, 0),
    BackgroundTransparency = 1,
    Parent = BodyFrame
})

-- Header Bar Kategori Aktif di atas Content
local ContentHeader = create("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundTransparency = 1,
    Parent = ContentPanel
})

local CategoryTitleLabel = create("TextLabel", {
    Position = UDim2.new(0, 22, 0, 14),
    Size = UDim2.new(0.6, 0, 0, 22),
    BackgroundTransparency = 1,
    Text = "General Settings",
    TextColor3 = Theme.TextPrimary,
    Font = Theme.FontBold,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = ContentHeader
})

local ToastNotification = create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -22, 0.5, 2),
    Size = UDim2.new(0.45, 0, 0, 20),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Theme.Success,
    Font = Theme.FontMedium,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextTransparency = 1,
    Parent = ContentHeader
})

local function showToast(message: string)
    ToastNotification.Text = "✓ " .. message
    ToastNotification.TextTransparency = 0
    task.spawn(function()
        task.wait(1.6)
        TweenService:Create(ToastNotification, TweenSmooth, { TextTransparency = 1 }):Play()
    end)
end

-- Container Halaman Kategori
local PagesFolder = create("Frame", {
    Position = UDim2.new(0, 0, 0, 44),
    Size = UDim2.new(1, 0, 1, -44),
    BackgroundTransparency = 1,
    Parent = ContentPanel
})

-- ================================================================================
-- 6. KOMPONEN BUILDER: SIDE MENU TABS & INPUT CARDS
-- ================================================================================
local TabRegistry: { [string]: { Button: TextButton, Indicator: Frame, Page: ScrollingFrame, Title: string } } = {}
local AllCards: { { Frame: Frame, SearchText: string, TabName: string } } = {}

local function switchTab(tabName: string)
    MenuState.CurrentTab = tabName
    for name, data in pairs(TabRegistry) do
        local isSelected = (name == tabName)
        data.Page.Visible = isSelected
        if isSelected then
            CategoryTitleLabel.Text = data.Title
            TweenService:Create(data.Button, TweenFast, {
                BackgroundColor3 = Theme.Card,
                TextColor3 = Theme.TextPrimary
            }):Play()
            TweenService:Create(data.Indicator, TweenFast, {
                Size = UDim2.new(0, 4, 0, 20),
                BackgroundTransparency = 0
            }):Play()
        else
            TweenService:Create(data.Button, TweenFast, {
                BackgroundColor3 = Theme.Sidebar,
                TextColor3 = Theme.TextSecondary
            }):Play()
            TweenService:Create(data.Indicator, TweenFast, {
                Size = UDim2.new(0, 4, 0, 0),
                BackgroundTransparency = 1
            }):Play()
        end
    end
end

local function createCategoryTab(tabId: string, icon: string, label: string, fullTitle: string, order: number): ScrollingFrame
    local tabBtn = create("TextButton", {
        Name = tabId .. "Tab",
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Theme.Sidebar,
        Text = "      " .. icon .. "   " .. label,
        TextColor3 = Theme.TextSecondary,
        Font = Theme.FontMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        Parent = TabListContainer
    })
    addCorner(tabBtn, 8)

    local activeIndicator = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.new(0, 4, 0, 0),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 1,
        Parent = tabBtn
    })
    addCorner(activeIndicator, 99)

    local page = create("ScrollingFrame", {
        Name = tabId .. "Page",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        Parent = PagesFolder
    })
    addPadding(page, 4, 18, 22, 22)

    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page
    })

    tabBtn.MouseButton1Click:Connect(function()
        SearchBox.Text = ""
        switchTab(tabId)
    end)

    tabBtn.MouseEnter:Connect(function()
        if MenuState.CurrentTab ~= tabId then
            TweenService:Create(tabBtn, TweenFast, { BackgroundColor3 = Theme.CardHover }):Play()
        end
    end)

    tabBtn.MouseLeave:Connect(function()
        if MenuState.CurrentTab ~= tabId then
            TweenService:Create(tabBtn, TweenFast, { BackgroundColor3 = Theme.Sidebar }):Play()
        end
    end)

    TabRegistry[tabId] = {
        Button = tabBtn,
        Indicator = activeIndicator,
        Page = page,
        Title = fullTitle
    }

    return page
end

-- Base Card Kerangka Dasar
local function createBaseCard(parentPage: ScrollingFrame, tabName: string, title: string, subtitle: string, height: number, order: number): Frame
    local card = create("Frame", {
        Name = title .. "Card",
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Theme.Card,
        Parent = parentPage
    })
    addCorner(card, 10)
    local cardStroke = addStroke(card, Theme.Stroke, 1, 0.15)

    create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 12),
        Size = UDim2.new(0.58, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        Font = Theme.FontBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 32),
        Size = UDim2.new(0.58, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = subtitle,
        TextColor3 = Theme.TextSecondary,
        Font = Theme.FontRegular,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    card.MouseEnter:Connect(function()
        TweenService:Create(card, TweenFast, { BackgroundColor3 = Theme.CardHover }):Play()
        TweenService:Create(cardStroke, TweenFast, { Color = Theme.Accent, Transparency = 0.4 }):Play()
    end)
    card.MouseLeave:Connect(function()
        TweenService:Create(card, TweenFast, { BackgroundColor3 = Theme.Card }):Play()
        TweenService:Create(cardStroke, TweenFast, { Color = Theme.Stroke, Transparency = 0.15 }):Play()
    end)

    table.insert(AllCards, {
        Frame = card,
        SearchText = string.lower(title .. " " .. subtitle),
        TabName = tabName
    })

    return card
end

-- CARD TYPE 1: TOGGLE SWITCH CARD
local function createToggleCard(parentPage: ScrollingFrame, tabName: string, title: string, subtitle: string, defaultVal: boolean, order: number, callback: (boolean) -> ())
    local card = createBaseCard(parentPage, tabName, title, subtitle, 60, order)
    local state = defaultVal

    local switchBg = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(48, 26),
        BackgroundColor3 = state and Theme.Accent or Theme.InputBg,
        Text = "",
        AutoButtonColor = false,
        Parent = card
    })
    addCorner(switchBg, 99)
    addStroke(switchBg, Theme.Stroke, 1, 0.2)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = state and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(20, 20),
        BackgroundColor3 = Theme.TextPrimary,
        Parent = switchBg
    })
    addCorner(knob, 99)

    switchBg.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(switchBg, TweenFast, {
            BackgroundColor3 = state and Theme.Accent or Theme.InputBg
        }):Play()
        TweenService:Create(knob, TweenFast, {
            Position = state and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        }):Play()
        callback(state)
        showToast(title .. ": " .. (state and "ON" or "OFF"))
    end)
end

-- CARD TYPE 2: INTERACTIVE BAR SLIDER CARD
local function createSliderCard(parentPage: ScrollingFrame, tabName: string, title: string, subtitle: string, minVal: number, maxVal: number, defaultVal: number, suffix: string, order: number, callback: (number) -> ())
    local card = createBaseCard(parentPage, tabName, title, subtitle, 76, order)
    local currentVal = math.clamp(defaultVal, minVal, maxVal)

    local valueBadge = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 12),
        Size = UDim2.fromOffset(80, 20),
        BackgroundTransparency = 1,
        Text = tostring(currentVal) .. suffix,
        TextColor3 = Theme.Accent,
        Font = Theme.FontBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = card
    })

    local sliderTrack = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -14),
        Size = UDim2.new(1, -32, 0, 8),
        BackgroundColor3 = Theme.InputBg,
        Parent = card
    })
    addCorner(sliderTrack, 99)

    local initialRatio = (currentVal - minVal) / (maxVal - minVal)
    local sliderFill = create("Frame", {
        Size = UDim2.new(initialRatio, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        Parent = sliderTrack
    })
    addCorner(sliderFill, 99)

    local sliderKnob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Theme.TextPrimary,
        Parent = sliderFill
    })
    addCorner(sliderKnob, 99)

    local isSliding = false

    local function updateFromInput(inputPos: Vector3)
        local trackPos = sliderTrack.AbsolutePosition.X
        local trackSize = sliderTrack.AbsoluteSize.X
        if trackSize <= 0 then return end
        local ratio = math.clamp((inputPos.X - trackPos) / trackSize, 0, 1)
        currentVal = math.round(minVal + (maxVal - minVal) * ratio)
        valueBadge.Text = tostring(currentVal) .. suffix
        TweenService:Create(sliderFill, TweenInfo.new(0.06, Enum.EasingStyle.Linear), {
            Size = UDim2.new(ratio, 0, 1, 0)
        }):Play()
        callback(currentVal)
    end

    sliderTrack.InputBegan:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isSliding = true
            updateFromInput(input.Position)
        end
    end)

    UserInputService.InputChanged:Connect(function(input: InputObject)
        if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input.Position)
        end
    end)

    UserInputService.InputEnded:Connect(function(input: InputObject)
        if isSliding and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isSliding = false
            showToast(title .. " -> " .. tostring(currentVal) .. suffix)
        end
    end)
end

-- CARD TYPE 3: TEXT / VALUE INPUT CARD
local function createInputCard(parentPage: ScrollingFrame, tabName: string, title: string, subtitle: string, defaultText: string, placeholder: string, order: number, callback: (string) -> ())
    local card = createBaseCard(parentPage, tabName, title, subtitle, 62, order)

    local inputBox = create("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(165, 34),
        BackgroundColor3 = Theme.InputBg,
        Text = defaultText,
        PlaceholderText = placeholder,
        PlaceholderColor3 = Theme.TextMuted,
        TextColor3 = Theme.TextPrimary,
        Font = Theme.FontMedium,
        TextSize = 12,
        ClearTextOnFocus = false,
        Parent = card
    })
    addCorner(inputBox, 8)
    local boxStroke = addStroke(inputBox, Theme.Stroke, 1, 0)

    inputBox.Focused:Connect(function()
        TweenService:Create(boxStroke, TweenFast, { Color = Theme.Accent }):Play()
    end)

    inputBox.FocusLost:Connect(function()
        TweenService:Create(boxStroke, TweenFast, { Color = Theme.Stroke }):Play()
        callback(inputBox.Text)
        showToast(title .. " disimpan")
    end)
end

-- CARD TYPE 4: CYCLE / PRESET SELECTOR CARD
local function createSelectorCard(parentPage: ScrollingFrame, tabName: string, title: string, subtitle: string, options: { string }, defaultIndex: number, order: number, callback: (string) -> ())
    local card = createBaseCard(parentPage, tabName, title, subtitle, 62, order)
    local idx = defaultIndex

    local selectorBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(165, 34),
        BackgroundColor3 = Theme.InputBg,
        Text = "◂  " .. options[idx] .. "  ▸",
        TextColor3 = Theme.Accent,
        Font = Theme.FontMedium,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = card
    })
    addCorner(selectorBtn, 8)
    local selStroke = addStroke(selectorBtn, Theme.Stroke, 1, 0)

    selectorBtn.MouseButton1Click:Connect(function()
        idx = (idx % #options) + 1
        local chosen = options[idx]
        selectorBtn.Text = "◂  " .. chosen .. "  ▸"
        callback(chosen)
        showToast(title .. ": " .. chosen)
    end)

    selectorBtn.MouseEnter:Connect(function()
        TweenService:Create(selStroke, TweenFast, { Color = Theme.Accent }):Play()
    end)
    selectorBtn.MouseLeave:Connect(function()
        TweenService:Create(selStroke, TweenFast, { Color = Theme.Stroke }):Play()
    end)
end

-- CARD TYPE 5: ACTION BUTTON CARD
local function createActionCard(parentPage: ScrollingFrame, tabName: string, title: string, subtitle: string, buttonLabel: string, order: number, callback: () -> ())
    local card = createBaseCard(parentPage, tabName, title, subtitle, 62, order)

    local actBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(130, 34),
        BackgroundColor3 = Theme.Accent,
        Text = buttonLabel,
        TextColor3 = Theme.Background,
        Font = Theme.FontBold,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = card
    })
    addCorner(actBtn, 8)

    actBtn.MouseButton1Click:Connect(function()
        TweenService:Create(actBtn, TweenInfo.new(0.08), { Size = UDim2.fromOffset(124, 30) }):Play()
        task.delay(0.09, function()
            TweenService:Create(actBtn, TweenFast, { Size = UDim2.fromOffset(130, 34) }):Play()
        end)
        callback()
    end)
end

-- ================================================================================
-- 7. POPULASI KATEGORI & INPUT CARDS
-- ================================================================================
local PageGeneral  = createCategoryTab("General",  "⚙", "General",  "General & Character Settings", 1)
local PageGraphics = createCategoryTab("Graphics", "✦", "Graphics", "Visuals & Performance", 2)
local PageAudio    = createCategoryTab("Audio",    "♫", "Audio & UI", "Audio & Responsive Scale", 3)
local PageControls = createCategoryTab("Controls", "⌘", "Controls", "Input & Keybind Settings", 4)

-- [TAB 1: GENERAL]
createInputCard(PageGeneral, "General", "Custom Display Tag", "Ubah nama tag yang tampil pada HUD karakter", MenuState.Settings.PlayerNameTag, "Masukkan tag...", 1, function(val)
    MenuState.Settings.PlayerNameTag = val
end)

createSliderCard(PageGeneral, "General", "Camera Field of View (FOV)", "Mengatur sudut pandang kamera secara langsung", 60, 110, MenuState.Settings.FOVValue, "°", 2, function(val)
    MenuState.Settings.FOVValue = val
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = val
    end
end)

createToggleCard(PageGeneral, "General", "Auto Sprint Mode", "Aktifkan lari cepat otomatis saat bergerak maju", MenuState.Settings.SprintToggle, 3, function(state)
    MenuState.Settings.SprintToggle = state
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = state and 22 or 16
    end
end)

createSelectorCard(PageGeneral, "General", "Camera Follow Style", "Pilih perilaku transisi kamera saat karakter berbelok", { "Default (Smooth)", "Action Cinematic", "Locked Combat" }, 1, 4, function(choice)
    MenuState.Settings.CameraMode = choice
end)

-- [TAB 2: GRAPHICS]
createSelectorCard(PageGraphics, "Graphics", "Shadow Preset Quality", "Sesuaikan ketajaman bayangan untuk menghemat FPS", { "Low", "Medium", "High", "Ultra" }, 3, 1, function(choice)
    MenuState.Settings.ShadowQuality = choice
end)

createSliderCard(PageGraphics, "Graphics", "Atmosphere Bloom Intensity", "Mengatur tingkat pendar cahaya objek neon", 0, 100, MenuState.Settings.BloomIntensity, "%", 2, function(val)
    MenuState.Settings.BloomIntensity = val
end)

createToggleCard(PageGraphics, "Graphics", "Dynamic Environment Lighting", "Aktifkan pantulan cahaya langit secara real-time", MenuState.Settings.DynamicLighting, 3, function(state)
    MenuState.Settings.DynamicLighting = state
end)

createInputCard(PageGraphics, "Graphics", "Target FPS Limit Note", "Masukkan target batas frame rate referensi", MenuState.Settings.MaxFPSCap, "Contoh: 60 / 144", 4, function(val)
    MenuState.Settings.MaxFPSCap = val
end)

-- [TAB 3: AUDIO & UI SCALE]
createSliderCard(PageAudio, "Audio", "UI Responsive Scale Multiplier", "Perbesar/perkecil seluruh menu sesuai kenyamanan layar", 75, 125, MenuState.Settings.UIScaleOverride, "%", 1, function(val)
    MenuState.Settings.UIScaleOverride = val
    updateResponsiveScale()
end)

createSliderCard(PageAudio, "Audio", "Master Audio Volume", "Kontrol tingkat volume utama seluruh suara di game", 0, 100, MenuState.Settings.MasterVolume, "%", 2, function(val)
    MenuState.Settings.MasterVolume = val
end)

createToggleCard(PageAudio, "Audio", "Mute Ambient Saat Minimize", "Redam suara latar otomatis ketika menu sedang diminimize", MenuState.Settings.MuteOnMinimize, 3, function(state)
    MenuState.Settings.MuteOnMinimize = state
end)

-- [TAB 4: CONTROLS]
createSliderCard(PageControls, "Controls", "Camera Look Sensitivity", "Kecepatan putaran kamera saat menggerakkan mouse/layar", 10, 100, MenuState.Settings.MouseSens, "%", 1, function(val)
    MenuState.Settings.MouseSens = val
end)

createToggleCard(PageControls, "Controls", "Touch Auto-Jump Assist", "Bantu lompat otomatis saat bermain di perangkat Mobile", MenuState.Settings.AutoJumpMobile, 2, function(state)
    MenuState.Settings.AutoJumpMobile = state
end)

createActionCard(PageControls, "Controls", "Reset All Preferences", "Kembalikan FOV dan kecepatan karakter ke nilai standar", "Reset Default", 3, function()
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = 70
    end
    showToast("Pengaturan dikembalikan ke standar")
end)

-- Set Tab Awal
switchTab("General")

-- ================================================================================
-- 8. LOGIKA SEARCH BAR (FILTER KARTU INPUT REAL-TIME)
-- ================================================================================
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = string.lower( string.gsub(SearchBox.Text, "^%s*(.-)%s*$", "%1") )
    if query == "" then
        for _, item in ipairs(AllCards) do
            item.Frame.Visible = true
        end
        switchTab(MenuState.CurrentTab)
        return
    end

    CategoryTitleLabel.Text = 'Hasil Pencarian: "' .. SearchBox.Text .. '"'
    -- Tampilkan kartu yang cocok di halaman aktif, atau pindahkan visibilitas halaman
    for name, tabData in pairs(TabRegistry) do
        local hasMatchInTab = false
        for _, item in ipairs(AllCards) do
            if item.TabName == name then
                local matched = string.find(item.SearchText, query, 1, true) ~= nil
                item.Frame.Visible = matched
                if matched then
                    hasMatchInTab = true
                end
            end
        end
        tabData.Page.Visible = (name == MenuState.CurrentTab) or hasMatchInTab
        -- Hanya tampilkan 1 halaman pertama yang memiliki kecocokan agar tidak tumpuk
    end

    local shownOnePage = false
    for _, tabData in pairs(TabRegistry) do
        if tabData.Page.Visible and not shownOnePage then
            shownOnePage = true
        else
            tabData.Page.Visible = false
        end
    end
end)

-- ================================================================================
-- 9. ANIMASI MINIMIZE & MAXIMIZE (POPUP ICON <-> FULL WINDOW)
-- ================================================================================
local isAnimating = false

local function setMinimized(minimize: boolean)
    if isAnimating or MenuState.IsMinimized == minimize then return end
    isAnimating = true
    MenuState.IsMinimized = minimize

    if minimize then
        -- Mengecilkan MainWindow lalu memunculkan FloatingPopup Icon
        local shrinkTween = TweenService:Create(WindowScale, TweenClose, { Scale = 0 })
        shrinkTween:Play()
        shrinkTween.Completed:Wait()
        MainWindow.Visible = false

        FloatingPopup.Visible = true
        FloatingPopup.Size = UDim2.fromOffset(10, 10)
        TweenService:Create(FloatingPopup, TweenOpen, { Size = UDim2.fromOffset(58, 58) }):Play()
    else
        -- Menyembunyikan FloatingPopup Icon lalu membesarkan MainWindow
        local hidePopup = TweenService:Create(FloatingPopup, TweenFast, { Size = UDim2.fromOffset(10, 10) })
        hidePopup:Play()
        hidePopup.Completed:Wait()
        FloatingPopup.Visible = false

        MainWindow.Visible = true
        WindowScale.Scale = 0.65
        TweenService:Create(WindowScale, TweenOpen, { Scale = 1 }):Play()
    end

    task.wait(0.1)
    isAnimating = false
end

MinimizeBtn.MouseButton1Click:Connect(function()
    setMinimized(true)
end)

-- Efek Hover pada Floating Popup Icon
FloatingPopup.MouseEnter:Connect(function()
    TweenService:Create(FloatingPopup, TweenFast, { Size = UDim2.fromOffset(64, 64) }):Play()
    TweenService:Create(popupStroke, TweenFast, { Color = Theme.TextPrimary }):Play()
end)
FloatingPopup.MouseLeave:Connect(function()
    TweenService:Create(FloatingPopup, TweenFast, { Size = UDim2.fromOffset(58, 58) }):Play()
    TweenService:Create(popupStroke, TweenFast, { Color = Theme.Accent }):Play()
end)

-- Buat TopBar bisa di-drag untuk menggeser MainWindow, dan FloatingPopup bisa di-drag + diklik untuk Maximize
makeDraggable(TopBar, MainWindow, nil)
makeDraggable(FloatingPopup, FloatingPopup, function()
    setMinimized(false)
end)

-- Shortcut Keyboard [RightControl] untuk Minimize / Maximize
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        setMinimized(not MenuState.IsMinimized)
    end
end)
