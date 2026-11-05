--[[
╔══════════════════════════════════════════════════════════════════════════╗
║  NXroENinD_DPcKage.Network — Packet Send / Receive / Hook Layer                 ║
╚══════════════════════════════════════════════════════════════════════════╝
  Handles:
    • SendPkt(id, data)        — Send a typed packet
    • SendRaw(buffer)          — Send raw binary buffer
    • HookPkt(id, fn)          — Intercept incoming packet
    • UnhookPkt(id)            — Remove hook
--]]

local Network = {}

-- ──────────────────────────────────────────────
--  Services & Dependencies
-- ──────────────────────────────────────────────
local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets   = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packets"))
local ByteNet   = require(ReplicatedStorage:WaitForChild("ByteNet"))
local SmoothBuf = require(script.Parent.SmoothBuf)
local Events    = require(script.Parent.Events)
local Utils     = require(script.Parent.Utils)

-- ──────────────────────────────────────────────
--  Internal State
-- ──────────────────────────────────────────────
local _hooks   = {}       -- [packetId] = { fn, ... }
local _queue   = {}       -- Outgoing packet queue (SmoothBuf)
local _started = false

-- Packet ID → ByteNet packet object map
local _packetMap = {
    -- Client → Server
    [0x0001] = Packets.InputPacket,
    [0x0002] = Packets.MovementPacket,
    [0x0003] = Packets.ChatPacket,
    [0x0004] = Packets.PlaceBlockPacket,
    [0x0005] = Packets.BreakBlockPacket,
    [0x0006] = Packets.DropItemPacket,
    [0x0007] = Packets.CollectItemPacket,
    [0x0008] = Packets.WearItemPacket,
    [0x0009] = Packets.RemoveItemPacket,
    [0x000A] = Packets.TrashItemPacket,
    [0x000B] = Packets.UseItemPacket,
    [0x000C] = Packets.EnterDoorPacket,
    [0x000D] = Packets.WorldRequestPacket,
    [0x001A] = Packets.AdminCommandPacket,
    [0x001B] = Packets.NpcInteractPacket,
    [0x001C] = Packets.CraftPacket,
    [0x001D] = Packets.BuyPacket,
    [0x001E] = Packets.SellPacket,
    [0x001F] = Packets.SignEditPacket,
    [0x0020] = Packets.LockPacket,
    [0x0021] = Packets.FriendPacket,
    [0x0022] = Packets.EmotePacket,
    [0x0023] = Packets.RespawnPacket,
    [0x0018] = Packets.PingPacket,
    -- Server → Client (readable)
    [0x000E] = Packets.WorldDataPacket,
    [0x000F] = Packets.TileUpdatePacket,
    [0x0010] = Packets.InventoryUpdatePacket,
    [0x0011] = Packets.PlayerJoinPacket,
    [0x0012] = Packets.PlayerLeavePacket,
    [0x0013] = Packets.PlayerUpdatePacket,
    [0x0014] = Packets.ConsoleMessagePacket,
    [0x0015] = Packets.DialogPacket,
    [0x0016] = Packets.TradeRequestPacket,
    [0x0017] = Packets.TradeUpdatePacket,
    [0x0019] = Packets.SyncClockPacket,
    [0x0024] = Packets.GrowthUpdatePacket,
    [0x0025] = Packets.WeatherPacket,
    [0x0026] = Packets.EffectPacket,
    [0x0027] = Packets.SoundPacket,
}

-- Reverse: name → id
local _nameToId = {
    InputPacket          = 0x0001,
    MovementPacket       = 0x0002,
    ChatPacket           = 0x0003,
    PlaceBlockPacket     = 0x0004,
    BreakBlockPacket     = 0x0005,
    DropItemPacket       = 0x0006,
    CollectItemPacket    = 0x0007,
    WearItemPacket       = 0x0008,
    RemoveItemPacket     = 0x0009,
    TrashItemPacket      = 0x000A,
    UseItemPacket        = 0x000B,
    EnterDoorPacket      = 0x000C,
    WorldRequestPacket   = 0x000D,
    WorldDataPacket      = 0x000E,
    TileUpdatePacket     = 0x000F,
    InventoryUpdatePacket= 0x0010,
    PlayerJoinPacket     = 0x0011,
    PlayerLeavePacket    = 0x0012,
    PlayerUpdatePacket   = 0x0013,
    ConsoleMessagePacket = 0x0014,
    DialogPacket         = 0x0015,
    TradeRequestPacket   = 0x0016,
    TradeUpdatePacket    = 0x0017,
    PingPacket           = 0x0018,
    SyncClockPacket      = 0x0019,
    AdminCommandPacket   = 0x001A,
    NpcInteractPacket    = 0x001B,
    CraftPacket          = 0x001C,
    BuyPacket            = 0x001D,
    SellPacket           = 0x001E,
    SignEditPacket        = 0x001F,
    LockPacket           = 0x0020,
    FriendPacket         = 0x0021,
    EmotePacket          = 0x0022,
    RespawnPacket        = 0x0023,
    GrowthUpdatePacket   = 0x0024,
    WeatherPacket        = 0x0025,
    EffectPacket         = 0x0026,
    SoundPacket          = 0x0027,
}

-- ──────────────────────────────────────────────
--  Helpers
-- ──────────────────────────────────────────────

-- Resolve packet ID from name or number
local function _resolveId(packetRef)
    if type(packetRef) == "string" then
        local id = _nameToId[packetRef]
        assert(id, "[NXroENinD_DPcKage.Network] Unknown packet name: " .. packetRef)
        return id
    elseif type(packetRef) == "number" then
        return packetRef
    end
    error("[NXroENinD_DPcKage.Network] packetRef must be string name or number ID")
end

-- Dispatch hooks for a received packet
local function _dispatch(packetId, data)
    local list = _hooks[packetId]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, data, packetId)
        if not ok then
            warn("[NXroENinD_DPcKage.Network] Hook error on pkt 0x" 
                .. string.format("%04X", packetId) .. " : " .. tostring(err))
        end
    end
    Events.Emit("packet:" .. packetId, data)
end

-- ──────────────────────────────────────────────
--  Public API
-- ──────────────────────────────────────────────

--[[
    SendPkt(packetRef, data)
    
    Send a typed packet to the server.
    packetRef = packet name (string) or packet ID (number)
    data      = table matching the packet's struct definition
    
    Example:
        NX.SendPkt("ChatPacket", { message = "Hello!", channel = 0 })
        NX.SendPkt(0x0003, { message = "Hello!", channel = 0 })
]]
function Network.SendPkt(packetRef, data)
    local id  = _resolveId(packetRef)
    local pkt = _packetMap[id]
    assert(pkt, "[NXroENinD_DPcKage.Network] No packet object for ID 0x" 
        .. string.format("%04X", id))
    assert(type(data) == "table", "[NXroENinD_DPcKage.Network] data must be a table")

    if SmoothBuf.SmoothBuf then
        -- Queue into smooth buffer, flush on next frame
        SmoothBuf.Queue(id, pkt, data)
    else
        -- Direct send
        pkt.send(data)
    end
end

--[[
    SendRaw(buf)
    
    Send a raw binary buffer directly (bypasses typed system).
    buf = Roblox buffer object (created with buffer.create)
    
    Example:
        local buf = buffer.create(4)
        buffer.writeu16(buf, 0, 0x0003) -- ChatPacket ID
        buffer.writeu16(buf, 2, 5)      -- custom field
        NX.SendRaw(buf)
]]
function Network.SendRaw(buf)
    assert(typeof(buf) == "buffer", "[NXroENinD_DPcKage.Network] SendRaw expects a buffer")
    local reliable = ReplicatedStorage:WaitForChild("ByteNet_RELIABLE")
    if reliable then
        reliable:FireServer(buf)
    end
end

--[[
    HookPkt(packetRef, callback)
    
    Register a callback to intercept a packet when received.
    callback(data, packetId) is called whenever that packet arrives.
    Returns a hook handle (use with UnhookPkt).
    
    Example:
        local handle = NX.HookPkt("ConsoleMessagePacket", function(data)
            print("[Intercepted]", data.text)
        end)
]]
function Network.HookPkt(packetRef, callback)
    assert(type(callback) == "function", "[NXroENinD_DPcKage.Network] callback must be a function")
    local id = _resolveId(packetRef)
    if not _hooks[id] then _hooks[id] = {} end
    local handle = { id = id, fn = callback }
    table.insert(_hooks[id], callback)
    return handle
end

--[[
    UnhookPkt(handle)
    
    Remove a previously registered hook.
    handle = the value returned by HookPkt()
]]
function Network.UnhookPkt(handle)
    assert(type(handle) == "table" and handle.id and handle.fn,
        "[NXroENinD_DPcKage.Network] Invalid hook handle")
    local list = _hooks[handle.id]
    if not list then return end
    for i, fn in ipairs(list) do
        if fn == handle.fn then
            table.remove(list, i)
            break
        end
    end
end

-- ──────────────────────────────────────────────
--  Internal startup: bind incoming listeners
-- ──────────────────────────────────────────────
function Network.Start()
    if _started then return end
    _started = true

    -- Listen to all incoming packets and route to hooks
    for id, pkt in pairs(_packetMap) do
        if pkt.listen then
            pkt.listen(function(data)
                _dispatch(id, data)
            end)
        end
    end
end

return Network
