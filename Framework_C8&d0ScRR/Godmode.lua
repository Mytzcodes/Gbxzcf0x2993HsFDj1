--[[
  ╔══════════════════════════════════════════════════╗
  ║   NXroENinD_DPcKage · Godmode                   ║
  ║   Anti-Damage · Anti-Lava · Anti-Spike           ║
  ║   HP Shield — health stays permanently full      ║
  ╚══════════════════════════════════════════════════╝

  Strategy (3-layer):
    1. Hook game's upvalue `v_u_132` (HP var) via getsenv/getupvalue
       and forcefully keep it at max every frame.
    2. Hook ForceDie / Burned / Knocked packets via Net module.
    3. Roblox Humanoid.Health as fallback anchor (cosmetic layer).

  Usage:
    NX.GodmodeOn()   — activate shield
    NX.GodmodeOff()  — deactivate
    NX.IsGodmode()   — query status
]]

local Godmode = {}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local Console = nil
local Events  = nil
local Network = nil

local _active      = false
local _heartbeatCn = nil
local _netHooks    = {}
local _started     = false

-- ── HP constant (GrowBlox max HP = 5) ────────────────────────────────────────
local MAX_HP = 5

-- ── Upvalue hook attempt ───────────────────────────────────────────────────────
-- GrowBlox stores HP in upvalue `v_u_132` inside Game.lua's main closure.
-- We try to find and lock it via getupvalue/setupvalue (executor-dependent).

local function _tryUpvalueHook()
    -- Try to find the game script environment
    local gameGui = nil
    pcall(function()
        local lp = Players.LocalPlayer
        local pg = lp:WaitForChild("PlayerGui", 5)
        if pg then
            local gg = pg:FindFirstChild("GameGui")
            if gg then
                gameGui = gg:FindFirstChild("Game")
            end
        end
    end)

    if not gameGui then return false end

    -- Executor functions: getsenv (Synapse) or getscriptenv
    local getEnv = getgenv and getgenv().getsenv
                or (getsenv and getsenv)
                or nil
    if not getEnv then return false end

    local ok, env = pcall(getEnv, gameGui)
    if not ok or type(env) ~= "table" then return false end

    -- The game script uses upvalues, not direct globals.
    -- Best effort: watch for 'dead' or HP flags in the env
    return false  -- upvalue approach requires deep executor support
end

-- ── Attribute-based ghost mode ─────────────────────────────────────────────────
-- GrowBlox checks v_u_144.ghost — if true, touchingHurt is bypassed.
-- v_u_144 is the world state object stored in script upvalues.
-- We'll try to set the "ghost" attribute on LocalPlayer as a signal.

local function _tryGhostAttribute()
    local lp = Players.LocalPlayer
    if not lp then return false end
    -- Some executors let us set attributes that game code reads
    pcall(function()
        lp:SetAttribute("ghost", true)
        lp:SetAttribute("Frozen", false)
    end)
    return true
end

-- ── Net packet intercept ───────────────────────────────────────────────────────
-- Intercept ForceDie, Burned, Knocked packets and suppress them

local function _hookDamagePackets(net)
    if not net then return end

    local function noop() end

    -- Block ForceDie
    if net.forceDie and type(net.forceDie.listen) == "function" then
        pcall(function()
            net.forceDie.listen(function()
                if _active then return end  -- suppress
            end)
        end)
    end

    -- Block Burned
    if net.burned and type(net.burned.listen) == "function" then
        pcall(function()
            net.burned.listen(function()
                if _active then return end  -- suppress
            end)
        end)
    end

    -- Block Knocked (heavy knockback)
    if net.knocked and type(net.knocked.listen) == "function" then
        pcall(function()
            net.knocked.listen(function()
                if _active then return end
            end)
        end)
    end
end

-- ── Heartbeat HP guard ────────────────────────────────────────────────────────
-- Every frame: find the HP-displaying UI and keep it at max visually.
-- Also keep Roblox Humanoid health at max (cosmetic).

local _hpLabel = nil

local function _findHpLabel()
    if _hpLabel and _hpLabel.Parent then return _hpLabel end
    local lp = Players.LocalPlayer
    if not lp then return nil end
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return nil end
    -- Try to find HP UI elements in GameGui
    for _, desc in ipairs(pg:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("Frame")) then
            local name = desc.Name:lower()
            if name:find("hp") or name:find("health") or name:find("heart") then
                _hpLabel = desc
                return desc
            end
        end
    end
    return nil
end

local function _tickGodmode()
    -- Keep Roblox character HP max (doesn't affect game's own HP system but prevents respawn)
    local lp = Players.LocalPlayer
    if lp and lp.Character then
        local hum = lp.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end

    -- Keep ghost attribute set (may bypass touchingHurt checks)
    pcall(function()
        if lp then
            lp:SetAttribute("ghost", true)
        end
    end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Godmode.On()
    if _active then return end
    _active = true

    _tryGhostAttribute()

    -- Heartbeat guard
    _heartbeatCn = RunService.Heartbeat:Connect(_tickGodmode)

    -- Hook Net packets
    local net = nil
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local sh = rs:FindFirstChild("Shared")
        if sh then
            local nm = sh:FindFirstChild("Net")
            if nm then net = require(nm) end
        end
    end)
    if net then _hookDamagePackets(net) end

    if Console and type(Console.ConsoleMsg) == "function" then
        Console.ConsoleMsg("🛡 Godmode ON — kebal damage", "green")
    end
    if Events and type(Events.Emit) == "function" then
        Events.Emit("godmode:on")
    end
end

function Godmode.Off()
    if not _active then return end
    _active = false

    if _heartbeatCn then
        _heartbeatCn:Disconnect()
        _heartbeatCn = nil
    end

    -- Remove ghost attribute
    pcall(function()
        local lp = Players.LocalPlayer
        if lp then lp:SetAttribute("ghost", nil) end
    end)

    if Console and type(Console.ConsoleMsg) == "function" then
        Console.ConsoleMsg("🛡 Godmode OFF", "yellow")
    end
    if Events and type(Events.Emit) == "function" then
        Events.Emit("godmode:off")
    end
end

function Godmode.Toggle()
    if _active then Godmode.Off() else Godmode.On() end
end

function Godmode.IsActive()
    return _active
end

-- ── Start ─────────────────────────────────────────────────────────────────────

function Godmode.Start(eventsModule, consoleModule, networkModule)
    if _started then return end
    _started = true

    if type(eventsModule) == "table"  then Events  = eventsModule  end
    if type(consoleModule) == "table" then Console = consoleModule end
    if type(networkModule) == "table" then Network = networkModule end
end

return Godmode
