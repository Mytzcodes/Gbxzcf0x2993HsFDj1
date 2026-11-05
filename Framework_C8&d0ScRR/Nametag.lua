--[[
  ╔══════════════════════════════════════════════════╗
  ║   NXroENinD_DPcKage · Nametag                   ║
  ║   Custom Visual Name above character head        ║
  ╚══════════════════════════════════════════════════╝

  Creates a stylish BillboardGui above player's visual sprite.
  Supports @ prefix, [MOD], [DEV], custom color, custom text.

  Usage:
    NX.SetNametag("MyName")                   -- simple
    NX.SetNametag("@MyName", "cyan")          -- with @ and color
    NX.SetNametag("MyName", "gold", "[MOD]")  -- with prefix badge
    NX.SetNametag("MyName", nil, nil, {       -- full options
        prefix  = "[★]",
        suffix  = " ✓",
        style   = "developer",    -- "developer"|"mod"|"admin"|"custom"
        size    = 16,
        glow    = true,
    })
    NX.RemoveNametag()
]]

local Nametag = {}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local Console  = nil
local Events   = nil
local _started = false

-- ── Style presets ─────────────────────────────────────────────────────────────

local STYLES = {
    default   = { color = Color3.fromRGB(255, 255, 255), badge = "",       badgeColor = Color3.fromRGB(180,180,180) },
    developer = { color = Color3.fromRGB(80,  220, 255), badge = "[@DEV]", badgeColor = Color3.fromRGB(0, 180, 255) },
    mod       = { color = Color3.fromRGB(160, 255, 100), badge = "[@MOD]", badgeColor = Color3.fromRGB(100, 220, 60) },
    admin     = { color = Color3.fromRGB(255, 180, 60),  badge = "[@ADM]", badgeColor = Color3.fromRGB(255, 140, 0) },
    gold      = { color = Color3.fromRGB(255, 215, 0),   badge = "[★]",    badgeColor = Color3.fromRGB(255, 180, 0) },
    custom    = { color = Color3.fromRGB(255, 255, 255), badge = "",       badgeColor = Color3.fromRGB(200,200,200) },
}

local COLOR_MAP = {
    white   = Color3.fromRGB(255, 255, 255),
    gray    = Color3.fromRGB(180, 180, 180),
    cyan    = Color3.fromRGB(80,  220, 255),
    green   = Color3.fromRGB(90,  235, 90),
    red     = Color3.fromRGB(255, 85,  85),
    yellow  = Color3.fromRGB(255, 220, 60),
    orange  = Color3.fromRGB(255, 160, 50),
    purple  = Color3.fromRGB(200, 120, 255),
    gold    = Color3.fromRGB(255, 215, 0),
    pink    = Color3.fromRGB(255, 150, 200),
}

local function _resolveColor(c)
    if typeof(c) == "Color3" then return c end
    if type(c) == "string" then return COLOR_MAP[c:lower()] or Color3.fromRGB(255,255,255) end
    return Color3.fromRGB(255,255,255)
end

-- ── Active nametag state ───────────────────────────────────────────────────────

local _gui    = nil
local _hbCn   = nil
local _config = nil

-- ── Build BillboardGui ────────────────────────────────────────────────────────

local function _buildGui(cfg)
    -- Cleanup old
    if _gui then pcall(function() _gui:Destroy() end); _gui = nil end

    local lp = Players.LocalPlayer
    if not lp then return end
    local char = lp.Character or lp.CharacterAdded:Wait()
    if not char then return end

    -- Find root part
    local root = char:FindFirstChild("HumanoidRootPart")
              or char:FindFirstChildOfClass("BasePart")
    if not root then return end

    local style = STYLES[cfg.style or "default"] or STYLES.default
    local nameColor   = cfg.color   and _resolveColor(cfg.color) or style.color
    local badgeColor  = style.badgeColor
    local fontSize    = cfg.size or 16
    local displayText = cfg.text or "..."
    local prefix      = cfg.prefix or style.badge
    local suffix      = cfg.suffix or ""

    -- BillboardGui
    local bb = Instance.new("BillboardGui")
    bb.Name           = "NX_Nametag"
    bb.ResetOnSpawn   = false
    bb.AlwaysOnTop    = false
    bb.Size           = UDim2.fromOffset(200, 50)
    bb.StudsOffset    = Vector3.new(0, 3.2, 0)   -- above head
    bb.Adornee        = root
    bb.Parent         = lp:FindFirstChild("PlayerGui") or char

    -- Background pill
    local pill = Instance.new("Frame")
    pill.Name                = "Pill"
    pill.BackgroundColor3    = Color3.fromRGB(10, 14, 20)
    pill.BackgroundTransparency = 0.3
    pill.BorderSizePixel     = 0
    pill.AnchorPoint         = Vector2.new(0.5, 0.5)
    pill.Position            = UDim2.fromScale(0.5, 0.5)
    pill.Size                = UDim2.fromOffset(0, fontSize + 10)
    pill.AutomaticSize       = Enum.AutomaticSize.X
    pill.Parent              = bb

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent       = pill

    local stroke = Instance.new("UIStroke")
    stroke.Color       = nameColor
    stroke.Thickness   = 1.2
    stroke.Transparency = 0.4
    stroke.Parent      = pill

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, 10)
    pad.PaddingRight  = UDim.new(0, 10)
    pad.PaddingTop    = UDim.new(0, 3)
    pad.PaddingBottom = UDim.new(0, 3)
    pad.Parent        = pill

    local layout = Instance.new("UIListLayout")
    layout.FillDirection        = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment  = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment    = Enum.VerticalAlignment.Center
    layout.Padding              = UDim.new(0, 4)
    layout.SortOrder            = Enum.SortOrder.LayoutOrder
    layout.Parent               = pill

    -- Badge label (prefix)
    if prefix and #prefix > 0 then
        local badge = Instance.new("TextLabel")
        badge.Name               = "Badge"
        badge.Text               = prefix
        badge.TextColor3         = badgeColor
        badge.Font               = Enum.Font.GothamBold
        badge.TextSize           = fontSize - 2
        badge.BackgroundTransparency = 1
        badge.Size               = UDim2.fromOffset(0, fontSize + 4)
        badge.AutomaticSize      = Enum.AutomaticSize.X
        badge.LayoutOrder        = 0
        badge.Parent             = pill
    end

    -- Name label
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name               = "Name"
    nameLbl.Text               = displayText .. suffix
    nameLbl.TextColor3         = nameColor
    nameLbl.Font               = Enum.Font.GothamBold
    nameLbl.TextSize           = fontSize
    nameLbl.BackgroundTransparency = 1
    nameLbl.Size               = UDim2.fromOffset(0, fontSize + 4)
    nameLbl.AutomaticSize      = Enum.AutomaticSize.X
    nameLbl.LayoutOrder        = 1
    nameLbl.Parent             = pill

    -- Glow effect
    if cfg.glow then
        local glow = Instance.new("UIGradient")
        glow.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   nameColor),
            ColorSequenceKeypoint.new(0.5, Color3.new(1,1,1)),
            ColorSequenceKeypoint.new(1,   nameColor),
        })
        glow.Rotation = 90
        glow.Parent   = nameLbl
    end

    _gui = bb
end

-- ── Keep attached on character respawn ────────────────────────────────────────

local function _attach()
    if not _config then return end
    _buildGui(_config)
end

-- ── Public API ────────────────────────────────────────────────────────────────

--[[
    SetNametag(text, color?, prefixBadge?, opts?)
    text        : display name string
    color       : "cyan"|"gold"|"red"|Color3 or nil
    prefixBadge : "[MOD]"|"[@DEV]"|"[★]" etc. or nil
    opts        : { style, size, suffix, glow }
]]
function Nametag.Set(text, color, prefixBadge, opts)
    opts = opts or {}
    _config = {
        text   = tostring(text or ""),
        color  = color,
        prefix = prefixBadge or opts.prefix,
        suffix = opts.suffix  or "",
        style  = opts.style   or "default",
        size   = opts.size    or 16,
        glow   = opts.glow    or false,
    }

    -- If name starts with @, treat as @ mention style
    if _config.text:sub(1,1) == "@" then
        _config.prefix = _config.prefix or "[@]"
        _config.color  = _config.color  or "cyan"
    end

    _buildGui(_config)

    if Console then
        Console.ConsoleMsg("🏷 Nametag: " .. _config.text, "cyan")
    end
end

function Nametag.Remove()
    _config = nil
    if _gui then pcall(function() _gui:Destroy() end); _gui = nil end
    if Console then Console.ConsoleMsg("🏷 Nametag removed", "gray") end
end

function Nametag.Update(text)
    if not _config then return end
    _config.text = tostring(text or _config.text)
    _buildGui(_config)
end

function Nametag.ApplyStyle(style)
    if not _config then return end
    _config.style = style
    _buildGui(_config)
end

-- ── Start ─────────────────────────────────────────────────────────────────────

function Nametag.Start(eventsModule, consoleModule)
    if _started then return end
    _started = true
    if type(eventsModule)  == "table" then Events  = eventsModule  end
    if type(consoleModule) == "table" then Console = consoleModule end

    -- Re-attach on character respawn
    local lp = Players.LocalPlayer
    if lp then
        lp.CharacterAdded:Connect(function()
            task.wait(1)
            _attach()
        end)
    end
end

return Nametag
