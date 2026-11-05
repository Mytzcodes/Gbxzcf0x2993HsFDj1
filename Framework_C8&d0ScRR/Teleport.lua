--[[
    NXroENinD_DPcKage.Teleport v2.0
    FindPath(x, y, method?, callback?)

    FIXED:
    - NO coordinate multipliers. GrowBlox uses raw tile float coords.
    - Net.move.send({x=44, y=37, ...}) moves to tile 44,37. Period.
    - method 1 = instant snap (t=65535)
    - method 2 = A* walk step by step

    All log output goes through Console.ConsoleMsg (visual in-game),
    never to developer console print.
]]

local Teleport = {}

local Events    = nil
local Network   = nil
local World     = nil
local PlayerAPI = nil
local Console   = nil

local STEP_DELAY = 0.08   -- seconds between A* steps
local MAX_NODES  = 3000   -- max A* iterations
local WORLD_W    = 100    -- default world width in tiles
local WORLD_H    = 60     -- default world height in tiles

local _activeWalk = nil

-- ── Visual log ───────────────────────────────────────────────────────────────

local function _msg(text, color)
    if Console and type(Console.ConsoleMsg) == "function" then
        Console.ConsoleMsg(text, color or "white")
    elseif Events and type(Events.Emit) == "function" then
        Events.Emit("console:message", { text = text, color = color or "white" })
    end
    -- Do NOT print() — visual only
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

-- ── Send move packet via Net (NO multiplier) ───────────────────────────────────

local function _sendMove(tx, ty, vx, vy, isInstant)
    -- Use Network module if available
    if Network and type(Network.SendPkt) == "function" then
        Network.SendPkt("move", {
            x     = tx,            -- raw tile coord, e.g. 44.0
            y     = ty,            -- raw tile coord, e.g. 37.0
            vx    = vx or 0,
            vy    = vy or 0,
            flags = 2,             -- grounded
            t     = isInstant and 65535 or (math.floor(os.clock() * 1000) % 65534),
        })
        return
    end

    -- Direct fallback if Network not injected
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local sh = rs:FindFirstChild("Shared")
        if not sh then return end
        local nm = sh:FindFirstChild("Net")
        if not nm then return end
        local Net = require(nm)
        if Net and Net.move and type(Net.move.send) == "function" then
            Net.move.send({
                x     = tx,
                y     = ty,
                vx    = vx or 0,
                vy    = vy or 0,
                flags = 2,
                t     = isInstant and 65535 or (math.floor(os.clock() * 1000) % 65534),
            })
        end
    end)
end

-- ── Method 1: Instant Teleport ────────────────────────────────────────────────

local function _directTeleport(tx, ty, callback)
    tx, ty = _clamp(tx, ty)
    _sendMove(tx, ty, 0, 0, true)

    -- Update internal position estimate
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
    local openSet = {}   -- key -> node
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

        -- Find lowest f
        local bestIdx, best = 1, open[1]
        for i = 2, #open do
            if open[i].f < best.f then bestIdx, best = i, open[i] end
        end
        table.remove(open, bestIdx)
        openSet[key(best.x, best.y)] = nil
        closed[key(best.x, best.y)] = true

        -- Reached goal?
        if best.x == gx and best.y == gy then
            local path, cur = {}, best
            while cur do
                table.insert(path, 1, { x = cur.x, y = cur.y })
                cur = cur.parent
            end
            return path
        end

        -- Expand neighbors (4-directional)
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
    return nil  -- no path
end

local function _waypointWalk(tx, ty, callback)
    -- Cancel existing walk
    if _activeWalk then
        _activeWalk.cancelled = true
        _activeWalk = nil
    end

    tx, ty = _clamp(tx, ty)

    local sx, sy = _getCurrentPos()
    local w = (World and World.GetWidth and World.GetWidth()) or WORLD_W
    local h = (World and World.GetHeight and World.GetHeight()) or WORLD_H

    -- If already there, snap
    if sx == tx and sy == ty then
        _sendMove(tx, ty, 0, 0, true)
        _msg("✅ Sudah di (" .. tx .. ", " .. ty .. ")", "green")
        if callback then callback(true, { x = tx, y = ty }) end
        return
    end

    local path = _astar(sx, sy, tx, ty, w, h)
    if not path then
        _msg("⚠ Jalur terhalang, direct teleport → (" .. tx .. ", " .. ty .. ")", "yellow")
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

            -- Update internal position
            if PlayerAPI and type(PlayerAPI.SetPosition) == "function" then
                PlayerAPI.SetPosition(node.x, node.y)
            end

            task.wait(STEP_DELAY)
        end

        if not handle.cancelled then
            _activeWalk = nil
            _sendMove(tx, ty, 0, 0, true)   -- final snap
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
    x, y    : tile coordinates (integers). World is typically 100 × 60.
    method  : 1 = instant snap (default), 2 = A* smooth walk
    callback: function(success, {x, y}) called on arrival
    
    Returns handle with :Cancel() method
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
        _directTeleport(x, y, callback)
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
