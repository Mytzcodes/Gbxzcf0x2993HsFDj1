-- NXroENinD_DPcKage.Inventory
-- GetInvent / FindItem / CountItem / HasItem / GetEquipped / GetByType
-- Fully guarded — won't crash if Events is nil.

local Inventory = {}

local Events  = nil
local _inventory = {}
local _started   = false
local _itemDB    = nil

local function _getDB()
    if _itemDB then return _itemDB end
    local ok, db = pcall(function()
        local rs     = game:GetService("ReplicatedStorage")
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
    if not raw or not raw.id then return nil end
    local db   = _getDB()
    local info = db[raw.id] or {}
    return {
        id        = raw.id,
        count     = raw.count  or 0,
        flags     = raw.flags  or 0,
        name      = info.name     or ("Item#" .. raw.id),
        type      = info.type     or "unknown",
        rarity    = info.rarity   or 0,
        stackable = info.stackable ~= false,
        maxStack  = info.maxStack  or 999,
        equipped  = (bit32.band(raw.flags or 0, 0x01) ~= 0),
    }
end

-- ── Public API ───────────────────────────────────────────────────────────────

function Inventory.GetInvent()
    return table.clone(_inventory)
end

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

function Inventory.CountItem(query)
    local total = 0
    for _, item in ipairs(Inventory.FindAllItems(query)) do total += item.count end
    return total
end

function Inventory.HasItem(query, minCount)
    return Inventory.CountItem(query) >= (minCount or 1)
end

function Inventory.GetEquipped()
    local result = {}
    for _, item in ipairs(_inventory) do
        if item.equipped then result[#result+1] = item end
    end
    return result
end

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

    -- Guard: eventsModule may be nil if called by old loader
    if type(eventsModule) ~= "table" or type(eventsModule.On) ~= "function" then
        warn("[NX.Inventory] Start() called without valid Events module — packet sync disabled.")
        return
    end
    Events = eventsModule

    -- InventoryUpdatePacket (0x0010)
    Events.On("packet:" .. 0x0010, function(data)
        if not data then return end
        _inventory = {}
        local items = data.items or data
        if type(items) == "table" then
            for _, raw in ipairs(items) do
                local item = _makeInvItem(raw)
                if item then _inventory[#_inventory+1] = item end
            end
        end
        Events.Emit("inventory:update", _inventory)
    end)
end

return Inventory
