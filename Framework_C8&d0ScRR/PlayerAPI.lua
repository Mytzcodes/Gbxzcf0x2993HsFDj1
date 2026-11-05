-- NXroENinD_DPcKage.PlayerAPI
-- In-game name sourced from:
--   1. Players.LocalPlayer:GetAttribute("GameName")  ← confirmed from decompiled Game.lua
--   2. PlayerJoinPacket(0x0011).name                 ← for other players + fallback
-- Never uses Roblox account name for display.
-- All nil cases handled — no crash under any condition.

local PlayerAPI = {}

local Events      = nil
local _registry   = {}
local _localId    = nil
local _localName  = nil   -- in-game GT name
local _started    = false

-- ── PlayerObject ─────────────────────────────────────────────────────────────

local PlayerObject = {}
PlayerObject.__index = PlayerObject

function PlayerObject.new(data)
    return setmetatable({
        userId          = data.userId  or 0,
        name            = data.name    or "...",
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
    local ok, Pl = pcall(game.GetService, game, "Players")
    if not ok then return nil end
    local rbx = Pl:GetPlayerByUserId(self.userId)
    return rbx and rbx.Character or nil
end

function PlayerObject:GetHRP()
    local char = self:GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

function PlayerObject:DistanceTo(target)
    local pos = (type(target) == "table"   and target.CurrentPosition)
             or (typeof(target) == "Vector3" and target)
    if not pos then return math.huge end
    return (self.CurrentPosition - pos).Magnitude
end

function PlayerObject:__tostring()
    return string.format("PlayerObject[%d] %s @(%.1f,%.1f,%.1f)",
        self.userId, self.name,
        self.CurrentPosition.X, self.CurrentPosition.Y, self.CurrentPosition.Z)
end

-- ── Name resolution (multi-source, priority order) ───────────────────────────

--[[
    _resolveLocalName()
    Try every known source in priority order.
    Returns string name or nil.

    Sources (in order):
      1. Players.LocalPlayer:GetAttribute("GameName")  — set by game server on join
      2. Players.LocalPlayer:GetAttribute("Name")      — fallback attribute
      3. PlayerJoinPacket data already cached
      4. Character nametag BillboardGui TextLabel
]]
local function _resolveLocalName()
    local ok, lp = pcall(function()
        return game:GetService("Players").LocalPlayer
    end)
    if not ok or not lp then return nil end

    -- Source 1: GameName attribute (confirmed in Game.lua line 26)
    local gn = lp:GetAttribute("GameName")
    if type(gn) == "string" and #gn > 0 then
        return gn
    end

    -- Source 2: Generic "Name" attribute (some games use this)
    local attrName = lp:GetAttribute("Name")
    if type(attrName) == "string" and #attrName > 0
       and attrName ~= lp.Name then   -- must differ from Roblox name
        return attrName
    end

    -- Source 3: Character overhead nametag
    local char = lp.Character
    if char then
        -- Check HumanoidRootPart or Head for BillboardGui nametags
        for _, part in ipairs({ "HumanoidRootPart", "Head" }) do
            local p = char:FindFirstChild(part)
            if p then
                for _, desc in ipairs(p:GetDescendants()) do
                    if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                        local t = desc.Text
                        -- Valid in-game name: 2–18 chars, alphanumeric only, not Roblox name
                        if t and #t >= 2 and #t <= 18
                           and t:match("^[%w]+$")
                           and t ~= lp.Name
                           and t ~= lp.DisplayName then
                            return t
                        end
                    end
                end
            end
        end
    end

    -- Source 4: PlayerData folder in player or ReplicatedStorage
    local dataFolder = lp:FindFirstChild("PlayerData")
                    or lp:FindFirstChild("Data")
    if dataFolder then
        for _, child in ipairs(dataFolder:GetChildren()) do
            if (child.Name == "GameName" or child.Name == "GrowName" or child.Name == "IGN")
               and child:IsA("StringValue") and #child.Value > 0 then
                return child.Value
            end
        end
    end

    return nil
end

-- ── Internal helpers ─────────────────────────────────────────────────────────

local function _getRbxLocalId()
    local ok, lp = pcall(function()
        return game:GetService("Players").LocalPlayer
    end)
    return (ok and lp) and lp.UserId or nil
end

local function _register(data)
    if not data or not data.userId then return nil end
    local existing = _registry[data.userId]
    if existing then
        -- Update existing instead of overwriting
        if data.name and data.name ~= "..." then existing.name = data.name end
        if data.position then existing.CurrentPosition = data.position end
        return existing
    end
    local obj = PlayerObject.new(data)
    _registry[data.userId] = obj
    if Events then Events.Emit("player:join", obj) end
    return obj
end

local function _unregister(userId)
    if not userId then return end
    local obj = _registry[userId]
    _registry[userId] = nil
    if obj and Events then Events.Emit("player:leave", obj) end
end

-- ── Active name polling ───────────────────────────────────────────────────────
-- Keeps checking until GameName attribute is set by server (may take 0.5–3s).

local function _startNamePoller()
    task.spawn(function()
        local attempts = 0
        while not _localName and attempts < 60 do   -- max 15s
            attempts += 1
            local name = _resolveLocalName()
            if name then
                _localName = name
                -- Update local player object too
                local obj = _localId and _registry[_localId]
                if obj then obj.name = name end
                print("[NX.PlayerAPI] In-game name resolved: " .. name)

                -- Watch for changes (name update edge case)
                local ok, lp = pcall(function()
                    return game:GetService("Players").LocalPlayer
                end)
                if ok and lp then
                    lp:GetAttributeChangedSignal("GameName"):Connect(function()
                        local newName = lp:GetAttribute("GameName")
                        if type(newName) == "string" and #newName > 0 then
                            _localName = newName
                            local lo = _localId and _registry[_localId]
                            if lo then lo.name = newName end
                            if Events then Events.Emit("player:namechange", newName) end
                        end
                    end)
                end
                return
            end
            task.wait(0.25)
        end
        if not _localName then
            warn("[NX.PlayerAPI] Could not resolve in-game name after 15s.")
        end
    end)
end

-- ── Player() accessor ─────────────────────────────────────────────────────────

local function Player()
    local localObj = _localId and _registry[_localId]
    local list = {}
    for _, o in pairs(_registry) do list[#list + 1] = o end

    return {
        name            = _localName or "...",   -- "..." until server provides GameName
        userId          = _localId or 0,
        CurrentPosition = localObj and localObj.CurrentPosition or Vector3.new(0, 0, 0),
        CurrentVelocity = localObj and localObj.CurrentVelocity or Vector3.new(0, 0, 0),
        CurrentRotation = localObj and localObj.CurrentRotation or 0,
        CurrentAnim     = localObj and localObj.CurrentAnim     or 0,
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

    -- Guard: accept nil gracefully
    if type(eventsModule) == "table" and type(eventsModule.On) == "function" then
        Events = eventsModule
    else
        warn("[NX.PlayerAPI] No Events module — packet hooks disabled.")
    end

    -- Seed local player identity (UserId only, name from poller below)
    local rbxId = _getRbxLocalId()
    if rbxId then
        _localId = rbxId
        if not _registry[rbxId] then
            local obj = PlayerObject.new({ userId = rbxId, name = "..." })
            obj.isLocal = true
            _registry[rbxId] = obj
        end
    end

    -- Immediately try to resolve name, then poll until found
    _localName = _resolveLocalName()
    if _localName then
        local obj = _localId and _registry[_localId]
        if obj then obj.name = _localName end
        print("[NX.PlayerAPI] In-game name: " .. _localName)
    else
        _startNamePoller()   -- background task, checks every 0.25s
    end

    -- Register attribute watcher right away
    local ok, lp = pcall(function()
        return game:GetService("Players").LocalPlayer
    end)
    if ok and lp then
        lp:GetAttributeChangedSignal("GameName"):Connect(function()
            local n = lp:GetAttribute("GameName")
            if type(n) == "string" and #n > 0 then
                _localName = n
                local obj = _localId and _registry[_localId]
                if obj then obj.name = n end
                if Events then Events.Emit("player:namechange", n) end
                print("[NX.PlayerAPI] GameName set: " .. n)
            end
        end)
    end

    if not Events then return end   -- no packet hooks if Events missing

    -- PlayerJoinPacket (0x0011): name + position for all players in world
    Events.On("packet:" .. 0x0011, function(data)
        if not data or not data.userId then return end
        local obj = _register(data)
        if not obj then return end

        -- Check if this is us (match by Roblox UserId)
        if data.userId == _localId then
            if data.name and data.name ~= "..." then
                _localName = data.name
                obj.name   = data.name
            end
            obj.isLocal = true
        end
    end)

    -- PlayerLeave (0x0012)
    Events.On("packet:" .. 0x0012, function(data)
        if data and data.userId then _unregister(data.userId) end
    end)

    -- PlayerUpdate (0x0013): position/rotation/anim for all
    Events.On("packet:" .. 0x0013, function(data)
        if not data or not data.userId then return end
        local obj = _registry[data.userId]
        if not obj then
            -- Player not yet registered — create placeholder
            obj = _register({ userId = data.userId })
        end
        if data.position then obj.CurrentPosition = data.position end
        if data.rotation then obj.CurrentRotation = data.rotation end
        if data.anim     then obj.CurrentAnim     = data.anim     end
    end)

    -- MovementPacket (0x0002): local player velocity
    Events.On("packet:" .. 0x0002, function(data)
        if not data then return end
        local obj = _localId and _registry[_localId]
        if obj then
            if data.position then obj.CurrentPosition = data.position end
            if data.velocity then obj.CurrentVelocity = data.velocity end
            if data.rotation then obj.CurrentRotation = data.rotation end
        end
    end)
end

-- ── Extra: request name manually ─────────────────────────────────────────────

--[[
    PlayerAPI.RequestName()
    Re-scan all sources now and update _localName.
    Call this if name is still "..." after a few seconds.

    NX.PlayerAPI.RequestName()
    task.wait(0.1)
    print(NX.Player().name)
]]
function PlayerAPI.RequestName()
    local n = _resolveLocalName()
    if n then
        _localName = n
        local obj = _localId and _registry[_localId]
        if obj then obj.name = n end
        return n
    end
    return _localName or "..."
end

PlayerAPI.Player = Player
return PlayerAPI
