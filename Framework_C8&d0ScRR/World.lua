-- NXroENinD_DPcKage.World
-- GetWorld / GetTile / FindTiles / TileAt
-- Deps injected via Start().

local World = {}

local Events = nil   -- injected

local _world = nil
local _tiles = {}    -- [y][x] = TileObject
local _started = false
local TILE_SIZE = 2  -- studs per tile

local function _makeTile(raw, x, y)
    return {
        x          = x,
        y          = y,
        foreground = raw.fg          or 0,
        background = raw.bg          or 0,
        flags      = raw.flags       or 0,
        growth     = raw.growthStage or 0,
        water      = raw.waterLevel  or 0,
        lockOwner  = raw.lockOwner   or 0,

        isSolid  = function(self) return bit32.band(self.flags, 0x001)    ~= 0 end,
        isLocked = function(self) return bit32.band(self.flags, 0x010)    ~= 0 end,
        isDoor   = function(self) return bit32.band(self.flags, 0x040000) ~= 0 end,
        isTree   = function(self) return bit32.band(self.flags, 0x4000)   ~= 0 end,
        hasSign  = function(self) return bit32.band(self.flags, 0x2000)   ~= 0 end,
        isPublic = function(self) return bit32.band(self.flags, 0x400)    ~= 0 end,
        isEmpty  = function(self) return self.foreground == 0 and self.background == 0 end,
    }
end

-- ── Public API ───────────────────────────────────────────────────────────────

--[[
    GetWorld() → WorldData | nil
    Fields: name, width, height, ownerId, weatherType, weatherIntensity

    local w = NX.GetWorld()
    if w then print(w.name, w.width.."x"..w.height) end
]]
function World.GetWorld()
    return _world
end

--[[
    GetTile(x, y) → TileObject | nil
    Grid coords (0-indexed). TileObject has: foreground, background, flags,
    growth, water, lockOwner, isSolid(), isLocked(), isDoor(), isTree(), etc.

    local tile = NX.GetTile(10, 20)
    if tile and tile:isLocked() then print("locked!") end
]]
function World.GetTile(x, y)
    local row = _tiles[y]
    return row and row[x] or nil
end

--[[
    FindTiles(predicate) → array of TileObject
    predicate(TileObject) → bool

    local trees = NX.FindTiles(function(t) return t:isTree() end)
    local locked = NX.FindTiles(function(t) return t:isLocked() end)
    local dirt   = NX.FindTiles(function(t) return t.foreground == 2 end)
]]
function World.FindTiles(predicate)
    local result = {}
    for _, row in pairs(_tiles) do
        for _, tile in pairs(row) do
            if predicate(tile) then result[#result+1] = tile end
        end
    end
    return result
end

--[[
    TileAt(worldPos) → TileObject | nil
    Convert Vector3 world position to tile coords and return TileObject.

    local tile = NX.TileAt(NX.Player().CurrentPosition)
    print("Standing on fg:", tile and tile.foreground or "air")
]]
function World.TileAt(worldPos)
    if not _world then return nil end
    local tx = math.floor(worldPos.X / TILE_SIZE)
    local ty = math.floor(worldPos.Y / TILE_SIZE)
    return World.GetTile(tx, ty)
end

-- ── Internal parsers ─────────────────────────────────────────────────────────

local function _parseWorldData(data)
    _world = {
        name             = data.name             or "UNKNOWN",
        width            = data.width            or 100,
        height           = data.height           or 60,
        ownerId          = data.ownerId          or 0,
        weatherType      = data.weatherType      or 0,
        weatherIntensity = data.weatherIntensity or 0,
    }
    _tiles = {}
    if Events then Events.Emit("world:loaded", _world) end
end

local function _applyTileUpdate(data)
    if not _tiles[data.y] then _tiles[data.y] = {} end
    local existing = _tiles[data.y][data.x]
    if existing then
        existing.foreground = data.fg    or existing.foreground
        existing.background = data.bg    or existing.background
        existing.flags      = data.flags or existing.flags
    else
        _tiles[data.y][data.x] = _makeTile({
            fg = data.fg, bg = data.bg, flags = data.flags
        }, data.x, data.y)
    end
    if Events then Events.Emit("tile:update", _tiles[data.y][data.x]) end
end

local function _applyGrowth(data)
    local row  = _tiles[data.y]
    local tile = row and row[data.x]
    if tile then
        tile.growth = data.stage
        if Events then Events.Emit("tile:growth", tile) end
    end
end

-- ── Startup ───────────────────────────────────────────────────────────────────

function World.Start(eventsModule)
    if _started then return end
    _started = true
    Events = eventsModule

    Events.On("packet:" .. 0x000E, _parseWorldData)   -- WorldDataPacket
    Events.On("packet:" .. 0x000F, _applyTileUpdate)  -- TileUpdatePacket
    Events.On("packet:" .. 0x0024, _applyGrowth)      -- GrowthUpdatePacket
end

return World
