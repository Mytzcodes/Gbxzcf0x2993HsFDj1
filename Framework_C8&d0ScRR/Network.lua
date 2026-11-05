-- NXroENinD_DPcKage.Network
-- SendPkt / SendRaw / HookPkt / UnhookPkt
-- All game-side requires (ByteNet, Packets) resolved lazily inside Start().

local Network = {}

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Lazy deps (injected or resolved in Start)
local SmoothBuf  = nil
local Events     = nil
local _Packets   = nil   -- ReplicatedStorage.Shared.Packets (may be nil outside game)
local _ByteNet   = nil   -- ReplicatedStorage.ByteNet (may be nil outside game)

local _hooks   = {}
local _started = false

-- ── Packet name ↔ ID maps ───────────────────────────────────────────────────
local _nameToId = {
    InputPacket           = 0x0001,
    MovementPacket        = 0x0002,
    ChatPacket            = 0x0003,
    PlaceBlockPacket      = 0x0004,
    BreakBlockPacket      = 0x0005,
    DropItemPacket        = 0x0006,
    CollectItemPacket     = 0x0007,
    WearItemPacket        = 0x0008,
    RemoveItemPacket      = 0x0009,
    TrashItemPacket       = 0x000A,
    UseItemPacket         = 0x000B,
    EnterDoorPacket       = 0x000C,
    WorldRequestPacket    = 0x000D,
    WorldDataPacket       = 0x000E,
    TileUpdatePacket      = 0x000F,
    InventoryUpdatePacket = 0x0010,
    PlayerJoinPacket      = 0x0011,
    PlayerLeavePacket     = 0x0012,
    PlayerUpdatePacket    = 0x0013,
    ConsoleMessagePacket  = 0x0014,
    DialogPacket          = 0x0015,
    TradeRequestPacket    = 0x0016,
    TradeUpdatePacket     = 0x0017,
    PingPacket            = 0x0018,
    SyncClockPacket       = 0x0019,
    AdminCommandPacket    = 0x001A,
    NpcInteractPacket     = 0x001B,
    CraftPacket           = 0x001C,
    BuyPacket             = 0x001D,
    SellPacket            = 0x001E,
    SignEditPacket        = 0x001F,
    LockPacket            = 0x0020,
    FriendPacket          = 0x0021,
    EmotePacket           = 0x0022,
    RespawnPacket         = 0x0023,
    GrowthUpdatePacket    = 0x0024,
    WeatherPacket         = 0x0025,
    EffectPacket          = 0x0026,
    SoundPacket           = 0x0027,
}

-- Built lazily once _Packets is available
local _packetMap = nil

local function _buildPacketMap()
    if not _Packets then return end
    _packetMap = {
        [0x0001] = _Packets.InputPacket,
        [0x0002] = _Packets.MovementPacket,
        [0x0003] = _Packets.ChatPacket,
        [0x0004] = _Packets.PlaceBlockPacket,
        [0x0005] = _Packets.BreakBlockPacket,
        [0x0006] = _Packets.DropItemPacket,
        [0x0007] = _Packets.CollectItemPacket,
        [0x0008] = _Packets.WearItemPacket,
        [0x0009] = _Packets.RemoveItemPacket,
        [0x000A] = _Packets.TrashItemPacket,
        [0x000B] = _Packets.UseItemPacket,
        [0x000C] = _Packets.EnterDoorPacket,
        [0x000D] = _Packets.WorldRequestPacket,
        [0x000E] = _Packets.WorldDataPacket,
        [0x000F] = _Packets.TileUpdatePacket,
        [0x0010] = _Packets.InventoryUpdatePacket,
        [0x0011] = _Packets.PlayerJoinPacket,
        [0x0012] = _Packets.PlayerLeavePacket,
        [0x0013] = _Packets.PlayerUpdatePacket,
        [0x0014] = _Packets.ConsoleMessagePacket,
        [0x0015] = _Packets.DialogPacket,
        [0x0016] = _Packets.TradeRequestPacket,
        [0x0017] = _Packets.TradeUpdatePacket,
        [0x0018] = _Packets.PingPacket,
        [0x0019] = _Packets.SyncClockPacket,
        [0x001A] = _Packets.AdminCommandPacket,
        [0x001B] = _Packets.NpcInteractPacket,
        [0x001C] = _Packets.CraftPacket,
        [0x001D] = _Packets.BuyPacket,
        [0x001E] = _Packets.SellPacket,
        [0x001F] = _Packets.SignEditPacket,
        [0x0020] = _Packets.LockPacket,
        [0x0021] = _Packets.FriendPacket,
        [0x0022] = _Packets.EmotePacket,
        [0x0023] = _Packets.RespawnPacket,
        [0x0024] = _Packets.GrowthUpdatePacket,
        [0x0025] = _Packets.WeatherPacket,
        [0x0026] = _Packets.EffectPacket,
        [0x0027] = _Packets.SoundPacket,
    }
end

-- ── Helpers ─────────────────────────────────────────────────────────────────

local function _resolveId(ref)
    if type(ref) == "string" then
        local id = _nameToId[ref]
        assert(id, "[NX.Network] Unknown packet name: " .. ref)
        return id
    elseif type(ref) == "number" then
        return ref
    end
    error("[NX.Network] packetRef must be string name or number ID")
end

local function _dispatch(packetId, data)
    local list = _hooks[packetId]
    if list then
        for _, fn in ipairs(list) do
            local ok, err = pcall(fn, data, packetId)
            if not ok then
                warn("[NX.Network] Hook error pkt 0x" .. string.format("%04X", packetId) .. ": " .. tostring(err))
            end
        end
    end
    if Events then Events.Emit("packet:" .. packetId, data) end
end

-- ── Public API ───────────────────────────────────────────────────────────────

--[[
    SendPkt(packetRef, data)
    packetRef = packet name string or numeric ID.
    data      = table matching the packet struct.

    NX.SendPkt("ChatPacket", { message = "hi", channel = 0 })
    NX.SendPkt(0x0003, { message = "hi", channel = 0 })
]]
function Network.SendPkt(packetRef, data)
    local id = _resolveId(packetRef)
    if not _packetMap then _buildPacketMap() end
    local pkt = _packetMap and _packetMap[id]
    if not pkt then
        warn("[NX.Network] No packet object for ID 0x" .. string.format("%04X", id) .. " — did Packets module load?")
        return
    end
    assert(type(data) == "table", "[NX.Network] data must be a table")
    if SmoothBuf and SmoothBuf.SmoothBuf then
        SmoothBuf.Queue(id, pkt, data)
    else
        pkt.send(data)
    end
end

--[[
    SendRaw(buf)
    buf = Roblox buffer object.

    local buf = buffer.create(4)
    buffer.writeu16(buf, 0, 0x0003)
    NX.SendRaw(buf)
]]
function Network.SendRaw(buf)
    local reliable = ReplicatedStorage:FindFirstChild("ByteNet_RELIABLE")
    if reliable then
        reliable:FireServer(buf)
    else
        warn("[NX.Network] ByteNet_RELIABLE not found in ReplicatedStorage")
    end
end

--[[
    HookPkt(packetRef, callback)
    Returns a handle. callback(data, packetId) fires on receive.

    local h = NX.HookPkt("ConsoleMessagePacket", function(data)
        print(data.text)
    end)
]]
function Network.HookPkt(packetRef, callback)
    assert(type(callback) == "function", "[NX.Network] callback must be a function")
    local id = _resolveId(packetRef)
    if not _hooks[id] then _hooks[id] = {} end
    local handle = { id = id, fn = callback }
    table.insert(_hooks[id], callback)
    return handle
end

--[[
    UnhookPkt(handle)
    Remove a hook returned by HookPkt().
]]
function Network.UnhookPkt(handle)
    if type(handle) ~= "table" or not handle.id then return end
    local list = _hooks[handle.id]
    if not list then return end
    for i, fn in ipairs(list) do
        if fn == handle.fn then table.remove(list, i); break end
    end
end

-- Name → ID helper (exposed so other modules can use)
function Network.ResolveId(ref) return _resolveId(ref) end

-- ── Start ───────────────────────────────────────────────────────────────────
function Network.Start(smoothBufModule, eventsModule)
    if _started then return end
    _started = true
    SmoothBuf = smoothBufModule
    Events    = eventsModule

    -- Resolve Packets and ByteNet from game (runs inside game context)
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    if shared then
        local pkts = shared:FindFirstChild("Packets")
        if pkts then
            local ok, result = pcall(require, pkts)
            if ok then _Packets = result end
        end
    end
    local byteNetObj = ReplicatedStorage:FindFirstChild("ByteNet")
    if byteNetObj then
        local ok, result = pcall(require, byteNetObj)
        if ok then _ByteNet = result end
    end

    _buildPacketMap()

    -- Bind incoming listeners
    if _packetMap then
        for id, pkt in pairs(_packetMap) do
            if pkt and type(pkt.listen) == "function" then
                pkt.listen(function(data)
                    _dispatch(id, data)
                end)
            end
        end
    end
end

return Network
