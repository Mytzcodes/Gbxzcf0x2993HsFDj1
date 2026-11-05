-- NXroENinD_DPcKage.MultiPacket
-- SendMulti / SendChain / SendIf / DefineMacro / RunMacro + composite presets.
-- Deps injected via Start().

local MultiPacket = {}

local Network   = nil   -- injected
local SmoothBuf = nil   -- injected
local Events    = nil   -- injected

local _macros = {}

local function _sendEntry(entry)
    if Network then Network.SendPkt(entry[1], entry[2]) end
end

local function _flush()
    if SmoothBuf then SmoothBuf.Flush() end
end

-- ── SendMulti ────────────────────────────────────────────────────────────────

--[[
    SendMulti(...)
    Send multiple packets in one call, flushed together on the same frame.
    Each argument: { "PacketName" | 0xID, payloadTable }

    NX.SendMulti(
        { "BuyPacket",        { shopId=1, itemId=50, count=1 } },
        { "PlaceBlockPacket", { x=10, y=20, itemId=50 } }
    )
]]
function MultiPacket.SendMulti(...)
    for _, entry in ipairs({...}) do _sendEntry(entry) end
    _flush()
end

-- ── SendChain ────────────────────────────────────────────────────────────────

--[[
    SendChain(steps) → { Cancel() }
    Send packets in sequence with per-step delays.
    Each step: { "PacketName" | 0xID, payload, delay? }

    local h = NX.SendChain({
        { "BuyPacket",        { shopId=1, itemId=50, count=1 }, 0.2 },
        { "PlaceBlockPacket", { x=10, y=20, itemId=50 },        0.1 },
        { "UseItemPacket",    { itemId=50, x=10, y=20 } },
    })
    h.Cancel()
]]
function MultiPacket.SendChain(steps)
    local handle = { cancelled = false }

    task.spawn(function()
        for i, step in ipairs(steps) do
            if handle.cancelled then return end
            _sendEntry(step)
            _flush()
            local delay = step[3] or 0
            if delay > 0 then task.wait(delay) end
            if Events then Events.Emit("multipacket:step", { index = i, total = #steps }) end
        end
        if not handle.cancelled then
            if Events then Events.Emit("multipacket:done", { steps = #steps }) end
        end
    end)

    return {
        Cancel = function()
            handle.cancelled = true
            if Events then Events.Emit("multipacket:cancel", {}) end
        end
    }
end

-- ── SendIf ───────────────────────────────────────────────────────────────────

--[[
    SendIf(condition, thenPkts, elsePkts?)
    Send thenPkts if condition is true, elsePkts otherwise.

    NX.SendIf(
        NX.HasItem("Dirt", 1),
        { { "PlaceBlockPacket", { x=5, y=5, itemId=2 } } },
        { { "ChatPacket", { message="No dirt!", channel=0 } } }
    )
]]
function MultiPacket.SendIf(condition, thenPkts, elsePkts)
    local list = condition and thenPkts or elsePkts
    if list then
        for _, entry in ipairs(list) do _sendEntry(entry) end
        _flush()
    end
end

-- ── DefineMacro / RunMacro ───────────────────────────────────────────────────

--[[
    DefineMacro(name, steps)
    Register a named packet chain macro (same step format as SendChain).

    NX.DefineMacro("BuyAndPlace", {
        { "BuyPacket",        { shopId=1, itemId=50, count=1 }, 0.2 },
        { "PlaceBlockPacket", { x=0, y=0, itemId=50 } },
    })
]]
function MultiPacket.DefineMacro(name, steps)
    assert(type(name) == "string", "DefineMacro: name must be string")
    _macros[name] = steps
end

--[[
    RunMacro(name, overrides?) → { Cancel() }
    Fire a registered macro. overrides: array of partial payloads per step index.

    NX.RunMacro("BuyAndPlace", {
        nil,                             -- step 1 unchanged
        { x=15, y=10, itemId=50 },       -- step 2 uses new coords
    })
]]
function MultiPacket.RunMacro(name, overrides)
    local steps = _macros[name]
    assert(steps, "RunMacro: no macro named '" .. tostring(name) .. "'")

    local resolved = {}
    for i, step in ipairs(steps) do
        local payload = {}
        for k, v in pairs(step[2]) do payload[k] = v end
        if overrides and overrides[i] then
            for k, v in pairs(overrides[i]) do payload[k] = v end
        end
        resolved[i] = { step[1], payload, step[3] }
    end

    return MultiPacket.SendChain(resolved)
end

--[[
    ListMacros() → array of string
]]
function MultiPacket.ListMacros()
    local names = {}
    for k in pairs(_macros) do names[#names+1] = k end
    return names
end

-- ── Composite Presets ────────────────────────────────────────────────────────

--[[
    BuyAndPlace(shopId, itemId, count, x, y)
    Buy an item then immediately place it at tile (x, y).

    NX.BuyAndPlace(1, 50, 1, 10, 20)
]]
function MultiPacket.BuyAndPlace(shopId, itemId, count, x, y)
    return MultiPacket.SendChain({
        { "BuyPacket",        { shopId=shopId, itemId=itemId, count=count }, 0.15 },
        { "PlaceBlockPacket", { x=x, y=y, itemId=itemId } },
    })
end

--[[
    BuySellArbitrage(buyShopId, sellShopId, itemId, count)
    Buy from one shop, sell to another.

    NX.BuySellArbitrage(1, 2, 50, 10)
]]
function MultiPacket.BuySellArbitrage(buyShopId, sellShopId, itemId, count)
    return MultiPacket.SendChain({
        { "BuyPacket",  { shopId=buyShopId,  itemId=itemId, count=count }, 0.3 },
        { "SellPacket", { shopId=sellShopId, itemId=itemId, count=count } },
    })
end

--[[
    EquipAndUse(itemId, x, y)
    Wear an item then use it at (x, y).

    NX.EquipAndUse(300, 5, 5)
]]
function MultiPacket.EquipAndUse(itemId, x, y)
    return MultiPacket.SendChain({
        { "WearItemPacket", { itemId=itemId },          0.1 },
        { "UseItemPacket",  { itemId=itemId, x=x, y=y } },
    })
end

--[[
    CraftAndWear(recipeId, itemId)
    Craft then immediately equip the result.

    NX.CraftAndWear(7, 999)
]]
function MultiPacket.CraftAndWear(recipeId, itemId)
    return MultiPacket.SendChain({
        { "CraftPacket",    { recipeId=recipeId }, 0.5 },
        { "WearItemPacket", { itemId=itemId } },
    })
end

--[[
    PlaceRow(itemId, startX, y, length, direction?)
    Place `length` blocks in a row. direction: 1=right (default), -1=left.

    NX.PlaceRow(2, 0, 10, 20)        -- 20 dirt blocks going right
    NX.PlaceRow(2, 20, 10, 20, -1)   -- going left
]]
function MultiPacket.PlaceRow(itemId, startX, y, length, direction)
    direction = direction or 1
    local steps = {}
    for i = 0, length - 1 do
        steps[#steps+1] = {
            "PlaceBlockPacket",
            { x = startX + i * direction, y = y, itemId = itemId },
            0.05
        }
    end
    return MultiPacket.SendChain(steps)
end

--[[
    BreakRect(x1, y1, x2, y2)
    Break all tiles in rectangle from (x1,y1) to (x2,y2).

    NX.BreakRect(0, 0, 9, 9)   -- 10x10 area
]]
function MultiPacket.BreakRect(x1, y1, x2, y2)
    local steps = {}
    for ty = y1, y2 do
        for tx = x1, x2 do
            steps[#steps+1] = { "BreakBlockPacket", { x=tx, y=ty }, 0.04 }
        end
    end
    return MultiPacket.SendChain(steps)
end

--[[
    FriendAndChat(targetUserId, message)
    Send friend request then follow up with chat.

    NX.FriendAndChat(123456, "Hey friend!")
]]
function MultiPacket.FriendAndChat(targetUserId, message)
    return MultiPacket.SendChain({
        { "FriendPacket", { targetUserId=targetUserId, action=0 }, 0.2 },
        { "ChatPacket",   { message=message, channel=0 } },
    })
end

--[[
    TradeAndConfirm(targetUserId, offerItems)
    Open trade with player then queue and confirm items.
    offerItems: array of { id: u16, count: u16 }

    NX.TradeAndConfirm(123456, { {id=50, count=5} })
]]
function MultiPacket.TradeAndConfirm(targetUserId, offerItems)
    return MultiPacket.SendChain({
        { "TradeRequestPacket", { targetUserId=targetUserId },              0.3 },
        { "TradeUpdatePacket",  { items=offerItems, confirmed=false },      0.5 },
        { "TradeUpdatePacket",  { items=offerItems, confirmed=true } },
    })
end

-- ── Startup ───────────────────────────────────────────────────────────────────

function MultiPacket.Start(networkModule, smoothBufModule, eventsModule)
    Network   = networkModule
    SmoothBuf = smoothBufModule
    Events    = eventsModule
end

return MultiPacket
