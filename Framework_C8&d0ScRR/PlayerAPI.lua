--[[
    NXroENinD_DPcKage.PlayerAPI v2.0
    
    - Reads IGN from GetAttribute("GameName") — NOT Roblox display name
    - Hooks Net.entered, Net.moved, Net.left for real-time player registry
    - RequestName() force-polls all sources immediately
    - Zero crash guarantee — all nil guarded
]]

local PlayerAPI = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Events     = nil
local _registry  = {}
local _localId   = nil
local _localName = nil
local _localPos  = {X = 50, Y = 30}
local _started   = false

-- ── PlayerObject ─────────────────────────────────────────────────────────────

local PlayerObject = {}
PlayerObject.__index = PlayerObject

function PlayerObject.new(data)
    return setmetatable({
        userId          = data.userId or 0,
        id              = data.id or 0,
        name            = data.name or "...",
        CurrentPosition = Vector3.new(data.x or 0, data.y or 0, 0),
        CurrentVelocity = Vector3.new(data.vx or 0, data.vy or 0, 0),
        isLocal         = false,
        inWorld         = true,
        country         = data.country or "",
        skin            = data.skin or 0,
    }, PlayerObject)
end

function PlayerObject:GetPosition() return self.CurrentPosition end
function PlayerObject:GetVelocity() return self.CurrentVelocity end
function PlayerObject:DistanceTo(target)
    local pos
    if type(target) == "table" then
        pos = target.CurrentPosition or Vector3.new(target.x or 0, target.y or 0, 0)
    elseif typeof(target) == "Vector3" then
        pos = target
    end
    if not pos then return math.huge end
    return (self.CurrentPosition - pos).Magnitude
end

-- ── Name resolution (GameName attribute first) ────────────────────────────────

local function _resolveLocalName()
    local lp = Players.LocalPlayer
    if not lp then return nil end

    -- Priority 1: GameName attribute (set by server on world join)
    local gn = lp:GetAttribute("GameName")
    if type(gn) == "string" and #gn > 0 then
        return gn
    end

    -- Priority 2: Look at net.entered data we may have cached
    -- (handled by _localName being set in Start())

    -- Priority 3: BillboardGui nametag on character
    local char = lp.Character
    if char then
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") or part:IsA("Model") then
                for _, desc in ipairs(part:GetDescendants()) do
                    if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text ~= "" then
                        local t = desc.Text:match("^[%w]+$")
                        if t and #t >= 2 and #t <= 18 and t ~= lp.Name then
                            return t
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- ── Registry helpers ─────────────────────────────────────────────────────────

local function _register(data)
    if not data or (not data.userId and not data.id) then return nil end
    local key = data.userId or data.id
    local existing = _registry[key]
    if existing then
        if data.name and data.name ~= "..." then existing.name = data.name end
        if data.x and data.y then
            existing.CurrentPosition = Vector3.new(data.x, data.y, 0)
        end
        return existing
    end
    local obj = PlayerObject.new(data)
    _registry[key] = obj
    if Events and type(Events.Emit) == "function" then
        Events.Emit("player:join", obj)
    end
    return obj
end

-- ── Player() snapshot ─────────────────────────────────────────────────────────

local function Player()
    local localObj = _localId and _registry[_localId]
    local name = _localName or _resolveLocalName() or "..."
    local pos = (localObj and localObj.CurrentPosition) or Vector3.new(_localPos.X, _localPos.Y, 0)

    local list = {}
    for _, o in pairs(_registry) do list[#list + 1] = o end

    return {
        name            = name,
        userId          = _localId or (Players.LocalPlayer and Players.LocalPlayer.UserId or 0),
        CurrentPosition = pos,
        CurrentVelocity = (localObj and localObj.CurrentVelocity) or Vector3.new(0, 0, 0),
        x               = pos.X,
        y               = pos.Y,
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
            return nil
        end,

        nearest = function(maxDist)
            maxDist = maxDist or math.huge
            local best, bestD = nil, math.huge
            for _, o in pairs(_registry) do
                if not o.isLocal then
                    local d = (pos - o.CurrentPosition).Magnitude
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

-- ── Start ─────────────────────────────────────────────────────────────────────

function PlayerAPI.Start(eventsModule)
    if _started then return end
    _started = true

    if type(eventsModule) == "table" and type(eventsModule.On) == "function" then
        Events = eventsModule
    end

    local lp = Players.LocalPlayer
    if not lp then return end

    local myId = lp.UserId
    _localId = myId

    -- Pre-register stub
    local localObj = PlayerObject.new({ userId = myId, name = "..." })
    localObj.isLocal = true
    _registry[myId] = localObj

    -- Immediately try to get GameName
    _localName = _resolveLocalName()
    if _localName then
        localObj.name = _localName
    end

    -- Watch for GameName attribute change (set when entering a world)
    pcall(function()
        lp:GetAttributeChangedSignal("GameName"):Connect(function()
            local gn = lp:GetAttribute("GameName")
            if type(gn) == "string" and #gn > 0 then
                _localName = gn
                localObj.name = gn
                if Events and type(Events.Emit) == "function" then
                    Events.Emit("player:namechange", gn)
                end
            end
        end)
    end)

    -- Hook ReplicatedStorage.Shared.Net for player events
    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        if not shared then return end
        local netMod = shared:FindFirstChild("Net")
        if not netMod then return end
        local Net = require(netMod)
        if not Net then return end

        -- net.entered: someone joined the world
        if Net.entered and type(Net.entered.listen) == "function" then
            Net.entered.listen(function(p)
                if not p then return end
                local obj = _register({
                    userId  = p.userId,
                    id      = p.id,
                    name    = p.name,
                    country = p.country,
                    skin    = p.skin,
                })
                -- If this is us, capture our IGN from server data
                if p.userId == myId and p.name and #p.name > 0 then
                    _localName = p.name
                    if obj then obj.name = p.name; obj.isLocal = true end
                    if Events and type(Events.Emit) == "function" then
                        Events.Emit("player:namechange", p.name)
                    end
                end
            end)
        end

        -- net.moved: other player moved
        if Net.moved and type(Net.moved.listen) == "function" then
            Net.moved.listen(function(p)
                if not p or not p.id then return end
                for _, obj in pairs(_registry) do
                    if obj.id == p.id then
                        obj.CurrentPosition = Vector3.new(p.x or 0, p.y or 0, 0)
                        obj.CurrentVelocity = Vector3.new(p.vx or 0, p.vy or 0, 0)
                        break
                    end
                end
            end)
        end

        -- net.left: player left world
        if Net.left and type(Net.left.listen) == "function" then
            Net.left.listen(function(pid)
                for key, obj in pairs(_registry) do
                    if obj.id == pid or key == pid then
                        _registry[key] = nil
                        if Events and type(Events.Emit) == "function" then
                            Events.Emit("player:leave", obj)
                        end
                        break
                    end
                end
            end)
        end
    end)

    -- Fallback: poll GameName every 2s until we get it
    if not _localName then
        task.spawn(function()
            for _ = 1, 30 do
                task.wait(2)
                if _localName then break end
                local gn = _resolveLocalName()
                if gn then
                    _localName = gn
                    localObj.name = gn
                    if Events and type(Events.Emit) == "function" then
                        Events.Emit("player:namechange", gn)
                    end
                    break
                end
            end
        end)
    end
end

-- ── Public API ───────────────────────────────────────────────────────────────

--[[
    RequestName()
    Force-resolves IGN right now from all sources.
    Returns the name string.
]]
function PlayerAPI.RequestName()
    local n = _resolveLocalName()
    if n and #n > 0 then
        _localName = n
        local lo = _localId and _registry[_localId]
        if lo then lo.name = n end
        return n
    end
    return _localName or "..."
end

--[[
    SetPosition(x, y)
    Update internal local position estimate (for A* path start).
]]
function PlayerAPI.SetPosition(x, y)
    _localPos = { X = x or 50, Y = y or 30 }
    local lo = _localId and _registry[_localId]
    if lo then lo.CurrentPosition = Vector3.new(x, y, 0) end
end

PlayerAPI.Player = Player
return PlayerAPI
