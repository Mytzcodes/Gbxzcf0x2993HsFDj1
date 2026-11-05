-- NXroENinD_DPcKage.PlayerAPI
-- Tracks all players from game packets only (no Roblox Players service dependency).
-- Properties: name, CurrentPosition, CurrentVelocity, CurrentRotation, CurrentAnim

local PlayerAPI = {}

-- Lazy deps (injected via Start)
local Events = nil

local _registry = {}
local _localId  = nil
local _localName = nil
local _started  = false

-- ── PlayerObject ─────────────────────────────────────────────────────────────

local PlayerObject = {}
PlayerObject.__index = PlayerObject

function PlayerObject.new(data)
    return setmetatable({
        userId          = data.userId,
        name            = data.name or ("Player_" .. tostring(data.userId)),
        CurrentPosition = data.position or Vector3.new(0, 0, 0),
        CurrentVelocity = Vector3.new(0, 0, 0),
        CurrentRotation = 0,
        CurrentAnim     = 0,
        ping            = 0,
        isLocal         = false,
        inWorld         = true,
    }, PlayerObject)
end

function PlayerObject:GetPosition()  return self.CurrentPosition end
function PlayerObject:GetVelocity()  return self.CurrentVelocity end
function PlayerObject:GetRotation()  return self.CurrentRotation end

function PlayerObject:GetCharacter()
    local ok, Players = pcall(game.GetService, game, "Players")
    if not ok then return nil end
    local rbx = Players:GetPlayerByUserId(self.userId)
    return rbx and rbx.Character or nil
end

function PlayerObject:GetHRP()
    local char = self:GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

function PlayerObject:DistanceTo(target)
    local pos = (type(target) == "table" and target.CurrentPosition)
             or (typeof(target) == "Vector3" and target)
    if not pos then return math.huge end
    return (self.CurrentPosition - pos).Magnitude
end

function PlayerObject:__tostring()
    return string.format("PlayerObject[%d] %s @(%.1f,%.1f,%.1f)",
        self.userId, self.name,
        self.CurrentPosition.X, self.CurrentPosition.Y, self.CurrentPosition.Z)
end

-- ── Internal ─────────────────────────────────────────────────────────────────

local function _register(data)
    local obj = PlayerObject.new(data)
    _registry[data.userId] = obj
    if Events then Events.Emit("player:join", obj) end
    return obj
end

local function _unregister(userId)
    local obj = _registry[userId]
    _registry[userId] = nil
    if obj and Events then Events.Emit("player:leave", obj) end
end

-- ── Player() accessor ─────────────────────────────────────────────────────────

local function Player()
    local localObj = _localId and _registry[_localId]
    local list = {}
    for _, o in pairs(_registry) do list[#list + 1] = o end

    return {
        name            = _localName or "Unknown",
        userId          = _localId or 0,
        CurrentPosition = localObj and localObj.CurrentPosition or Vector3.new(0, 0, 0),
        CurrentVelocity = localObj and localObj.CurrentVelocity or Vector3.new(0, 0, 0),
        CurrentRotation = localObj and localObj.CurrentRotation or 0,
        CurrentAnim     = localObj and localObj.CurrentAnim or 0,
        list            = list,
        count           = #list,
        ["local"]       = localObj,
        self            = localObj,

        find = function(query)
            if type(query) == "number" then return _registry[query] end
            if type(query) == "string" then
                local q = query:lower()
                for _, o in pairs(_registry) do
                    if o.name:lower():find(q, 1, true) then return o end
                end
            end
        end,

        nearest = function(maxDist)
            if not localObj then return nil, math.huge end
            maxDist = maxDist or math.huge
            local best, bestD = nil, math.huge
            for _, o in pairs(_registry) do
                if not o.isLocal then
                    local d = localObj:DistanceTo(o)
                    if d < bestD and d <= maxDist then best, bestD = o, d end
                end
            end
            return best, bestD
        end,

        forEach = function(fn)
            for _, o in pairs(_registry) do
                if fn(o) == false then break end
            end
        end,
    }
end

-- ── Startup ───────────────────────────────────────────────────────────────────

function PlayerAPI.Start(eventsModule)
    if _started then return end
    _started = true
    Events = eventsModule

    -- PlayerJoin packet (0x0011): name, userId, position from game
    Events.On("packet:" .. 0x0011, function(data)
        local obj = _register(data)
        if not _localId then
            -- Heuristic: match against Roblox LocalPlayer name
            local ok, lp = pcall(function()
                return game:GetService("Players").LocalPlayer
            end)
            if ok and lp and (lp.Name == data.name or lp.DisplayName == data.name) then
                _localId = data.userId
                _localName = data.name
                obj.isLocal = true
            end
        end
    end)

    -- PlayerLeave (0x0012)
    Events.On("packet:" .. 0x0012, function(data)
        _unregister(data.userId)
    end)

    -- PlayerUpdate (0x0013): position/rotation/anim for all players
    Events.On("packet:" .. 0x0013, function(data)
        local obj = _registry[data.userId]
        if obj then
            if data.position then obj.CurrentPosition = data.position end
            if data.rotation then obj.CurrentRotation = data.rotation end
            if data.anim     then obj.CurrentAnim     = data.anim     end
        end
    end)

    -- MovementPacket (0x0002): update local player's own velocity
    Events.On("packet:" .. 0x0002, function(data)
        local obj = _localId and _registry[_localId]
        if obj then
            if data.position then obj.CurrentPosition = data.position end
            if data.velocity then obj.CurrentVelocity = data.velocity end
            if data.rotation then obj.CurrentRotation = data.rotation end
        end
    end)

    -- Fallback: seed from Roblox LocalPlayer if game hasn't sent join packet yet
    local ok, rbx = pcall(function()
        return game:GetService("Players").LocalPlayer
    end)
    if ok and rbx and not _localId then
        _localId = rbx.UserId
        _localName = rbx.Name
        local obj = _register({ userId = rbx.UserId, name = rbx.Name })
        obj.isLocal = true
    end
end

PlayerAPI.Player = Player
return PlayerAPI
