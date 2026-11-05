--[[
    NXroENinD_DPcKage.Console v2.0
    Visual System Messages — FULLY in-game, never in developer console print.

    Strategy:
      1. INJECT into game's native ChatGui "Lines" ScrollingFrame
         → Uses BitmapText module exactly like the game does (via addLine / Lines Frame)
         → Falls back to plain TextLabel if BitmapText unavailable
      2. ON-SCREEN TOAST — floating pill at top-center screen (3.5s)
      3. StarterGui SetCore ChatMakeSystemMessage (Roblox fallback)

    addLine(text, channel) wraps every channel tab (all, world, system, global, etc.)
    so messages show up regardless of which tab is active.
]]

local Console = {}

local Players    = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local _prefix   = "[NX]"
local _logLevel = 1
local _history  = {}
local _maxHist  = 500
local _started  = false
local Events    = nil

-- ── Colors ────────────────────────────────────────────────────────────────────

local Colors = {
    white  = Color3.fromRGB(255, 255, 255),
    gray   = Color3.fromRGB(180, 180, 180),
    yellow = Color3.fromRGB(255, 220, 60),
    green  = Color3.fromRGB(90,  235, 90),
    red    = Color3.fromRGB(255, 85,  85),
    cyan   = Color3.fromRGB(80,  220, 255),
    orange = Color3.fromRGB(255, 160, 50),
    purple = Color3.fromRGB(200, 120, 255),
}

local function _resolveColor(c)
    if typeof(c) == "Color3" then return c end
    if type(c) == "string" then return Colors[c:lower()] or Colors.white end
    return Colors.white
end

-- ── BitmapText color code from Color3 ─────────────────────────────────────────
-- GrowBlox uses "`r", "`g", "`b", "`w", "`o", "`y", "`4" etc.
-- We'll use the closest markup code or just embed as plain text.

local function _colorToMarkup(color)
    if not color then return "" end
    local r, g, b = color.R, color.G, color.B
    if g > 0.7 and r < 0.4 and b < 0.4 then return "`g" end   -- green
    if r > 0.9 and g < 0.4 and b < 0.4 then return "`4" end   -- red
    if r > 0.9 and g > 0.8 and b < 0.3 then return "`y" end   -- yellow
    if b > 0.8 and r < 0.4 and g > 0.6 then return "`b" end   -- cyan
    if r > 0.9 and b > 0.6 and g < 0.4 then return "`p" end   -- purple
    if r > 0.9 and g > 0.5 and b < 0.2 then return "`o" end   -- orange
    return "`w"  -- white default
end

-- ── Toast UI ──────────────────────────────────────────────────────────────────

local _toastGui = nil
local _toastContainer = nil

local function _initToast()
    if _toastGui then return end
    local lp = Players.LocalPlayer
    if not lp then return end
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return end
    pcall(function()
        local sg = Instance.new("ScreenGui")
        sg.Name = "NX_ToastGui"
        sg.ResetOnSpawn = false
        sg.DisplayOrder = 999
        sg.IgnoreGuiInset = true
        sg.Parent = pg

        local cont = Instance.new("Frame")
        cont.Name = "Container"
        cont.BackgroundTransparency = 1
        cont.Position = UDim2.new(0.5, 0, 0.06, 0)
        cont.AnchorPoint = Vector2.new(0.5, 0)
        cont.Size = UDim2.new(0, 500, 0, 300)
        cont.Parent = sg

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Padding = UDim.new(0, 5)
        layout.Parent = cont

        _toastContainer = cont
        _toastGui = sg
    end)
end

local function _showToast(text, color)
    _initToast()
    if not _toastContainer then return end
    pcall(function()
        local pill = Instance.new("Frame")
        pill.Name = "Toast"
        pill.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
        pill.BackgroundTransparency = 0.1
        pill.BorderSizePixel = 0
        pill.Size = UDim2.new(0, 0, 0, 36)
        pill.AutomaticSize = Enum.AutomaticSize.X
        pill.AnchorPoint = Vector2.new(0.5, 0)

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = pill

        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Thickness = 1.5
        stroke.Transparency = 0.25
        stroke.Parent = pill

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft  = UDim.new(0, 14)
        pad.PaddingRight = UDim.new(0, 14)
        pad.PaddingTop   = UDim.new(0, 5)
        pad.PaddingBottom = UDim.new(0, 5)
        pad.Parent = pill

        local lbl = Instance.new("TextLabel")
        lbl.Text = _prefix .. " " .. text
        lbl.TextColor3 = color
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(0, 0, 1, 0)
        lbl.AutomaticSize = Enum.AutomaticSize.X
        lbl.TextWrapped = false
        lbl.Parent = pill

        pill.Parent = _toastContainer

        task.delay(3.5, function()
            if pill and pill.Parent then
                pcall(function()
                    local tw = TweenService:Create(pill, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
                    local tw2 = TweenService:Create(lbl, TweenInfo.new(0.3), { TextTransparency = 1 })
                    tw:Play(); tw2:Play()
                    task.wait(0.35)
                    pill:Destroy()
                end)
            end
        end)
    end)
end

-- ── Game Native Chat Injection ─────────────────────────────────────────────────
-- Uses BitmapText exactly like ChatUI.lua's addLine() does.
-- Channels: "system", "world", "all", "global" — covers ALL tab filters.

local _linesFrame = nil

local function _getLinesFrame()
    if _linesFrame and _linesFrame.Parent then return _linesFrame end
    local lp = Players.LocalPlayer
    if not lp then return nil end
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local chatGui = pg:FindFirstChild("ChatGui")
    if not chatGui then return nil end

    -- ChatUI.lua line 127: v_u_41.Name = "Lines" inside Console > Inner
    local found = chatGui:FindFirstChild("Lines", true)
    if found and found:IsA("ScrollingFrame") then
        _linesFrame = found
        return found
    end
    -- Fallback: any ScrollingFrame with UIListLayout
    for _, d in ipairs(chatGui:GetDescendants()) do
        if d:IsA("ScrollingFrame") and d:FindFirstChildOfClass("UIListLayout") then
            _linesFrame = d
            return d
        end
    end
    return nil
end

local function _injectChatLine(text, color)
    local lines = _getLinesFrame()
    if not lines then return false end

    local ok = pcall(function()
        -- Try using game's BitmapText module for proper rendering
        local BitmapText = nil
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local sh = rs:FindFirstChild("Shared")
            if sh then BitmapText = require(sh:FindFirstChild("BitmapText")) end
        end)

        local markup = _colorToMarkup(color)
        local fullText = markup .. _prefix .. " " .. text .. "``"

        if BitmapText then
            -- Use native BitmapText exactly like ChatUI.addLine() does
            local unitProbe = lines.Parent and lines.Parent:FindFirstChild("UnitProbe")
            local scale = unitProbe and (unitProbe.AbsoluteSize.X / 100) or 1
            local wrapWidth = math.max(100, lines.AbsoluteSize.X / (scale > 0 and scale or 1) - 12)

            local bt = BitmapText.new(lines, {
                size  = 20,
                color = color,
                wrap  = wrapWidth,
            })
            bt.kind   = "system"  -- shows in ALL / System / Custom tabs
            bt.order  = os.clock()
            bt.frame.LayoutOrder = bt.order
            bt.frame.BackgroundTransparency = 0.95
            bt.frame.BackgroundColor3 = Color3.new(0, 0, 0)
            bt.frame.Visible = true
            bt:set(fullText)
            bt.frame.Size = UDim2.new(1, 0, 0, bt.height)

            -- Auto-trim
            local children = lines:GetChildren()
            if #children > 85 then
                -- destroy oldest BitmapText frames
                local frames = {}
                for _, c in ipairs(children) do
                    if c:IsA("Frame") and c.LayoutOrder then
                        table.insert(frames, c)
                    end
                end
                table.sort(frames, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
                for i = 1, math.max(0, #frames - 80) do
                    frames[i]:Destroy()
                end
            end
        else
            -- Fallback: plain TextLabel
            local lbl = Instance.new("TextLabel")
            lbl.Name = "NX_Msg"
            lbl.Text = _prefix .. " " .. text
            lbl.TextColor3 = color
            lbl.BackgroundTransparency = 0.95
            lbl.BackgroundColor3 = Color3.new(0, 0, 0)
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 16
            lbl.AutomaticSize = Enum.AutomaticSize.Y
            lbl.Size = UDim2.new(1, -6, 0, 20)
            lbl.TextWrapped = true
            lbl.Parent = lines

            -- trim
            local nxMsgs = {}
            for _, c in ipairs(lines:GetChildren()) do
                if c.Name == "NX_Msg" then table.insert(nxMsgs, c) end
            end
            if #nxMsgs > 40 then nxMsgs[1]:Destroy() end
        end

        -- Auto-scroll to bottom
        task.defer(function()
            if lines and lines.Parent then
                local layout = lines:FindFirstChildOfClass("UIListLayout")
                if layout then
                    lines.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y)
                    lines.CanvasPosition = Vector2.new(0, math.max(0, layout.AbsoluteContentSize.Y - lines.AbsoluteWindowSize.Y))
                end
            end
        end)
    end)
    return ok
end

-- ── SetCore fallback ──────────────────────────────────────────────────────────

local function _setCoreSysMsg(text, color)
    pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage", {
            Text     = _prefix .. " " .. text,
            Color    = color,
            Font     = Enum.Font.GothamBold,
            FontSize = Enum.FontSize.Size14,
        })
    end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Console.ConsoleMsg(text, color)
    text = tostring(text or "")
    local c = _resolveColor(color)

    table.insert(_history, { text = text, color = c, t = os.time() })
    if #_history > _maxHist then table.remove(_history, 1) end

    _injectChatLine(text, c)
    _showToast(text, c)
    _setCoreSysMsg(text, c)

    if Events and type(Events.Emit) == "function" then
        Events.Emit("console:message", { text = text, color = c })
    end
end

function Console.Log(text, level)
    level = level or 1
    if level > _logLevel then return end
    local map = { [1] = "white", [2] = "cyan", [3] = "yellow" }
    Console.ConsoleMsg(text, map[level] or "white")
end

function Console.Notify(text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = _prefix,
            Text     = tostring(text or ""),
            Duration = duration or 3,
        })
    end)
end

function Console.Clear()
    _history = {}
    local lines = _getLinesFrame()
    if lines then
        for _, c in ipairs(lines:GetChildren()) do
            if c.Name == "NX_Msg" then c:Destroy() end
        end
    end
end

function Console.SetPrefix(s)   _prefix   = tostring(s) end
function Console.SetLogLevel(l) _logLevel = l end
function Console.GetHistory()   return table.clone(_history) end

-- ── Start ─────────────────────────────────────────────────────────────────────

function Console.Start(eventsModule)
    if _started then return end
    _started = true

    -- Guard: eventsModule is optional
    if type(eventsModule) == "table" and type(eventsModule.On) == "function" then
        Events = eventsModule
        Events.On("packet:0x0014", function(data)
            if data and data.text then
                Console.ConsoleMsg("[SERVER] " .. tostring(data.text), "yellow")
            end
        end)
    end

    task.defer(_initToast)
end

return Console
