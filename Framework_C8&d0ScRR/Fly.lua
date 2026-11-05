--[[
  ╔══════════════════════════════════════════════════╗
  ║   NXroENinD_DPcKage · Fly                       ║
  ║   Smooth Flight System — no crash, no jitter    ║
  ╚══════════════════════════════════════════════════╝

  GrowBlox is 2D side-scroll. "Fly" = send rapid move packets
  upward while holding hover position, bypassing gravity.

  How it works:
    1. Send Net.move packets with vy = -flySpeed (upward)
    2. Use RunService.Heartbeat to maintain altitude
    3. Keyboard/direction control for WASD / Arrow keys
    4. Toggle with NX.FlyOn() / NX.FlyOff()

  Controls (while flying):
    W / Up    = fly up
    S / Down  = fly down
    A / Left  = move left
    D / Right = move right
    Space     = hover in place

  Usage:
    NX.FlyOn()
    NX.FlyOff()
    NX.FlyToggle()
    NX.SetFlySpeed(n)   -- default 8
]]

local Fly = {}

local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Players    = game:GetService("Players")

local Console   = nil
local Events    = nil
local Network   = nil
local PlayerAPI = nil

local _started    = false
local _flying     = false
local _flySpeed   = 8          -- tiles per second
local _hbCn       = nil
local _posX       = 50.0
local _posY       = 30.0
local _lastSent   = 0
local SEND_RATE   = 0.05       -- send move packet every 50ms (20/sec)

-- ── Keybinds ──────────────────────────────────────────────────────────────────

local function _getInput()
    local vx, vy = 0, 0
    local ok = pcall(function()
        if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left)  then vx = -1 end
        if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then vx =  1 end
        if UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Up)    then vy = -1 end
        if UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.Down)  then vy =  1 end
    end)
    return vx, vy
end

-- ── Send move via Net (direct, no delay) ────────────────────────────────────

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

local function _sendMoveRaw(x, y, vx, vy)
    local net = _getNet()
    if net and net.move and type(net.move.send) == "function" then
        pcall(net.move.send, {
            x     = x,
            y     = y,
            vx    = vx * _flySpeed,
            vy    = vy * _flySpeed,
            flags = 2,   -- grounded flag (server accepts this)
            t     = math.floor(os.clock() * 1000) % 65534,
        })
        return
    end
    -- Fallback via Network module
    if Network and type(Network.SendPkt) == "function" then
        Network.SendPkt("move", {
            x = x, y = y,
            vx = vx * _flySpeed, vy = vy * _flySpeed,
            flags = 2,
            t = math.floor(os.clock() * 1000) % 65534,
        })
    end
end

-- ── World bounds ──────────────────────────────────────────────────────────────

local function _clampPos(x, y)
    local w, h = 100, 60
    -- Try to get real world size
    if Network then
        pcall(function()
            local net = _getNet()
            -- (world size not directly available here, use defaults)
        end)
    end
    return math.clamp(x, 1, w - 1), math.clamp(y, 1, h - 1)
end

-- ── Fly tick ──────────────────────────────────────────────────────────────────

local function _onHeartbeat(dt)
    if not _flying then return end

    local vx, vy = _getInput()
    local speed = _flySpeed * dt

    _posX = _posX + vx * speed
    _posY = _posY + vy * speed
    _posX, _posY = _clampPos(_posX, _posY)

    -- Rate-limit sends to avoid spam/kick
    local now = os.clock()
    if now - _lastSent >= SEND_RATE then
        _lastSent = now
        _sendMoveRaw(_posX, _posY, vx, vy)

        -- Update PlayerAPI internal position
        if PlayerAPI and type(PlayerAPI.SetPosition) == "function" then
            PlayerAPI.SetPosition(_posX, _posY)
        end
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Fly.On()
    if _flying then return end
    _flying = true

    -- Grab current position
    if PlayerAPI and type(PlayerAPI.Player) == "function" then
        local p = PlayerAPI.Player()
        if p then
            _posX = p.x or p.CurrentPosition and p.CurrentPosition.X or 50
            _posY = p.y or p.CurrentPosition and p.CurrentPosition.Y or 30
        end
    end

    _hbCn = RunService.Heartbeat:Connect(_onHeartbeat)

    if Console then Console.ConsoleMsg("✈ Fly ON  [WASD / Arrow keys]", "cyan") end
    if Events  then Events.Emit("fly:on") end
end

function Fly.Off()
    if not _flying then return end
    _flying = false

    if _hbCn then _hbCn:Disconnect(); _hbCn = nil end

    -- Final snap to current position with grounded flag
    _sendMoveRaw(_posX, _posY, 0, 0)

    if Console then Console.ConsoleMsg("✈ Fly OFF", "gray") end
    if Events  then Events.Emit("fly:off") end
end

function Fly.Toggle()
    if _flying then Fly.Off() else Fly.On() end
end

function Fly.IsActive() return _flying end

function Fly.SetSpeed(n)
    _flySpeed = math.clamp(tonumber(n) or 8, 1, 50)
    if Console then Console.ConsoleMsg("✈ Fly speed: " .. _flySpeed, "cyan") end
end

function Fly.SetPosition(x, y)
    _posX = tonumber(x) or _posX
    _posY = tonumber(y) or _posY
end

-- ── Start ─────────────────────────────────────────────────────────────────────

function Fly.Start(eventsModule, consoleModule, networkModule, playerAPIModule)
    if _started then return end
    _started = true
    if type(eventsModule)   == "table" then Events    = eventsModule   end
    if type(consoleModule)  == "table" then Console   = consoleModule  end
    if type(networkModule)  == "table" then Network   = networkModule  end
    if type(playerAPIModule)== "table" then PlayerAPI = playerAPIModule end
end

return Fly
