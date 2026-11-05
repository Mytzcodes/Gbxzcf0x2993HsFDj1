-- NXroENinD_DPcKage.Inventory
-- GetInvent / FindItem / CountItem / HasItem / GetEquipped / GetByType
-- Deps injected via Start().

local Inventory = {}

local Events = nil   -- injected

local _inventory = {}
local _started   = false
local _itemDB    = nil

local function _getDB()
    if _itemDB then return _itemDB end
    local ok, db = pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local shared = rs:FindFirstChild("Shared")
        if not shared then return {} end
        local idb = shared:FindFirstChild("ItemDatabase")
        if not idb then return {} end
        return require(idb)
    end)
    _itemDB = (ok and type(db) == "table") and db or {}
    return _itemDB
end

local function _makeInvItem(raw)
    local db   = _getDB()
    local info = db[raw.id] or {}
    return {
        id        = raw.id,
        count     = raw.count,
        flags     = raw.flags or 0,
        name      = info.name     or ("Item#" .. raw.id),
        type      = info.type     or "unknown",
        rarity    = info.rarity   or 0,
        stackable = info.stackable ~= false,
        maxStack  = info.maxStack  or 999,
        equipped  = (bit32.band(raw.flags or 0, 0x01) ~= 0),
    }
end

-- ── Public API ───────────────────────────────────────────────────────────────

--[[
    GetInvent() → array of InvItem
    Each InvItem: { id, count, name, type, rarity, equipped, flags }

    local inv = NX.GetInvent()
    for _, item in ipairs(inv) do
        print(item.name, "x"..item.count)
    end
]]
function Inventory.GetInvent()
    return table.clone(_inventory)
end

--[[
    FindItem(query) → InvItem | nil
    query: number (by ID) or string (by name, partial, case-insensitive)

    local dirt = NX.FindItem("Dirt")
    local sword = NX.FindItem(1234)
]]
function Inventory.FindItem(query)
    if type(query) == "number" then
        for _, item in ipairs(_inventory) do
            if item.id == query then return item end
        end
    elseif type(query) == "string" then
        local q = query:lower()
        for _, item in ipairs(_inventory) do
            if item.name:lower():find(q, 1, true) then return item end
        end
    end
    return nil
end

--[[
    FindAllItems(query) → array of InvItem
    Same as FindItem but returns ALL matches.

    local seeds = NX.FindAllItems("Seed")
]]
function Inventory.FindAllItems(query)
    local result = {}
    if type(query) == "number" then
        for _, item in ipairs(_inventory) do
            if item.id == query then result[#result+1] = item end
        end
    elseif type(query) == "string" then
        local q = query:lower()
        for _, item in ipairs(_inventory) do
            if item.name:lower():find(q, 1, true) then result[#result+1] = item end
        end
    end
    return result
end

--[[
    CountItem(query) → number
    Total count of item across all stacks.

    print(NX.CountItem("Wood"))
]]
function Inventory.CountItem(query)
    local total = 0
    for _, item in ipairs(Inventory.FindAllItems(query)) do total += item.count end
    return total
end

--[[
    HasItem(query, minCount?) → bool
    Returns true if inventory has >= minCount (default 1).

    if NX.HasItem("Seed", 10) then ... end
]]
function Inventory.HasItem(query, minCount)
    return Inventory.CountItem(query) >= (minCount or 1)
end

--[[
    GetEquipped() → array of InvItem
    Items currently worn/equipped.

    for _, w in ipairs(NX.GetEquipped()) do print(w.name) end
]]
function Inventory.GetEquipped()
    local result = {}
    for _, item in ipairs(_inventory) do
        if item.equipped then result[#result+1] = item end
    end
    return result
end

--[[
    GetByType(typeName) → array of InvItem
    Types: "block", "seed", "clothing", "tool", "consumable"

    local blocks = NX.GetByType("block")
]]
function Inventory.GetByType(typeName)
    local result = {}
    local t = typeName:lower()
    for _, item in ipairs(_inventory) do
        if item.type:lower() == t then result[#result+1] = item end
    end
    return result
end

-- ── Startup ───────────────────────────────────────────────────────────────────

function Inventory.Start(eventsModule)
    if _started then return end
    _started = true
    Events = eventsModule

    -- InventoryUpdatePacket (0x0010): full inventory sync from server
    Events.On("packet:" .. 0x0010, function(data)
        _inventory = {}
        local items = data.items or data
        if type(items) == "table" then
            for _, raw in ipairs(items) do
                _inventory[#_inventory+1] = _makeInvItem(raw)
            end
        end
        Events.Emit("inventory:update", _inventory)
    end)
end

return Inventory
