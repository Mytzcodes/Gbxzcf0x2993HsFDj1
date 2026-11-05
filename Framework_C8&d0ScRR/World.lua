--[[
╔══════════════════════════════════════════════════════════════════════════╗
║  NXroENinD_DPcKage.World — World / Tile Query API                               ║
╚══════════════════════════════════════════════════════════════════════════╝
  Provides:
    GetWorld()           → Current WorldData table
    GetTile(x, y)        → TileObject at coordinate
    FindTiles(query)     → Find all tiles matching criteria
    TileAt(pos)          → Get tile at Vector3 world position
--]]

local World = {}

local Events = require(script.Parent.Events)

-- ──────────────────────────────────────────────
--  State
-- ──────────────────────────────────────────────
local _world = nil        -- Current WorldData
local _tiles = {}         -- [y][x] = TileObject

-- ──────────────────────────────────────────────
--  TileObject
-- ──────────────────────────────────────────────
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

        -- Flag helpers
        isSolid    = function(self) return bit32.band(self.flags, 0x001) ~= 0 end,
        isLocked   = function(self) return bit32.band(self.flags, 0x010) ~= 0 end,
        isDoor     = function(self) return bit32.band(self.flags, 0x040000) ~= 0 end,
        isTree     = function(self) return bit32.band(self.flags, 0x4000) ~= 0 end,
        hasSign    = function(self) return bit32.band(self.flags, 0x2000) ~= 0 end,
        isPublic   = function(self) return bit32.band(self.flags, 0x400) ~= 0 end,
        isEmpty    = function(self) return self.foreground == 0 and self.background == 0 end,
    }
end

-- ──────────────────────────────────────────────
--  API
-- ──────────────────────────────────────────────

--[[
    GetWorld()
    
    Returns the current world data table or nil if not in world.
    
    Fields:
      name, width, height, ownerId, weatherType, weatherIntensity
    
    Example:
        local w = NX.GetWorld()
        if w then print("World:", w.name, w.width .. "x" .. w.height) end
]]
function World.GetWorld()
    return _world
end

--[[
    GetTile(x, y)
    
    Get a TileObject at grid coordinates (0-indexed).
    Returns nil if out of bounds.
    
    Example:
        local tile = NX.GetTile(10, 20)
        if tile then
            print("Foreground ID:", tile.foreground)
            print("Is locked:", tile:isLocked())
        end
]]
function World.GetTile(x, y)
    local row = _tiles[y]
    return row and row[x] or nil
end

--[[
    FindTiles(predicate)
    
    Find all tiles matching a predicate function.
    predicate(TileObject) → bool
    
    Returns array of TileObject.
    
    Example:
        -- Find all locked tiles
        local locked = NX.FindTiles(function(t) return t:isLocked() end)
        
        -- Find all trees
        local trees = NX.FindTiles(function(t) return t:isTree() end)
        
        -- Find tiles with specific foreground ID
        local dirt = NX.FindTiles(function(t) return t.foreground == 2 end)
]]
function World.FindTiles(predicate)
    local result = {}
    for _, row in pairs(_tiles) do
        for _, tile in pairs(row) do
            if predicate(tile) then
                table.insert(result, tile)
            end
        end
    end
    return result
end

--[[
    TileAt(worldPos)
    
    Convert a Roblox Vector3 world position to tile coordinates
    and return the TileObject.
    
    Example:
        local hrp = NX.Player()["local"]:GetHRP()
        if hrp then
            local tile = NX.TileAt(hrp.Position)
            print("Standing on tile:", tile and tile.foreground or "air")
        end
]]
function World.TileAt(worldPos)
    if not _world then return nil end
    -- Assuming each tile = 2 studs wide, bottom-left origin at (0,0,0)
    local tileSize = 2
    local tx = math.floor(worldPos.X / tileSize)
    local ty = math.floor(worldPos.Y / tileSize)
    return World.GetTile(tx, ty)
end

-- ──────────────────────────────────────────────
--  Internal: parse WorldDataPacket buffer
-- ──────────────────────────────────────────────
local function _parseWorldData(data)
    -- data.worldData is a raw buffer
    -- This is a stub — real parsing depends on world format
    -- For now, store placeholder and emit event
    _world = {
        name             = "UNKNOWN",
        width            = 100,
        height           = 60,
        ownerId          = 0,
        weatherType      = 0,
        weatherIntensity = 0,
    }
    _tiles = {}
    Events.Emit("world:loaded", _world)
end

local function _applyTileUpdate(data)
    -- data = { x, y, fg, bg, flags }
    if not _tiles[data.y] then _tiles[data.y] = {} end
    local existing = _tiles[data.y][data.x]
    if existing then
        existing.foreground = data.fg
        existing.background = data.bg
        existing.flags      = data.flags
    else
        _tiles[data.y][data.x] = _makeTile({
            fg    = data.fg,
            bg    = data.bg,
            flags = data.flags,
        }, data.x, data.y)
    end
    Events.Emit("tile:update", _tiles[data.y][data.x])
end

local function _applyGrowth(data)
    local row = _tiles[data.y]
    local tile = row and row[data.x]
    if tile then
        tile.growth = data.stage
        Events.Emit("tile:growth", tile)
    end
end

-- ──────────────────────────────────────────────
--  Startup
-- ──────────────────────────────────────────────
function World.Start()
    Events.On("packet:" .. 0x000E, _parseWorldData)
    Events.On("packet:" .. 0x000F, _applyTileUpdate)
    Events.On("packet:" .. 0x0024, _applyGrowth)
end

return World
