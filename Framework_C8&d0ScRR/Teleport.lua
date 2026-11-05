--[[
    NXroENinD_DPcKage.Teleport v2.1

    FIXED v2.1:
    - Method 1: Multi-attempt TP (3x with 50ms gap) for reliability
    - Method 3: Waypoint approach (1/3 → 2/3 → target) for far distances
    - Auto-fallback: if direct fails (far), split into approach segments
    - NO coordinate multipliers. Raw tile float coords.
    - All log → Console.ConsoleMsg (visual), never print()
]]

local Teleport = {}

local Events    = nil
local Network   = nil
local World     = nil
local PlayerAPI = nil
local Console   = nil

local STEP_DELAY = 0.08   -- seconds between A* steps
local MAX_NODES  = 3000
local WORLD_W    = 100
local WORLD_H    = 60

local _activeWalk = nil

-- ── Visual log ───────────────────────────────────────────────────────────────

local function _msg(text, color)
    if Console and type(Console.ConsoleMsg) == "function" then
        Console.ConsoleMsg(text, color or "white")
    elseif Events and type(Events.Emit) == "function" then
        Events.Emit("console:message", { text = text, color = color or "white" })
    end
end

-- ── Bounds ───────────────────────────────────────────────────────────────────

local function _clamp(x, y)
    local w = (World and World.GetWidth and World.GetWidth()) or WORLD_W
    local h = (World and World.GetHeight and World.GetHeight()) or WORLD_H
    x = math.clamp(math.floor(tonumber(x) or 0), 1, w - 1)
    y = math.clamp(math.floor(tonumber(y) or 0), 1, h - 1)
    return x, y
end

-- ── Get current position ──────────────────────────────────────────────────────

local function _getCurrentPos()
    if PlayerAPI and type(PlayerAPI.Player) == "function" then
        local p = PlayerAPI.Player()
        if p and p.CurrentPosition then
            local px = p.CurrentPosition.X or p.x or 50
            local py = p.CurrentPosition.Y or p.y or 30
            return math.floor(px), math.floor(py)
        end
    end
    return 50, 30
end

-- ── Send move packet via Net (NO multiplier) ──────────────────────────────────

local _DirectNet = nil
local function _getDirectNet()
    if _DirectNet then return _DirectNet end
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local sh = rs:FindFirstChild("Shared")
        if sh then _DirectNet = require(sh:FindFirstChild("Net")) end
    end)
    return _DirectNet
end

local function _sendMove(tx, ty, vx, vy, isInstant)
    local net = _getDirectNet()
    if net and net.move and type(net.move.send) == "function" then
        pcall(net.move.send, {
            x     = tx,
            y     = ty,
            vx    = vx or 0,
            vy    = vy or 0,
            flags = 2,
            t     = isInstant and 65535 or (math.floor(os.clock() * 1000) % 65534),
        })
        return
    end
    -- Fallback via Network module
    if Network and type(Network.SendPkt) == "function" then
        Network.SendPkt("move", {
            x = tx, y = ty, vx = vx or 0, vy = vy or 0,
            flags = 2,
            t = isInstant and 65535 or (math.floor(os.clock() * 1000) % 65534),
        })
    end
end

-- ── Method 1: Instant Teleport (multi-attempt for reliability) ────────────────
--
-- GrowBlox server may reject a single large-distance move as anti-cheat.
-- Fix: send 3 times with 50ms gap. If distance > 20 tiles, send intermediate
-- waypoints first (approach method built into direct TP).

local function _directTeleport(tx, ty, callback)
    tx, ty = _clamp(tx, ty)

    local sx, sy = _getCurrentPos()
    local dist = math.abs(tx - sx) + math.abs(ty - sy)

    if dist > 20 then
        -- Far target: send 2 intermediate waypoints first
        local m1x = math.floor(sx + (tx - sx) * 0.33)
        local m1y = math.floor(sy + (ty - sy) * 0.33)
        local m2x = math.floor(sx + (tx - sx) * 0.66)
        local m2y = math.floor(sy + (ty - sy) * 0.66)

        _sendMove(m1x, m1y, 0, 0, true)
        task.wait(0.05)
        _sendMove(m2x, m2y, 0, 0, true)
        task.wait(0.05)
    end

    -- Final destination — send 3x for reliability
    _sendMove(tx, ty, 0, 0, true)
    task.wait(0.05)
    _sendMove(tx, ty, 0, 0, true)
    task.wait(0.05)
    _sendMove(tx, ty, 0, 0, true)

    -- Update internal position
    if PlayerAPI and type(PlayerAPI.SetPosition) == "function" then
        PlayerAPI.SetPosition(tx, ty)
    end

    _msg("⚡ Teleport → (" .. tx .. ", " .. ty .. ")", "green")

    if Events and type(Events.Emit) == "function" then
        Events.Emit("teleport:arrive", { x = tx, y = ty, method = 1 })
    end
    if callback then callback(true, { x = tx, y = ty }) end
end

-- ── Method 2: A* Walk ────────────────────────────────────────────────────────

local function _heuristic(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

local function _isSolid(x, y)
    if not World or type(World.GetTile) ~= "function" then return false end
    local tile = World.GetTile(x, y)
    if not tile then return false end
    if type(tile.isSolid) == "function" and tile:isSolid() then return true end
    return false
end

local function _astar(sx, sy, gx, gy, maxW, maxH)
    local open    = {}
    local openSet = {}
    local closed  = {}

    local function key(x, y) return y * 10000 + x end

    local start = { x = sx, y = sy, g = 0, h = _heuristic(sx, sy, gx, gy), parent = nil }
    start.f = start.h
    table.insert(open, start)
    openSet[key(sx, sy)] = start

    local iter = 0
    while #open > 0 do
        iter += 1
        if iter > MAX_NODES then return nil end

        local bestIdx, best = 1, open[1]
        for i = 2, #open do
            if open[i].f < best.f then bestIdx, best = i, open[i] end
        end
        table.remove(open, bestIdx)
        openSet[key(best.x, best.y)] = nil
        closed[key(best.x, best.y)] = true

        if best.x == gx and best.y == gy then
            local path, cur = {}, best
            while cur do
                table.insert(path, 1, { x = cur.x, y = cur.y })
                cur = cur.parent
            end
            return path
        end

        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            local nx, ny = best.x + d[1], best.y + d[2]
            if nx >= 1 and nx <= maxW and ny >= 1 and ny <= maxH then
                local nk = key(nx, ny)
                if not closed[nk] and not _isSolid(nx, ny) then
                    local g = best.g + 1
                    local existing = openSet[nk]
                    if not existing or g < existing.g then
                        local node = {
                            x = nx, y = ny,
                            g = g,
                            h = _heuristic(nx, ny, gx, gy),
                            parent = best,
                        }
                        node.f = node.g + node.h
                        openSet[nk] = node
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

    tx, ty = _clamp(tx, ty)

    local sx, sy = _getCurrentPos()
    local w = (World and World.GetWidth and World.GetWidth()) or WORLD_W
    local h = (World and World.GetHeight and World.GetHeight()) or WORLD_H

    if sx == tx and sy == ty then
        _sendMove(tx, ty, 0, 0, true)
        _msg("✅ Sudah di (" .. tx .. ", " .. ty .. ")", "green")
        if callback then callback(true, { x = tx, y = ty }) end
        return
    end

    local path = _astar(sx, sy, tx, ty, w, h)
    if not path then
        _msg("⚠ Jalur terhalang → direct TP ke (" .. tx .. ", " .. ty .. ")", "yellow")
        _directTeleport(tx, ty, callback)
        return
    end
    if #path <= 1 then
        _directTeleport(tx, ty, callback)
        return
    end

    local handle = { cancelled = false }
    _activeWalk  = handle

    _msg("🚶 Berjalan → (" .. tx .. ", " .. ty .. ") [" .. #path .. " langkah]", "cyan")
    if Events and type(Events.Emit) == "function" then
        Events.Emit("teleport:start", { x = tx, y = ty, steps = #path })
    end

    task.spawn(function()
        for i, node in ipairs(path) do
            if handle.cancelled then return end

            local vx, vy = 0, 0
            if i < #path then
                vx = (path[i+1].x - node.x) * 4
                vy = (path[i+1].y - node.y) * 4
            end

            _sendMove(node.x, node.y, vx, vy, false)

            if PlayerAPI and type(PlayerAPI.SetPosition) == "function" then
                PlayerAPI.SetPosition(node.x, node.y)
            end

            task.wait(STEP_DELAY)
        end

        if not handle.cancelled then
            _activeWalk = nil
            _sendMove(tx, ty, 0, 0, true)
            task.wait(0.05)
            _sendMove(tx, ty, 0, 0, true)   -- double-confirm arrival
            if PlayerAPI and type(PlayerAPI.SetPosition) == "function" then
                PlayerAPI.SetPosition(tx, ty)
            end
            _msg("✅ Sampai di (" .. tx .. ", " .. ty .. ")", "green")
            if Events and type(Events.Emit) == "function" then
                Events.Emit("teleport:arrive", { x = tx, y = ty, method = 2 })
            end
            if callback then callback(true, { x = tx, y = ty }) end
        end
    end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

--[[
    FindPath(x, y, method?, callback?)
    method 1 = instant snap (default) — multi-attempt, approach on far distances
    method 2 = A* smooth walk step by step
]]
function Teleport.FindPath(x, y, method, callback)
    if type(x) ~= "number" or type(y) ~= "number" then
        _msg("❌ FindPath: x dan y harus angka!", "red")
        return { Cancel = function() end }
    end

    method = method or 1

    if method == 2 then
        _waypointWalk(x, y, callback)
        local h = _activeWalk
        return {
            Cancel = function()
                if h then h.cancelled = true end
                if _activeWalk == h then _activeWalk = nil end
                _msg("🛑 Walk dibatalkan", "yellow")
                if Events and type(Events.Emit) == "function" then
                    Events.Emit("teleport:cancel", { x = x, y = y })
                end
            end
        }
    else
        -- Wrap in task.spawn so it doesn't block caller
        task.spawn(function()
            _directTeleport(x, y, callback)
        end)
        return { Cancel = function() end }
    end
end

function Teleport.CancelWalk()
    if _activeWalk then
        _activeWalk.cancelled = true
        _activeWalk = nil
        _msg("🛑 Walk dibatalkan", "yellow")
        if Events and type(Events.Emit) == "function" then
            Events.Emit("teleport:cancel", {})
        end
    end
end

function Teleport.SetStepDelay(s)
    STEP_DELAY = math.clamp(tonumber(s) or 0.08, 0.01, 2.0)
end

-- ── Start ─────────────────────────────────────────────────────────────────────

function Teleport.Start(eventsModule, networkModule, worldModule, playerAPIModule, consoleModule)
    Events    = eventsModule
    Network   = networkModule
    World     = worldModule
    PlayerAPI = playerAPIModule
    Console   = consoleModule
end

return Teleport
