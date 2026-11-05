-- NXroENinD_DPcKage.PlayerAPI
-- Tracks players purely from game packets (no Roblox Players service dependency).
-- Name, position, velocity, etc. all sourced from in-game net data.

local PlayerAPI = {}

local Players = game:GetService("Players")
local Events  = require(script.Parent.Events)

-- ── State ──────────────────────────────────────────────────────────────────
local _registry    = {}   -- [userId] = PlayerObject
local _localId     = nil  -- game-assigned local player ID (from first join pkt)
local _localName   = nil  -- in-game name from server packet
local _started     = false

-- ── PlayerObject ───────────────────────────────────────────────────────────
local PlayerObject = {}
PlayerObject.__index = PlayerObject

function PlayerObject.new(data)
    return setmetatable({
        userId          = data.userId,
        name            = data.name or ("Player_" .. data.userId),
        CurrentPosition = data.position or Vector3.new(0, 0, 0),
        CurrentVelocity = Vector3.new(0, 0, 0),
        CurrentRotation = 0,
        CurrentAnim     = 0,
        ping            = 0,
        isLocal         = false,
        inWorld         = true,
    }, PlayerObject)
end

-- Live position (never stale — always packet-sourced)
function PlayerObject:GetPosition()
    return self.CurrentPosition
end

function PlayerObject:GetVelocity()
    return self.CurrentVelocity
end

function PlayerObject:GetRotation()
    return self.CurrentRotation
end

-- Roblox character ref (optional, may be nil for remote players)
function PlayerObject:GetCharacter()
    local rbx = Players:GetPlayerByUserId(self.userId)
    return rbx and rbx.Character or nil
end

function PlayerObject:GetHRP()
    local char = self:GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- Distance from this player to a position or another PlayerObject
function PlayerObject:DistanceTo(target)
    local pos = (type(target) == "table" and target.CurrentPosition)
             or (typeof(target) == "Vector3" and target)
    if not pos then return math.huge end
    return (self.CurrentPosition - pos).Magnitude
end

function PlayerObject:__tostring()
    return string.format("PlayerObject[%d] %s @(%.1f,%.1f,%.1f)",
        self.userId, self.name,
        self.CurrentPosition.X,
        self.CurrentPosition.Y,
        self.CurrentPosition.Z)
end

-- ── Internal helpers ───────────────────────────────────────────────────────
local function _register(data)
    local obj = PlayerObject.new(data)
    _registry[data.userId] = obj
    Events.Emit("player:join", obj)
    return obj
end

local function _unregister(userId)
    local obj = _registry[userId]
    _registry[userId] = nil
    if obj then Events.Emit("player:leave", obj) end
end

-- ── Player() accessor ──────────────────────────────────────────────────────
-- Returns a lightweight snapshot table every call (no userdata allocation).
local function Player()
    local localObj = _registry[_localId]

    local list = {}
    for _, o in pairs(_registry) do
        list[#list + 1] = o
    end

    return {
        -- local player fields (direct, no call overhead)
        name            = _localName or (Players.LocalPlayer and Players.LocalPlayer.Name) or "Unknown",
        userId          = _localId or 0,
        CurrentPosition = localObj and localObj.CurrentPosition or Vector3.new(0,0,0),
        CurrentVelocity = localObj and localObj.CurrentVelocity or Vector3.new(0,0,0),
        CurrentRotation = localObj and localObj.CurrentRotation or 0,

        -- collection
        list  = list,
        count = #list,

        -- object refs
        ["local"] = localObj,
        self      = localObj,

        -- find(name: string | userId: number) -> PlayerObject?
        find = function(query)
            if type(query) == "number" then
                return _registry[query]
            elseif type(query) == "string" then
                local q = query:lower()
                for _, o in pairs(_registry) do
                    if o.name:lower():find(q, 1, true) then return o end
                end
            end
        end,

        -- nearest(maxDist?) -> PlayerObject?, number
        nearest = function(maxDist)
            if not localObj then return nil, math.huge end
            maxDist = maxDist or math.huge
            local best, bestD = nil, math.huge
            for _, o in pairs(_registry) do
                if not o.isLocal then
                    local d = localObj:DistanceTo(o)
                    if d < bestD and d <= maxDist then
                        best, bestD = o, d
                    end
                end
            end
            return best, bestD
        end,

        -- forEach(fn) — fn(PlayerObject) return false to break
        forEach = function(fn)
            for _, o in pairs(_registry) do
                if fn(o) == false then break end
            end
        end,
    }
end

-- ── Startup ────────────────────────────────────────────────────────────────
function PlayerAPI.Start()
    if _started then return end
    _started = true

    -- PlayerJoin: register players from game packets (not Roblox service)
    Events.On("packet:" .. 0x0011, function(data)
        -- data = { userId: u32, name: string, position: vec3 }
        local obj = _register(data)

        -- Determine which is local: first join packet where userId matches Roblox
        local rbxLocal = Players.LocalPlayer
        if rbxLocal and not _localId then
            -- Heuristic: match by name against account name
            if rbxLocal.Name == data.name or rbxLocal.DisplayName == data.name then
                _localId = data.userId
                _localName = data.name
                obj.isLocal = true
            end
        end
    end)

    -- PlayerLeave
    Events.On("packet:" .. 0x0012, function(data)
        _unregister(data.userId)
    end)

    -- PlayerUpdate: live position/rotation/anim from server
    Events.On("packet:" .. 0x0013, function(data)
        -- data = { userId: u32, position: vec3, rotation: f32, anim: u8 }
        local obj = _registry[data.userId]
        if obj then
            obj.CurrentPosition = data.position
            obj.CurrentRotation = data.rotation
            obj.CurrentAnim     = data.anim
        end
    end)

    -- MovementPacket echo: update local player's own position
    Events.On("packet:" .. 0x0002, function(data)
        -- data = { position: vec3, velocity: vec3, rotation: f32 }
        local obj = _localId and _registry[_localId]
        if obj then
            obj.CurrentPosition = data.position
            obj.CurrentVelocity = data.velocity
            obj.CurrentRotation = data.rotation
        end
    end)

    -- Fallback: seed local player from Roblox if no join packet yet
    local rbx = Players.LocalPlayer
    if rbx and not _localId then
        _localId   = rbx.UserId
        _localName = rbx.Name
        local seed = {
            userId   = rbx.UserId,
            name     = rbx.Name,
            position = Vector3.new(0, 0, 0),
        }
        local obj = _register(seed)
        obj.isLocal = true
    end
end

PlayerAPI.Player = Player
return PlayerAPI
