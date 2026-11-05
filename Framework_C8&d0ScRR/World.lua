--[[
    NXroENinD_DPcKage.World v2.0
    GetWorld / GetTile / FindTiles / TileAt
    
    FIXED: TILE_SIZE removed from TileAt() — GrowBlox uses RAW tile coordinates.
    World positions are already in tile units (not pixels).
    Fully guarded — won't crash if Events is nil.
]]

local World = {}

local Events   = nil
local _world   = nil
local _tiles   = {}   -- [y][x] = tile
local _started = false

-- ── Tile object constructor ───────────────────────────────────────────────────

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

function World.GetWorld()
    return _world
end

function World.GetTile(x, y)
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    local row = _tiles[y]
    return row and row[x] or nil
end

function World.FindTiles(predicate)
    local result = {}
    for _, row in pairs(_tiles) do
        for _, tile in pairs(row) do
            if predicate(tile) then
                result[#result + 1] = tile
            end
        end
    end
    return result
end

--[[
    TileAt(worldPos)
    worldPos: Vector3 or {X, Y} in TILE coordinates (NOT pixels).
    GrowBlox tile coords are raw floats (e.g. x=44.3, y=37.8).
    No TILE_SIZE multiplication needed.
]]
function World.TileAt(worldPos)
    if not worldPos then return nil end
    local tx = math.floor(worldPos.X or worldPos.x or 0)
    local ty = math.floor(worldPos.Y or worldPos.y or 0)
    return World.GetTile(tx, ty)
end

function World.GetWidth()
    return _world and _world.width or 100
end

function World.GetHeight()
    return _world and _world.height or 60
end

-- ── Internal parsers ─────────────────────────────────────────────────────────

local function _parseWorldData(data)
    if not data then return end
    _world = {
        name             = data.name             or "UNKNOWN",
        width            = data.width            or 100,
        height           = data.height           or 60,
        ownerId          = data.ownerId          or 0,
        weatherType      = data.weatherType      or 0,
        weatherIntensity = data.weatherIntensity or 0,
    }
    _tiles = {}
    if Events and type(Events.Emit) == "function" then
        Events.Emit("world:loaded", _world)
    end
end

local function _applyTileUpdate(data)
    if not data or data.x == nil or data.y == nil then return end
    local x, y = math.floor(data.x), math.floor(data.y)
    if not _tiles[y] then _tiles[y] = {} end
    local existing = _tiles[y][x]
    if existing then
        if data.fg    ~= nil then existing.foreground = data.fg    end
        if data.bg    ~= nil then existing.background = data.bg    end
        if data.flags ~= nil then existing.flags      = data.flags end
        if data.id    ~= nil then existing.foreground = data.id    end
    else
        _tiles[y][x] = _makeTile({
            fg    = data.fg or data.id or 0,
            bg    = data.bg or 0,
            flags = data.flags or 0,
        }, x, y)
    end
    if Events and type(Events.Emit) == "function" then
        Events.Emit("tile:update", _tiles[y][x])
    end
end

local function _applyGrowth(data)
    if not data or data.x == nil or data.y == nil then return end
    local x, y = math.floor(data.x), math.floor(data.y)
    local row  = _tiles[y]
    local tile = row and row[x]
    if tile then
        tile.growth = data.stage or data.p or 0
        if Events and type(Events.Emit) == "function" then
            Events.Emit("tile:growth", tile)
        end
    end
end

-- ── Start ─────────────────────────────────────────────────────────────────────

function World.Start(eventsModule)
    if _started then return end
    _started = true

    -- Guard: eventsModule is optional
    if type(eventsModule) ~= "table" or type(eventsModule.On) ~= "function" then
        warn("[NX.World] Start() called without valid Events module — packet hooks disabled.")
        return
    end
    Events = eventsModule

    Events.On("packet:14",   _parseWorldData)   -- WorldDataPacket 0x000E = 14
    Events.On("packet:15",   _applyTileUpdate)  -- TileUpdatePacket 0x000F = 15
    Events.On("packet:36",   _applyGrowth)      -- GrowthUpdatePacket 0x0024 = 36

    -- Also hook native Net names
    Events.On("tileChanged", function(data)
        if data then _applyTileUpdate(data) end
    end)
end

return World
