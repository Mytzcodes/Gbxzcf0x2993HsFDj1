-- NXroENinD_DPcKage.Teleport
-- FindPath(x, y, method, callback?) — two independent methods.
--
--   Method 1 — Direct:   Single MovementPacket. Instant teleport.
--   Method 2 — Waypoint: Grid A* walk with incremental MovementPackets.
--
-- Deps injected via Start().

local Teleport = {}

local Events    = nil   -- injected
local Network   = nil   -- injected
local World     = nil   -- injected
local PlayerAPI = nil   -- injected

local TILE_SIZE  = 2        -- studs per tile
local STEP_DELAY = 0.08     -- seconds between waypoint steps (method 2)
local MAX_NODES  = 2000     -- A* budget

local _activeWalk = nil

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function tileToWorld(tx, ty)
    return Vector3.new(tx * TILE_SIZE, ty * TILE_SIZE, 0)
end

local function worldToTile(pos)
    return math.floor(pos.X / TILE_SIZE), math.floor(pos.Y / TILE_SIZE)
end

local function sendMove(pos, vel, rot)
    if Network then
        Network.SendPkt("MovementPacket", {
            position = pos,
            velocity = vel or Vector3.new(0, 0, 0),
            rotation = rot or 0,
        })
    end
end

-- ── Method 1: Direct teleport ────────────────────────────────────────────────

local function _directTeleport(tx, ty, callback)
    local dest = tileToWorld(tx, ty)
    sendMove(dest)
    if callback then callback(true, dest) end
    if Events then Events.Emit("teleport:arrive", { x = tx, y = ty, method = 1 }) end
end

-- ── Method 2: A* Waypoint walk ───────────────────────────────────────────────

local function _heuristic(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

local function _astar(sx, sy, gx, gy)
    local open      = {}
    local openMap   = {}
    local closedMap = {}
    local nodeKey   = function(x, y) return y * 10000 + x end

    local startNode = { x = sx, y = sy, g = 0, h = _heuristic(sx, sy, gx, gy), parent = nil }
    startNode.f = startNode.h
    table.insert(open, startNode)
    openMap[nodeKey(sx, sy)] = startNode

    local iter = 0

    while #open > 0 do
        iter += 1
        if iter > MAX_NODES then return nil end

        local bestIdx, bestNode = 1, open[1]
        for i = 2, #open do
            if open[i].f < bestNode.f then bestIdx, bestNode = i, open[i] end
        end
        table.remove(open, bestIdx)
        openMap[nodeKey(bestNode.x, bestNode.y)] = nil

        closedMap[nodeKey(bestNode.x, bestNode.y)] = true

        if bestNode.x == gx and bestNode.y == gy then
            local path, cur = {}, bestNode
            while cur do table.insert(path, 1, { x = cur.x, y = cur.y }); cur = cur.parent end
            return path
        end

        for _, d in ipairs({ {1,0},{-1,0},{0,1},{0,-1} }) do
            local nx, ny = bestNode.x + d[1], bestNode.y + d[2]
            local nkey   = nodeKey(nx, ny)
            if not closedMap[nkey] then
                local walkable = true
                if World then
                    local tile = World.GetTile(nx, ny)
                    if tile and tile:isSolid() then walkable = false end
                end
                if walkable then
                    local g    = bestNode.g + 1
                    local h    = _heuristic(nx, ny, gx, gy)
                    local f    = g + h
                    local existing = openMap[nkey]
                    if not existing or g < existing.g then
                        local node = { x=nx, y=ny, g=g, h=h, f=f, parent=bestNode }
                        openMap[nkey] = node
                        table.insert(open, node)
                    end
                end
            end
        end
    end

    return nil
end

local function _waypointWalk(tx, ty, callback)
    if _activeWalk then
        _activeWalk.cancelled = true
        _activeWalk = nil
    end

    local p      = PlayerAPI and PlayerAPI.Player() or { CurrentPosition = Vector3.new(0,0,0) }
    local sx, sy = worldToTile(p.CurrentPosition)
    local path   = _astar(sx, sy, tx, ty)

    if not path then
        if Events then Events.Emit("teleport:npath", { x = tx, y = ty }) end
        if callback then callback(false, nil) end
        return
    end

    local handle = { cancelled = false }
    _activeWalk  = handle

    if Events then Events.Emit("teleport:start", { x = tx, y = ty, steps = #path, method = 2 }) end

    task.spawn(function()
        for i, node in ipairs(path) do
            if handle.cancelled then return end
            local pos = tileToWorld(node.x, node.y)
            local vel = Vector3.new(0, 0, 0)
            if i < #path then
                local npos = tileToWorld(path[i+1].x, path[i+1].y)
                vel = (npos - pos).Unit * (TILE_SIZE / STEP_DELAY)
            end
            sendMove(pos, vel)
            task.wait(STEP_DELAY)
        end
        if not handle.cancelled then
            _activeWalk = nil
            local dest  = tileToWorld(tx, ty)
            if Events then Events.Emit("teleport:arrive", { x = tx, y = ty, method = 2 }) end
            if callback then callback(true, dest) end
        end
    end)
end

-- ── Public API ───────────────────────────────────────────────────────────────

--[[
    FindPath(x, y, method, callback?) → { Cancel() }

    Navigate to tile (x, y).
    method 1 = instant single-packet teleport.
    method 2 = A* step-by-step walk (looks natural, respects solid tiles).
    callback(success: bool, arrivedPos: Vector3?)

    NX.FindPath(10, 20, 1)                        -- instant
    NX.FindPath(10, 20, 2)                        -- walk
    local h = NX.FindPath(50, 30, 2, function(ok) print(ok) end)
    h.Cancel()
]]
function Teleport.FindPath(x, y, method, callback)
    assert(type(x) == "number" and type(y) == "number", "FindPath: x, y must be numbers")
    method = method or 1

    if method == 1 then
        _directTeleport(x, y, callback)
        return { Cancel = function() end }
    elseif method == 2 then
        _waypointWalk(x, y, callback)
        local handle = _activeWalk
        return {
            Cancel = function()
                if handle then handle.cancelled = true end
                if _activeWalk == handle then _activeWalk = nil end
                if Events then Events.Emit("teleport:cancel", { x = x, y = y }) end
            end
        }
    else
        error("FindPath: method must be 1 (direct) or 2 (waypoint)")
    end
end

--[[
    CancelWalk()
    Cancel any active method-2 walk.

    NX.CancelWalk()
]]
function Teleport.CancelWalk()
    if _activeWalk then
        _activeWalk.cancelled = true
        _activeWalk = nil
        if Events then Events.Emit("teleport:cancel", {}) end
    end
end

--[[
    SetStepDelay(seconds)
    Tune method-2 walking speed. Default 0.08s.
]]
function Teleport.SetStepDelay(s) STEP_DELAY = s end

--[[
    SetTileSize(studs)
    Adjust if world uses different tile dimensions. Default 2.
]]
function Teleport.SetTileSize(s) TILE_SIZE = s end

-- ── Startup ───────────────────────────────────────────────────────────────────

function Teleport.Start(eventsModule, networkModule, worldModule, playerAPIModule)
    Events    = eventsModule
    Network   = networkModule
    World     = worldModule
    PlayerAPI = playerAPIModule
end

return Teleport
