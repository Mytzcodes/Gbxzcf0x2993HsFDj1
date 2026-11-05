--[[
╔══════════════════════════════════════════════════════════════════════════╗
║  NXroENinD_DPcKage.Inventory — GetInvent / FindItem / CountItem                 ║
╚══════════════════════════════════════════════════════════════════════════╝
  Provides:
    GetInvent()           → Full inventory table (array of InvItem)
    FindItem(id/name)     → Find first item by ID or name
    CountItem(id/name)    → Count total of item in inventory
    HasItem(id/name, n?)  → Check if inventory has n of item
--]]

local Inventory = {}

local Events  = require(script.Parent.Events)

-- ──────────────────────────────────────────────
--  Internal State
-- ──────────────────────────────────────────────
local _inventory = {}     -- Current inventory: array of InvItem
local _started   = false

-- ──────────────────────────────────────────────
--  InvItem Class
-- ──────────────────────────────────────────────
-- Each item in inventory is an InvItem table:
-- {
--   id      : number  (item ID, uint16)
--   count   : number  (stack count)
--   flags   : number  (equipped, locked, etc.)
--   name    : string  (from ItemDatabase lookup)
--   type    : string  (block, seed, clothing, tool, consumable)
--   rarity  : number  (0-7)
--   equipped: bool
-- }

-- Lazy-load item database
local _itemDB = nil
local function _getDB()
    if not _itemDB then
        local ok, db = pcall(function()
            return require(game.ReplicatedStorage:WaitForChild("Shared")
                :WaitForChild("ItemDatabase"))
        end)
        _itemDB = ok and db or {}
    end
    return _itemDB
end

local function _makeInvItem(raw)
    local db   = _getDB()
    local info = db[raw.id] or {}
    return {
        id       = raw.id,
        count    = raw.count,
        flags    = raw.flags or 0,
        name     = info.name     or ("Item#" .. raw.id),
        type     = info.type     or "unknown",
        rarity   = info.rarity   or 0,
        stackable= info.stackable ~= false,
        maxStack = info.maxStack  or 999,
        equipped = (bit32.band(raw.flags or 0, 0x01) ~= 0),
    }
end

-- ──────────────────────────────────────────────
--  Public API
-- ──────────────────────────────────────────────

--[[
    GetInvent()
    
    Returns the full inventory as an array of InvItem tables.
    Each InvItem contains: id, count, name, type, rarity, equipped, etc.
    
    Example:
        local inv = NX.GetInvent()
        for _, item in ipairs(inv) do
            print(item.name, "x" .. item.count)
        end
    
    Result: #table (array) of InvItem
--]]
function Inventory.GetInvent()
    return table.clone(_inventory)
end

--[[
    FindItem(query)
    
    Find the first InvItem matching:
      • query as number → match by item ID
      • query as string → match by item name (case-insensitive, partial)
    
    Returns InvItem or nil.
    
    Example:
        local dirt = NX.FindItem("Dirt")
        local sword = NX.FindItem(1234)
        if dirt then
            print("Found:", dirt.name, "x" .. dirt.count)
        end
]]
function Inventory.FindItem(query)
    if type(query) == "number" then
        for _, item in ipairs(_inventory) do
            if item.id == query then return item end
        end
    elseif type(query) == "string" then
        local q = query:lower()
        for _, item in ipairs(_inventory) do
            if item.name:lower():find(q, 1, true) then
                return item
            end
        end
    end
    return nil
end

--[[
    FindAllItems(query)
    
    Returns ALL matching InvItems (instead of just the first).
    Useful when the same item might appear in multiple slots.
    
    Example:
        local seeds = NX.FindAllItems("Seed")
        for _, s in ipairs(seeds) do print(s.name, s.count) end
]]
function Inventory.FindAllItems(query)
    local result = {}
    if type(query) == "number" then
        for _, item in ipairs(_inventory) do
            if item.id == query then table.insert(result, item) end
        end
    elseif type(query) == "string" then
        local q = query:lower()
        for _, item in ipairs(_inventory) do
            if item.name:lower():find(q, 1, true) then
                table.insert(result, item)
            end
        end
    end
    return result
end

--[[
    CountItem(query)
    
    Count total stack count of matching items.
    
    Example:
        local total = NX.CountItem("Wood")
        print("Wood count:", total)
]]
function Inventory.CountItem(query)
    local total = 0
    for _, item in ipairs(Inventory.FindAllItems(query)) do
        total += item.count
    end
    return total
end

--[[
    HasItem(query, minCount?)
    
    Returns true if inventory has at least minCount (default 1) of item.
    
    Example:
        if NX.HasItem("Seed", 10) then
            NX.ConsoleMsg("Have 10+ seeds!")
        end
]]
function Inventory.HasItem(query, minCount)
    minCount = minCount or 1
    return Inventory.CountItem(query) >= minCount
end

--[[
    GetEquipped()
    
    Returns array of InvItems that are currently equipped/worn.
    
    Example:
        local worn = NX.GetEquipped()
        for _, w in ipairs(worn) do print("Wearing:", w.name) end
]]
function Inventory.GetEquipped()
    local result = {}
    for _, item in ipairs(_inventory) do
        if item.equipped then table.insert(result, item) end
    end
    return result
end

--[[
    GetByType(typeName)
    
    Filter inventory by item type.
    Types: "block", "seed", "clothing", "tool", "consumable"
    
    Example:
        local blocks = NX.GetByType("block")
]]
function Inventory.GetByType(typeName)
    local result = {}
    local t = typeName:lower()
    for _, item in ipairs(_inventory) do
        if item.type:lower() == t then
            table.insert(result, item)
        end
    end
    return result
end

-- ──────────────────────────────────────────────
--  Startup: sync from InventoryUpdatePacket
-- ──────────────────────────────────────────────
function Inventory.Start()
    if _started then return end
    _started = true

    -- Listen for inventory sync from server (pkt 0x0010)
    Events.On("packet:" .. 0x0010, function(data)
        -- data.items = array of { id: uint16, count: uint16 }
        _inventory = {}
        for _, raw in ipairs(data.items) do
            table.insert(_inventory, _makeInvItem(raw))
        end
        Events.Emit("inventory:update", _inventory)
    end)
end

return Inventory
