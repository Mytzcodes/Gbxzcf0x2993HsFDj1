-- NXroENinD_DPcKage.Teleport
-- FindPath(x, y, method, callback?)
-- Method 1 = direct single-packet teleport.
-- Method 2 = A* step-by-step walk.
-- All status messages go to NX.ConsoleMsg (visual), NOT print.

local Teleport = {}

local Events    = nil
local Network   = nil
local World     = nil
local PlayerAPI = nil
local Console   = nil   -- injected for visual output

local TILE_SIZE  = 2
local STEP_DELAY = 0.08
local MAX_NODES  = 2000

local _activeWalk = nil

-- ── Visual log helper ─────────────────────────────────────────────────────────
-- Uses Console.ConsoleMsg if available, falls back to print silently.

local function _log(text, color)
    if Console and type(Console.ConsoleMsg) == "function" then
        Console.ConsoleMsg(text, color or "gray")
    end
    -- No print — stays out of Roblox output log
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

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

-- ── Method 1: Direct teleport ─────────────────────────────────────────────────

local function _directTeleport(tx, ty, callback)
    local dest = tileToWorld(tx, ty)
    sendMove(dest)
    _log("Teleport → (" .. tx .. ", " .. ty .. ")", "cyan")
    if callback then callback(true, dest) end
    if Events then Events.Emit("teleport:arrive", { x = tx, y = ty, method = 1 }) end
end

-- ── Method 2: A* Waypoint walk ────────────────────────────────────────────────

local function _heuristic(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

local function _astar(sx, sy, gx, gy)
    local open      = {}
    local openMap   = {}
    local closedMap = {}
    local function nodeKey(x, y) return y * 10000 + x end

    local startNode = { x=sx, y=sy, g=0, h=_heuristic(sx,sy,gx,gy), parent=nil }
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
            while cur do table.insert(path, 1, {x=cur.x, y=cur.y}); cur = cur.parent end
            return path
        end

        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            local nx_, ny_ = bestNode.x + d[1], bestNode.y + d[2]
            local nkey     = nodeKey(nx_, ny_)
            if not closedMap[nkey] then
                local walkable = true
                if World then
                    local tile = World.GetTile(nx_, ny_)
                    if tile and tile:isSolid() then walkable = false end
                end
                if walkable then
                    local g = bestNode.g + 1
                    local h = _heuristic(nx_, ny_, gx, gy)
                    local existing = openMap[nkey]
                    if not existing or g < existing.g then
                        local node = {x=nx_, y=ny_, g=g, h=h, f=g+h, parent=bestNode}
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
        _log("FindPath: tidak ada jalur ke (" .. tx .. ", " .. ty .. ")", "red")
        if Events then Events.Emit("teleport:npath", { x=tx, y=ty }) end
        if callback then callback(false, nil) end
        return
    end

    local handle = { cancelled = false }
    _activeWalk  = handle

    _log("Jalan ke (" .. tx .. ", " .. ty .. ") — " .. #path .. " langkah", "cyan")
    if Events then Events.Emit("teleport:start", { x=tx, y=ty, steps=#path, method=2 }) end

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
            _log("Sampai di (" .. tx .. ", " .. ty .. ")", "green")
            if Events then Events.Emit("teleport:arrive", { x=tx, y=ty, method=2 }) end
            if callback then callback(true, dest) end
        end
    end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

--[[
    FindPath(x, y, method, callback?) → { Cancel() }

    method 1 = instant teleport (single MovementPacket).
    method 2 = A* step walk, natural movement, respects solid tiles.
    callback(success: bool, arrivedPos: Vector3?)

    NX.FindPath(10, 20, 1)
    local h = NX.FindPath(50, 30, 2, function(ok) print(ok) end)
    h.Cancel()
]]
function Teleport.FindPath(x, y, method, callback)
    if type(x) ~= "number" or type(y) ~= "number" then
        _log("FindPath: x dan y harus angka", "red")
        return { Cancel = function() end }
    end
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
                _log("Walk dibatalkan", "yellow")
                if Events then Events.Emit("teleport:cancel", { x=x, y=y }) end
            end
        }
    else
        _log("FindPath: method harus 1 atau 2", "red")
        return { Cancel = function() end }
    end
end

function Teleport.CancelWalk()
    if _activeWalk then
        _activeWalk.cancelled = true
        _activeWalk = nil
        _log("Walk dibatalkan", "yellow")
        if Events then Events.Emit("teleport:cancel", {}) end
    end
end

function Teleport.SetStepDelay(s)  STEP_DELAY = s end
function Teleport.SetTileSize(s)   TILE_SIZE  = s end

-- ── Startup ───────────────────────────────────────────────────────────────────

function Teleport.Start(eventsModule, networkModule, worldModule, playerAPIModule, consoleModule)
    Events    = eventsModule
    Network   = networkModule
    World     = worldModule
    PlayerAPI = playerAPIModule
    Console   = consoleModule
end

return Teleport
