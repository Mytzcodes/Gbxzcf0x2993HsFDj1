--[[
  ╔══════════════════════════════════════════════════╗
  ║   NXroENinD_DPcKage · FastSpin                  ║
  ║   Instant Roulette/Wheel — zero animation delay  ║
  ╚══════════════════════════════════════════════════╝

  Game's spin() function:
    1. Checks v_u_94[key] — if entry exists, it's "already spinning" (cooldown)
    2. Sets ends = os.clock() + rollTime (default 2.2s) — animation timer
    3. Calls Net.spin.send({x, y}) — sends packet to server

  To bypass the 2.2s animation delay:
    → Send Net.spin.send({x, y}) directly (no cooldown check)
    → Listen for Net.wheelSpun (server result) immediately

  Anti-spam: enforce minimum 0.3s between spins (server minimum).

  Usage:
    NX.FastSpin(x, y)             — spin wheel at tile x,y instantly
    NX.FastSpinAuto(x, y, count?) — spin N times with minimal delay
    NX.StopAutoSpin()             — stop auto-spin loop

  Hooks:
    NX.OnSpinResult(callback)
    — callback(result) where result = { name, n, userId, x, y }
]]

local FastSpin = {}

local RunService = game:GetService("RunService")

local Console  = nil
local Events   = nil
local _started = false

local _autoRunning  = false
local _autoHandle   = nil
local _resultHook   = nil
local _lastSpin     = 0
local MIN_INTERVAL  = 0.35   -- minimum seconds between spins (server limit ~0.3s)

-- ── Net access ────────────────────────────────────────────────────────────────

local _Net = nil
local function _getNet()
    if _Net then return _Net end
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local sh = rs:FindFirstChild("Shared")
        if sh then _Net = require(sh:FindFirstChild("Net")) end
    end)
    return _Net
end

-- ── Core: send spin packet immediately ────────────────────────────────────────

local function _doSpin(x, y)
    local now = os.clock()
    local wait_needed = MIN_INTERVAL - (now - _lastSpin)
    if wait_needed > 0 then
        task.wait(wait_needed)
    end
    _lastSpin = os.clock()

    local net = _getNet()
    if not net then
        if Console then Console.ConsoleMsg("❌ Net não disponível para spin", "red") end
        return false
    end

    if not net.spin or type(net.spin.send) ~= "function" then
        if Console then Console.ConsoleMsg("❌ Net.spin.send não encontrado", "red") end
        return false
    end

    pcall(net.spin.send, {
        x = math.floor(tonumber(x) or 0),
        y = math.floor(tonumber(y) or 0),
    })
    return true
end

-- ── Hook wheel result ─────────────────────────────────────────────────────────

local _resultHookConn = false

local function _hookResult()
    if _resultHookConn then return end
    _resultHookConn = true

    local net = _getNet()
    if not net then return end

    -- Net.wheelSpun: { w, x, y, n, name, userId }
    if net.wheelSpun and type(net.wheelSpun.listen) == "function" then
        pcall(net.wheelSpun.listen, function(data)
            if not data then return end
            if Events and type(Events.Emit) == "function" then
                Events.Emit("spin:result", data)
            end
            if type(_resultHook) == "function" then
                pcall(_resultHook, data)
            end
            if Console and type(Console.ConsoleMsg) == "function" then
                Console.ConsoleMsg(
                    "🎰 Spin result: " .. tostring(data.name or "?") .. " ×" .. tostring(data.n or "?"),
                    "gold"
                )
            end
        end)
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────

--[[
    FastSpin(x, y)
    Instantly sends spin packet for wheel at tile (x, y).
    Zero animation delay. Server responds with wheelSpun event.
]]
function FastSpin.Spin(x, y)
    _hookResult()
    local ok = _doSpin(x, y)
    if ok and Console then
        Console.ConsoleMsg("🎰 Spin → (" .. math.floor(x) .. ", " .. math.floor(y) .. ")", "cyan")
    end
    return ok
end

--[[
    AutoSpin(x, y, count?, intervalOverride?)
    Spin N times with minimum delay. If count=nil, loops indefinitely.
    Returns handle with :Stop() method.
]]
function FastSpin.AutoSpin(x, y, count, interval)
    _hookResult()

    if _autoRunning then
        FastSpin.StopAuto()
    end

    _autoRunning = true
    local minInterval = math.max(MIN_INTERVAL, tonumber(interval) or MIN_INTERVAL)
    local remaining  = count  -- nil = infinite

    local handle = { stopped = false }
    _autoHandle  = handle

    if Console then
        local countStr = remaining and tostring(remaining) or "∞"
        Console.ConsoleMsg("🎰 AutoSpin START ×" .. countStr .. " @ (" .. math.floor(x) .. "," .. math.floor(y) .. ")", "cyan")
    end

    task.spawn(function()
        local spun = 0
        while _autoRunning and not handle.stopped do
            if remaining and spun >= remaining then break end

            local ok = _doSpin(x, y)
            if ok then
                spun += 1
            end

            -- Wait minimum interval (this is from server, unavoidable)
            task.wait(minInterval)
        end

        _autoRunning = false
        if Console and not handle.stopped then
            Console.ConsoleMsg("🎰 AutoSpin done [×" .. spun .. "]", "green")
        end
        if Events then Events.Emit("spin:auto_done", { spun = spun, x = x, y = y }) end
    end)

    return {
        Stop = function()
            handle.stopped = true
            _autoRunning   = false
            if Console then Console.ConsoleMsg("🎰 AutoSpin STOPPED", "yellow") end
        end
    }
end

function FastSpin.StopAuto()
    _autoRunning = false
    if _autoHandle then _autoHandle.stopped = true end
    _autoHandle = nil
end

function FastSpin.IsAutoRunning()
    return _autoRunning
end

--[[
    OnResult(callback)
    callback(data) — data: { name, n, userId, x, y, w }
    Called every time wheelSpun packet received.
]]
function FastSpin.OnResult(callback)
    _resultHook = callback
    _hookResult()
end

function FastSpin.SetMinInterval(s)
    MIN_INTERVAL = math.max(0.3, tonumber(s) or 0.35)
end

-- ── Start ─────────────────────────────────────────────────────────────────────

function FastSpin.Start(eventsModule, consoleModule)
    if _started then return end
    _started = true
    if type(eventsModule)  == "table" then Events  = eventsModule  end
    if type(consoleModule) == "table" then Console = consoleModule end
end

return FastSpin
