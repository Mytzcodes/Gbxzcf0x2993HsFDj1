-- NXroENinD_DPcKage.Teleport
-- FindPath(x, y, method) — two independent pathfinding methods.
--
--   Method 1 — Direct:    Single MovementPacket teleport. Instant, no steps.
--   Method 2 — Waypoint:  Grid A* walk. Sends incremental MovementPackets
--                         along computed path. Looks natural, respects solids.

local Teleport = {}

local Events   = require(script.Parent.Events)
local Network  = require(script.Parent.Network)
local World    = require(script.Parent.World)
local PlayerAPI = require(script.Parent.PlayerAPI)

-- ── Config ─────────────────────────────────────────────────────────────────
local TILE_SIZE   = 2       -- studs per tile (adjust to actual game scale)
local STEP_DELAY  = 0.08    -- seconds between waypoint steps (method 2)
local MAX_NODES   = 2000    -- A* node budget (prevents infinite loop on huge worlds)

-- ── Helpers ────────────────────────────────────────────────────────────────
local function tileToWorld(tx, ty)
    return Vector3.new(tx * TILE_SIZE, ty * TILE_SIZE, 0)
end

local function worldToTile(pos)
    return math.floor(pos.X / TILE_SIZE), math.floor(pos.Y / TILE_SIZE)
end

local function sendMove(pos, vel, rot)
    Network.SendPkt("MovementPacket", {
        position = pos,
        velocity = vel or Vector3.new(0, 0, 0),
        rotation = rot or 0,
    })
end

-- ── Method 1: Direct teleport ───────────────────────────────────────────────
-- Sends a single MovementPacket to the destination tile.
-- No collision check, instant arrival.
local function _directTeleport(tx, ty, callback)
    local dest = tileToWorld(tx, ty)
    sendMove(dest)
    if callback then callback(true, dest) end
    Events.Emit("teleport:arrive", { x = tx, y = ty, method = 1 })
end

-- ── Method 2: A* Waypoint walk ─────────────────────────────────────────────
-- Computes a grid path avoiding solid tiles, then walks step by step.
-- Each step fires a MovementPacket simulating real movement.

local function _heuristic(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)   -- Manhattan
end

local function _astar(sx, sy, gx, gy)
    -- Node: { x, y, g, h, f, parent }
    local open   = {}
    local closed  = {}
    local nodeKey = function(x, y) return y * 10000 + x end

    local startNode = { x = sx, y = sy, g = 0, h = _heuristic(sx, sy, gx, gy), parent = nil }
    startNode.f = startNode.h
    table.insert(open, startNode)
    local openMap = { [nodeKey(sx, sy)] = startNode }
    local closedMap = {}

    local iterations = 0

    while #open > 0 do
        iterations += 1
        if iterations > MAX_NODES then return nil end   -- safety

        -- Pop lowest f
        local bestIdx, bestNode = 1, open[1]
        for i = 2, #open do
            if open[i].f < bestNode.f then bestIdx, bestNode = i, open[i] end
        end
        table.remove(open, bestIdx)
        openMap[nodeKey(bestNode.x, bestNode.y)] = nil

        local key = nodeKey(bestNode.x, bestNode.y)
        closedMap[key] = true

        if bestNode.x == gx and bestNode.y == gy then
            -- Reconstruct path
            local path = {}
            local cur  = bestNode
            while cur do
                table.insert(path, 1, { x = cur.x, y = cur.y })
                cur = cur.parent
            end
            return path
        end

        -- 4-directional neighbors
        local dirs = { {1,0},{-1,0},{0,1},{0,-1} }
        for _, d in ipairs(dirs) do
            local nx, ny = bestNode.x + d[1], bestNode.y + d[2]
            if not closedMap[nodeKey(nx, ny)] then
                local tile = World.GetTile(nx, ny)
                local walkable = not tile or not tile:isSolid()
                if walkable then
                    local g    = bestNode.g + 1
                    local h    = _heuristic(nx, ny, gx, gy)
                    local f    = g + h
                    local nkey = nodeKey(nx, ny)
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

    return nil  -- no path
end

local _activeWalk = nil   -- handle to cancel ongoing walk

local function _waypointWalk(tx, ty, callback)
    -- Cancel any existing walk
    if _activeWalk then
        _activeWalk.cancelled = true
        _activeWalk = nil
    end

    local p       = PlayerAPI.Player()
    local sx, sy  = worldToTile(p.CurrentPosition)
    local path    = _astar(sx, sy, tx, ty)

    if not path then
        Events.Emit("teleport:npath", { x = tx, y = ty })
        if callback then callback(false, nil) end
        return
    end

    local handle = { cancelled = false }
    _activeWalk  = handle

    Events.Emit("teleport:start", { x = tx, y = ty, steps = #path, method = 2 })

    task.spawn(function()
        for i, node in ipairs(path) do
            if handle.cancelled then return end
            local pos = tileToWorld(node.x, node.y)
            -- Approximate forward velocity direction
            local vel = Vector3.new(0, 0, 0)
            if i < #path then
                local next = path[i + 1]
                local npos = tileToWorld(next.x, next.y)
                vel = (npos - pos).Unit * (TILE_SIZE / STEP_DELAY)
            end
            sendMove(pos, vel)
            task.wait(STEP_DELAY)
        end
        if not handle.cancelled then
            _activeWalk = nil
            local dest  = tileToWorld(tx, ty)
            Events.Emit("teleport:arrive", { x = tx, y = ty, method = 2 })
            if callback then callback(true, dest) end
        end
    end)
end

-- ── Public API ─────────────────────────────────────────────────────────────

--[[
    FindPath(x, y, method, callback?)

    Navigate to tile (x, y) using the specified method.

    method 1 — Direct teleport. Single packet, instant.
    method 2 — A* waypoint walk. Natural movement, respects solid tiles.

    callback(success: bool, arrivedPos: Vector3?)

    Returns for method 2: a cancel handle { Cancel() }

    Examples:
        NX.FindPath(10, 20, 1)                    -- instant
        NX.FindPath(10, 20, 2)                    -- walk
        local h = NX.FindPath(50, 30, 2, function(ok, pos)
            if ok then print("Arrived!") end
        end)
        h.Cancel()   -- abort walk mid-way
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
                Events.Emit("teleport:cancel", { x = x, y = y })
            end
        }
    else
        error("FindPath: method must be 1 (direct) or 2 (waypoint)")
    end
end

--[[
    CancelWalk()
    Cancel any active method-2 walk immediately.
]]
function Teleport.CancelWalk()
    if _activeWalk then
        _activeWalk.cancelled = true
        _activeWalk = nil
        Events.Emit("teleport:cancel", {})
    end
end

--[[
    SetStepDelay(seconds)
    Tune method-2 walking speed. Default 0.08s.
]]
function Teleport.SetStepDelay(s)
    STEP_DELAY = s
end

--[[
    SetTileSize(studs)
    Adjust if world uses different tile dimensions. Default 2.
]]
function Teleport.SetTileSize(s)
    TILE_SIZE = s
end

return Teleport
