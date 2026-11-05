-- NXroENinD_DPcKage.Console
-- Visual output ke ChatGui game (channel "system") + fallback print.
-- Gunakan ConsoleMsg() untuk pesan yang muncul di chat game.

local Console = {}

local _prefix     = "[NX]"
local _logLevel   = 1
local _history    = {}
local _maxHistory = 500
local _started    = false
local Events      = nil

-- ── Color palette ─────────────────────────────────────────────────────────────

local Colors = {
    white  = Color3.fromRGB(255, 255, 255),
    gray   = Color3.fromRGB(180, 180, 180),
    yellow = Color3.fromRGB(255, 230, 50),
    green  = Color3.fromRGB(80,  255, 80),
    red    = Color3.fromRGB(255, 80,  80),
    cyan   = Color3.fromRGB(50,  220, 255),
    orange = Color3.fromRGB(255, 160, 50),
    purple = Color3.fromRGB(180, 100, 255),
}

-- GT color code map (BitmapText markup: `N = color code)
-- System messages use "`o" = orange/white in this game
local ColorCode = {
    white  = "`o",   -- default text color
    gray   = "`s",   -- subtle
    yellow = "`3",   -- yellow/gold
    green  = "`9",   -- green
    red    = "`4",   -- red/error
    cyan   = "`2",   -- cyan
    orange = "`8",   -- orange
    purple = "`5",   -- purple
}

-- ── Visual output: inject into game ChatGui ───────────────────────────────────

local _chatAdd = nil      -- cached chat.add function
local _chatFound = false  -- prevent repeated searches

local function _findChatAdd()
    if _chatFound then return _chatAdd end
    _chatFound = true

    local ok, lp = pcall(function()
        return game:GetService("Players").LocalPlayer
    end)
    if not ok or not lp then return nil end

    -- ChatGui is created by ChatUI.lua as PlayerGui.ChatGui
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return nil end

    local chatGui = pg:FindFirstChild("ChatGui")
    if not chatGui then return nil end

    -- The chat module stores its API in a BindableFunction or via script communication.
    -- We can inject text directly into the ScrollingFrame used for messages.
    -- Fallback: find the message list frame and append a TextLabel.

    -- Look for the message list (UIListLayout frame inside ChatGui)
    local msgFrame = nil
    for _, desc in ipairs(chatGui:GetDescendants()) do
        if desc:IsA("UIListLayout") then
            msgFrame = desc.Parent
            break
        end
    end

    if msgFrame then
        _chatAdd = function(text, colorCode)
            pcall(function()
                -- Inject a styled TextLabel into the chat message frame
                local lbl = Instance.new("TextLabel")
                lbl.Name = "NX_msg"
                lbl.Text = (colorCode or "") .. text .. "``"
                lbl.RichText = false
                lbl.TextColor3 = Colors.white
                lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                lbl.BackgroundTransparency = 0.9
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Font = Enum.Font.Code
                lbl.TextSize = 14
                lbl.AutomaticSize = Enum.AutomaticSize.Y
                lbl.Size = UDim2.new(1, 0, 0, 20)
                lbl.TextWrapped = true
                lbl.Parent = msgFrame

                -- Auto-scroll
                local sf = msgFrame.Parent
                if sf and sf:IsA("ScrollingFrame") then
                    sf.CanvasPosition = Vector2.new(0, sf.AbsoluteCanvasSize.Y)
                end

                -- Auto-trim old messages
                local children = msgFrame:GetChildren()
                local nxMsgs = {}
                for _, c in ipairs(children) do
                    if c.Name == "NX_msg" then nxMsgs[#nxMsgs+1] = c end
                end
                if #nxMsgs > 50 then
                    nxMsgs[1]:Destroy()
                end
            end)
        end
        return _chatAdd
    end

    return nil
end

-- ── SendNotification fallback (Roblox top-right popup) ───────────────────────

local function _notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title    = title or _prefix,
            Text     = text,
            Duration = duration or 4,
        })
    end)
end

-- ── Core output function ──────────────────────────────────────────────────────

local function _pushHistory(entry)
    table.insert(_history, entry)
    if #_history > _maxHistory then table.remove(_history, 1) end
end

-- Main visual output — tries ChatGui first, then notification, then print
local function _output(text, colorName)
    colorName = colorName or "white"
    local code = ColorCode[colorName] or ColorCode.white

    local entry = { text = text, colorName = colorName, timestamp = os.time() }
    _pushHistory(entry)

    -- Try ChatGui inject
    local addFn = _findChatAdd()
    if addFn then
        addFn(_prefix .. " " .. text, code)
        return
    end

    -- Fallback: Roblox StarterGui notification
    _notify(_prefix, text, 4)

    -- Always also print to output for debugging
    print(_prefix .. " " .. text)
end

-- ── Public API ───────────────────────────────────────────────────────────────

--[[
    ConsoleMsg(text, color?)
    Shows message visually in game ChatGui (system channel).
    color: "white"|"green"|"red"|"yellow"|"cyan"|"orange"|"purple"|"gray"

    NX.ConsoleMsg("Arrived!", "green")
    NX.ConsoleMsg("Error!", "red")
]]
function Console.ConsoleMsg(text, color)
    text = tostring(text)

    local colorName
    if type(color) == "string" then
        colorName = Colors[color:lower()] and color:lower() or "white"
    elseif typeof(color) == "Color3" then
        -- Find closest named color
        colorName = "white"
    else
        colorName = "white"
    end

    _output(text, colorName)

    if Events then
        Events.Emit("console:message", { text = text, colorName = colorName, timestamp = os.time() })
    end
end

function Console.Log(text, level)
    level = level or 1
    if level > _logLevel then return end
    local colorMap = { [1]="white", [2]="cyan", [3]="yellow" }
    Console.ConsoleMsg(text, colorMap[level] or "white")
end

function Console.Clear()
    _history = {}
    -- Clear injected NX messages from ChatGui
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        local pg = lp:FindFirstChild("PlayerGui")
        local cg = pg and pg:FindFirstChild("ChatGui")
        if cg then
            for _, desc in ipairs(cg:GetDescendants()) do
                if desc.Name == "NX_msg" then desc:Destroy() end
            end
        end
    end)
end

--[[
    Notify(text, duration?)
    Show a Roblox top-right notification popup.

    NX.Console.Notify("Done!", 3)
]]
function Console.Notify(text, duration)
    _notify(_prefix, tostring(text), duration or 4)
end

function Console.SetPrefix(str)   _prefix   = tostring(str) end
function Console.SetLogLevel(lvl) _logLevel = lvl end
function Console.GetHistory()     return table.clone(_history) end

-- ── Startup ───────────────────────────────────────────────────────────────────

function Console.Start(eventsModule)
    if _started then return end
    _started = true

    if type(eventsModule) == "table" and type(eventsModule.On) == "function" then
        Events = eventsModule
    else
        warn("[NX.Console] No Events module.")
    end

    -- Pre-search for ChatGui after a short delay (GUI may not exist yet)
    task.delay(2, function()
        _chatFound = false   -- reset so next ConsoleMsg retries the search
        _chatAdd   = nil
        _findChatAdd()
    end)

    if not Events then return end

    -- Listen for server console messages (ConsoleMessagePacket 0x0014)
    Events.On("packet:" .. 0x0014, function(data)
        if not data then return end
        Console.ConsoleMsg("[SERVER] " .. tostring(data.text or ""), "gray")
    end)
end

return Console
