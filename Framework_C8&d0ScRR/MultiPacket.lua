-- NXroENinD_DPcKage.MultiPacket
-- Composite and multi-type packet sending.
--
-- Solves:
--   - Sending multiple packet types in one atomic action (Buy + Place, Wear + Use, etc.)
--   - Chained sequences with per-step delays
--   - Conditional packet flows (send B only if A succeeded)
--   - Packet macros: define once, fire many times

local MultiPacket = {}

local Network   = require(script.Parent.Network)
local SmoothBuf = require(script.Parent.SmoothBuf)
local Events    = require(script.Parent.Events)

-- ── Internal ───────────────────────────────────────────────────────────────
local _macros = {}   -- named macro registry

-- Send one entry: { "PacketName", payload } or { 0xID, payload }
local function _sendEntry(entry)
    Network.SendPkt(entry[1], entry[2])
end

-- ── SendMulti ──────────────────────────────────────────────────────────────
--[[
    SendMulti(...)

    Send multiple packets in a single call. All queued into SmoothBuf
    and flushed together on the same frame — minimises round-trip overhead.

    Each argument: { "PacketName" | 0xID, payloadTable }

    Example — Buy then immediately Place the item:
        NX.SendMulti(
            { "BuyPacket",        { shopId = 1, itemId = 50, count = 1 } },
            { "PlaceBlockPacket", { x = 10, y = 20, itemId = 50 } }
        )

    Example — Equip + Emote:
        NX.SendMulti(
            { "WearItemPacket", { itemId = 300 } },
            { "EmotePacket",    { emoteId = 2 } }
        )
]]
function MultiPacket.SendMulti(...)
    local entries = { ... }
    for _, entry in ipairs(entries) do
        _sendEntry(entry)
    end
    -- Force immediate flush so all arrive same frame
    SmoothBuf.Flush()
end

-- ── SendChain ──────────────────────────────────────────────────────────────
--[[
    SendChain(steps)

    Send packets in sequence with per-step delays.
    Each step: { "PacketName" | 0xID, payload, delay? }
    delay (optional) = seconds to wait AFTER this step before next.

    Returns a cancel handle { Cancel() }.

    Example — Buy, wait 0.2s, Place, wait 0.1s, Use:
        local h = NX.SendChain({
            { "BuyPacket",        { shopId=1, itemId=50, count=1 }, 0.2 },
            { "PlaceBlockPacket", { x=10, y=20, itemId=50 },        0.1 },
            { "UseItemPacket",    { itemId=50, x=10, y=20 } },
        })
        -- cancel mid-chain:
        h.Cancel()

    Example — Craft then immediately equip result:
        NX.SendChain({
            { "CraftPacket",   { recipeId = 7 },      0.3 },
            { "WearItemPacket",{ itemId   = 999 } },
        })
]]
function MultiPacket.SendChain(steps)
    local handle = { cancelled = false }

    task.spawn(function()
        for i, step in ipairs(steps) do
            if handle.cancelled then return end
            _sendEntry(step)
            SmoothBuf.Flush()
            local delay = step[3] or 0
            if delay > 0 then
                task.wait(delay)
            end
            Events.Emit("multipacket:step", { index = i, total = #steps })
        end
        if not handle.cancelled then
            Events.Emit("multipacket:done", { steps = #steps })
        end
    end)

    return {
        Cancel = function()
            handle.cancelled = true
            Events.Emit("multipacket:cancel", {})
        end
    }
end

-- ── SendIf ─────────────────────────────────────────────────────────────────
--[[
    SendIf(condition, thenPkts, elsePkts?)

    Send one set of packets if condition is true, another if false.
    thenPkts / elsePkts: array of { "PacketName", payload }

    Example — place only if have item:
        local inv = NX.GetInvent()
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
        SmoothBuf.Flush()
    end
end

-- ── DefineMacro / RunMacro ─────────────────────────────────────────────────
--[[
    DefineMacro(name, steps)

    Register a named packet chain macro. Steps same format as SendChain.

    Example:
        NX.DefineMacro("BuyAndPlace", {
            { "BuyPacket",        { shopId=1, itemId=50, count=1 }, 0.2 },
            { "PlaceBlockPacket", { x=0, y=0, itemId=50 } },
        })

    RunMacro(name, overrides?)

    Fire a registered macro. overrides replaces payload fields per-step.
    overrides: array of partial payload tables (index = step number).

    Example:
        NX.RunMacro("BuyAndPlace", {
            nil,                              -- step 1 unchanged
            { x = 15, y = 10, itemId = 50 }, -- step 2 uses new coords
        })
]]
function MultiPacket.DefineMacro(name, steps)
    assert(type(name) == "string", "DefineMacro: name must be string")
    _macros[name] = steps
end

function MultiPacket.RunMacro(name, overrides)
    local steps = _macros[name]
    assert(steps, "RunMacro: no macro named '" .. tostring(name) .. "'")

    local resolved = {}
    for i, step in ipairs(steps) do
        local payload = {}
        for k, v in pairs(step[2]) do payload[k] = v end   -- shallow copy
        if overrides and overrides[i] then
            for k, v in pairs(overrides[i]) do payload[k] = v end
        end
        resolved[i] = { step[1], payload, step[3] }
    end

    return MultiPacket.SendChain(resolved)
end

--[[
    ListMacros()
    Returns table of registered macro names.
]]
function MultiPacket.ListMacros()
    local names = {}
    for k in pairs(_macros) do names[#names+1] = k end
    return names
end

-- ── Composite Presets ──────────────────────────────────────────────────────
-- Ready-made complex actions. Use directly or as reference.

--[[
    BuyAndPlace(shopId, itemId, count, x, y)
    Buy an item from a shop then immediately place it at (x, y).
]]
function MultiPacket.BuyAndPlace(shopId, itemId, count, x, y)
    return MultiPacket.SendChain({
        { "BuyPacket",        { shopId=shopId, itemId=itemId, count=count }, 0.15 },
        { "PlaceBlockPacket", { x=x, y=y, itemId=itemId } },
    })
end

--[[
    BuySellArbitrage(buyShopId, sellShopId, itemId, count)
    Buy from one shop, sell to another. Useful for gem/item flipping.
]]
function MultiPacket.BuySellArbitrage(buyShopId, sellShopId, itemId, count)
    return MultiPacket.SendChain({
        { "BuyPacket",  { shopId=buyShopId,  itemId=itemId, count=count }, 0.3 },
        { "SellPacket", { shopId=sellShopId, itemId=itemId, count=count } },
    })
end

--[[
    EquipAndUse(itemId, x, y)
    Wear an item then use it at (x, y) in one action.
]]
function MultiPacket.EquipAndUse(itemId, x, y)
    return MultiPacket.SendChain({
        { "WearItemPacket", { itemId=itemId },         0.1 },
        { "UseItemPacket",  { itemId=itemId, x=x, y=y } },
    })
end

--[[
    CraftAndWear(recipeId, itemId)
    Craft an item then immediately equip the result.
]]
function MultiPacket.CraftAndWear(recipeId, itemId)
    return MultiPacket.SendChain({
        { "CraftPacket",    { recipeId=recipeId }, 0.5 },
        { "WearItemPacket", { itemId=itemId } },
    })
end

--[[
    PlaceRow(itemId, startX, y, length, direction?)
    Place `length` blocks in a row starting at (startX, y).
    direction: 1 = right (default), -1 = left
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
    Break all tiles inside a rectangle (x1,y1) to (x2,y2).
]]
function MultiPacket.BreakRect(x1, y1, x2, y2)
    local steps = {}
    for ty = y1, y2 do
        for tx = x1, x2 do
            steps[#steps+1] = {
                "BreakBlockPacket",
                { x = tx, y = ty },
                0.04
            }
        end
    end
    return MultiPacket.SendChain(steps)
end

--[[
    FriendAndChat(targetUserId, message)
    Send a friend request then follow up with a chat message.
]]
function MultiPacket.FriendAndChat(targetUserId, message)
    return MultiPacket.SendChain({
        { "FriendPacket", { targetUserId=targetUserId, action=0 }, 0.2 },
        { "ChatPacket",   { message=message, channel=0 } },
    })
end

--[[
    TradeAndConfirm(targetUserId, offerItems)
    Initiate trade with a player and immediately queue your offer items.
    offerItems: array of { id: u16, count: u16 }
]]
function MultiPacket.TradeAndConfirm(targetUserId, offerItems)
    return MultiPacket.SendChain({
        { "TradeRequestPacket", { targetUserId=targetUserId },              0.3 },
        { "TradeUpdatePacket",  { items=offerItems, confirmed=false },      0.5 },
        { "TradeUpdatePacket",  { items=offerItems, confirmed=true } },
    })
end

return MultiPacket
