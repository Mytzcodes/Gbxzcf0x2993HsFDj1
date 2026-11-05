-- NXroENinD_DPcKage.Console
-- ConsoleMsg / Log / Clear. Deps injected via Start().

local Console = {}

local _prefix    = "[NXroENinD_DPcKage]"
local _logLevel  = 1
local _history   = {}
local _maxHistory = 500
local _started   = false
local _outputUI  = nil

local Events = nil  -- injected

local Colors = {
    white  = Color3.fromRGB(255, 255, 255),
    gray   = Color3.fromRGB(180, 180, 180),
    yellow = Color3.fromRGB(255, 230, 50),
    green  = Color3.fromRGB(80, 255, 80),
    red    = Color3.fromRGB(255, 80, 80),
    cyan   = Color3.fromRGB(50, 220, 255),
    orange = Color3.fromRGB(255, 160, 50),
    purple = Color3.fromRGB(180, 100, 255),
}

local LevelColors = {
    [0] = Colors.gray,
    [1] = Colors.white,
    [2] = Colors.cyan,
    [3] = Colors.yellow,
}

local function _pushHistory(entry)
    table.insert(_history, entry)
    if #_history > _maxHistory then table.remove(_history, 1) end
end

local function _tryFindUI()
    local ok, lp = pcall(function()
        return game:GetService("Players").LocalPlayer
    end)
    if not ok or not lp then return end
    local gui = lp:FindFirstChild("PlayerGui")
    if gui then
        local cg = gui:FindFirstChild("ConsoleGui")
        if cg then _outputUI = cg:FindFirstChild("OutputFrame") end
    end
end

local function _renderToUI(text, color)
    if not _outputUI then return end
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.TextColor3 = color or Colors.white
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 13
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.Size = UDim2.new(1, 0, 0, 0)
    lbl.Parent = _outputUI
    local sl = _outputUI.Parent
    if sl and sl:IsA("ScrollingFrame") then
        sl.CanvasPosition = Vector2.new(0, sl.AbsoluteCanvasSize.Y)
    end
    if #_outputUI:GetChildren() > 200 then
        _outputUI:GetChildren()[1]:Destroy()
    end
end

function Console.ConsoleMsg(text, color)
    text = tostring(text)
    local resolvedColor
    if type(color) == "string" then
        resolvedColor = Colors[color:lower()] or Colors.white
    elseif typeof(color) == "Color3" then
        resolvedColor = color
    else
        resolvedColor = Colors.white
    end
    local entry = { text = text, color = resolvedColor, timestamp = os.time() }
    _pushHistory(entry)
    print(_prefix .. " " .. text)
    _renderToUI(text, resolvedColor)
    if Events then Events.Emit("console:message", entry) end
end

function Console.Log(text, level)
    level = level or 1
    if level > _logLevel then return end
    Console.ConsoleMsg(text, LevelColors[level] or Colors.white)
end

function Console.Clear()
    _history = {}
    if _outputUI then
        for _, child in ipairs(_outputUI:GetChildren()) do child:Destroy() end
    end
    print(_prefix .. " Console cleared.")
end

function Console.SetPrefix(str) _prefix = tostring(str) end
function Console.SetLogLevel(level) _logLevel = level end
function Console.GetHistory() return table.clone(_history) end

function Console.Start(eventsModule)
    if _started then return end
    _started = true
    Events = eventsModule

    task.defer(_tryFindUI)

    Events.On("packet:" .. 0x0014, function(data)
        local r = bit32.rshift(bit32.band(data.color, 0xFF0000), 16)
        local g = bit32.rshift(bit32.band(data.color, 0x00FF00), 8)
        local b = bit32.band(data.color, 0x0000FF)
        Console.ConsoleMsg("[SERVER] " .. tostring(data.text), Color3.fromRGB(r, g, b))
    end)
end

return Console
