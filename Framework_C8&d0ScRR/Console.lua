--[[
╔══════════════════════════════════════════════════════════════════════════╗
║  NXroENinD_DPcKage.Console — ConsoleMsg / Log / Clear                           ║
╚══════════════════════════════════════════════════════════════════════════╝
  Provides:
    ConsoleMsg(text, color?)   → Display message in game console
    Log(text, level?)          → Internal debug log
    Clear()                    → Clear console output
    SetPrefix(str)             → Set log prefix tag
--]]

local Console = {}

local RunService    = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events        = require(script.Parent.Events)

-- ──────────────────────────────────────────────
--  Config
-- ──────────────────────────────────────────────
local _prefix    = "[NXroENinD_DPcKage]"
local _logLevel  = 1   -- 0=off, 1=info, 2=debug, 3=verbose
local _history   = {}  -- Ring buffer of log entries
local _maxHistory= 500
local _started   = false

-- Color palette (Roblox Color3)
local Colors = {
    white   = Color3.fromRGB(255, 255, 255),
    gray    = Color3.fromRGB(180, 180, 180),
    yellow  = Color3.fromRGB(255, 230, 50),
    green   = Color3.fromRGB(80, 255, 80),
    red     = Color3.fromRGB(255, 80, 80),
    cyan    = Color3.fromRGB(50, 220, 255),
    orange  = Color3.fromRGB(255, 160, 50),
    purple  = Color3.fromRGB(180, 100, 255),
}

local LevelColors = {
    [0] = Colors.gray,
    [1] = Colors.white,
    [2] = Colors.cyan,
    [3] = Colors.yellow,
}

-- ──────────────────────────────────────────────
--  Internal: push to history ring buffer
-- ──────────────────────────────────────────────
local function _pushHistory(entry)
    table.insert(_history, entry)
    if #_history > _maxHistory then
        table.remove(_history, 1)
    end
end

-- ──────────────────────────────────────────────
--  Internal: render to output UI (if exists)
-- ──────────────────────────────────────────────
local _outputUI = nil  -- Will be set if ConsoleGui found

local function _tryFindUI()
    local gui = game:GetService("Players").LocalPlayer
        :WaitForChild("PlayerGui", 2)
    if gui then
        local cg = gui:FindFirstChild("ConsoleGui")
        if cg then
            _outputUI = cg:FindFirstChild("OutputFrame")
        end
    end
end

local function _renderToUI(text, color)
    if not _outputUI then return end
    -- Append a TextLabel to the output frame
    local lbl = Instance.new("TextLabel")
    lbl.Text            = text
    lbl.TextColor3      = color or Colors.white
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment  = Enum.TextXAlignment.Left
    lbl.Font            = Enum.Font.Code
    lbl.TextSize        = 13
    lbl.AutomaticSize   = Enum.AutomaticSize.Y
    lbl.Size            = UDim2.new(1, 0, 0, 0)
    lbl.Parent          = _outputUI
    -- Auto-scroll
    local sl = _outputUI.Parent
    if sl and sl:IsA("ScrollingFrame") then
        sl.CanvasPosition = Vector2.new(0, sl.AbsoluteCanvasSize.Y)
    end
    -- Auto-trim UI labels
    if #_outputUI:GetChildren() > 200 then
        _outputUI:GetChildren()[1]:Destroy()
    end
end

-- ──────────────────────────────────────────────
--  Public API
-- ──────────────────────────────────────────────

--[[
    ConsoleMsg(text, color?)
    
    Display a message in the game console and output.
    color: optional Color3 value or color name string
           ("white", "green", "red", "yellow", "cyan", etc.)
    
    Example:
        NX.ConsoleMsg("Player joined!", "green")
        NX.ConsoleMsg("Error occurred", Color3.fromRGB(255,0,0))
        NX.ConsoleMsg("Info message")
]]
function Console.ConsoleMsg(text, color)
    assert(type(text) == "string" or type(text) == "number",
        "[NXroENinD_DPcKage.Console] text must be a string or number")
    
    text = tostring(text)
    
    -- Resolve color
    local resolvedColor
    if type(color) == "string" then
        resolvedColor = Colors[color:lower()] or Colors.white
    elseif typeof(color) == "Color3" then
        resolvedColor = color
    else
        resolvedColor = Colors.white
    end

    local entry = {
        text      = text,
        color     = resolvedColor,
        timestamp = os.time(),
    }

    _pushHistory(entry)

    -- Print to Roblox output
    print(_prefix .. " " .. text)

    -- Render to UI if available
    _renderToUI(text, resolvedColor)

    -- Fire internal event for other systems to listen
    Events.Emit("console:message", entry)
end

--[[
    Log(text, level?)
    
    Internal framework log. Level: 1=info, 2=debug, 3=verbose
    
    Example:
        NX.ConsoleLog("Packet received", 2)
]]
function Console.Log(text, level)
    level = level or 1
    if level > _logLevel then return end
    local color = LevelColors[level] or Colors.white
    Console.ConsoleMsg(text, color)
end

--[[
    Clear()
    
    Clear the console output UI and history.
]]
function Console.Clear()
    _history = {}
    if _outputUI then
        for _, child in ipairs(_outputUI:GetChildren()) do
            child:Destroy()
        end
    end
    print(_prefix .. " Console cleared.")
end

--[[
    SetPrefix(str)
    
    Set the console message prefix tag.
    Default: "[NXroENinD_DPcKage]"
]]
function Console.SetPrefix(str)
    _prefix = tostring(str)
end

--[[
    SetLogLevel(level)
    
    Set verbosity: 0=silent, 1=info, 2=debug, 3=verbose
]]
function Console.SetLogLevel(level)
    _logLevel = level
end

--[[
    GetHistory()
    
    Returns the console history table (up to 500 entries).
    Each entry: { text: string, color: Color3, timestamp: number }
]]
function Console.GetHistory()
    return table.clone(_history)
end

-- ──────────────────────────────────────────────
--  Startup: hook ConsoleMessagePacket
-- ──────────────────────────────────────────────
function Console.Start()
    if _started then return end
    _started = true

    -- Lazy find UI
    task.defer(_tryFindUI)

    -- Listen for server console messages (pkt 0x0014)
    Events.On("packet:" .. 0x0014, function(data)
        -- data = { text: string, color: uint32 }
        local r = bit32.rshift(bit32.band(data.color, 0xFF0000), 16)
        local g = bit32.rshift(bit32.band(data.color, 0x00FF00), 8)
        local b = bit32.band(data.color, 0x0000FF)
        local c = Color3.fromRGB(r, g, b)
        Console.ConsoleMsg("[SERVER] " .. data.text, c)
    end)
end

return Console
