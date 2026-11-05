-- NXroENinD_DPcKage.Network
-- SendPkt / SendRaw / HookPkt / UnhookPkt
-- Uses ByteNetReliable / ByteNetUnreliable (confirmed from client.lua decompile).

local Network = {}

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SmoothBuf = nil
local Events    = nil
local _Packets  = nil   -- ReplicatedStorage.Shared.Packets (may not exist)
local _hooks    = {}
local _started  = false

-- Remote references (resolved once in Start)
local _reliableRemote   = nil
local _unreliableRemote = nil

-- Warn throttle: suppress repeat warnings for same packet ID
local _warnedMissing = {}

-- ── Packet name ↔ ID ──────────────────────────────────────────────────────────

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

-- Unreliable packet IDs (sent via ByteNetUnreliable)
local _unreliableIds = {
    [0x0002] = true,  -- MovementPacket
    [0x0013] = true,  -- PlayerUpdatePacket
    [0x0018] = true,  -- PingPacket
}

local _packetMap = nil

local function _buildPacketMap()
    if not _Packets then return end
    _packetMap = {}
    for name, id in pairs(_nameToId) do
        local pkt = _Packets[name]
        if pkt then _packetMap[id] = pkt end
    end
end

-- ── ByteNet raw send (fallback when no packet object) ────────────────────────
-- Constructs minimal ByteNet buffer: [u8 packetID][payload bytes]
-- Used when _packetMap doesn't have the packet (e.g. MovementPacket in some builds).

local _bw = nil   -- bufferWriter from ByteNet (resolved lazily)

local function _getRawByteNet()
    if _bw then return _bw end
    local ok, bw = pcall(function()
        return require(ReplicatedStorage:WaitForChild("ByteNet", 1)
            :WaitForChild("process", 1)
            :WaitForChild("bufferWriter", 1))
    end)
    if ok and bw then _bw = bw end
    return _bw
end

-- Send raw movement packet via ByteNet buffer writer
local function _sendMovementRaw(data)
    -- MovementPacket (0x0002) struct (from decompiled ByteNet definitions):
    -- u8 packetId, vec3 position, vec3 velocity, f32 rotation
    local ok = pcall(function()
        local remote = _unreliableRemote or _reliableRemote
        if not remote then return end

        local pos = data.position or Vector3.new(0, 0, 0)
        local vel = data.velocity or Vector3.new(0, 0, 0)
        local rot = data.rotation or 0

        -- Build buffer: 1(id) + 12(pos) + 12(vel) + 4(rot) = 29 bytes
        local buf = buffer.create(29)
        buffer.writeu8(buf, 0, 0x02)  -- packet ID
        buffer.writef32(buf,  1, pos.X)
        buffer.writef32(buf,  5, pos.Y)
        buffer.writef32(buf,  9, pos.Z)
        buffer.writef32(buf, 13, vel.X)
        buffer.writef32(buf, 17, vel.Y)
        buffer.writef32(buf, 21, vel.Z)
        buffer.writef32(buf, 25, rot)

        remote:FireServer(buf, nil)
    end)
    return ok
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function _resolveId(ref)
    if type(ref) == "string" then
        local id = _nameToId[ref]
        assert(id, "[NX.Network] Unknown packet: " .. ref)
        return id
    elseif type(ref) == "number" then
        return ref
    end
    error("[NX.Network] packetRef must be string or number")
end

local function _dispatch(packetId, data)
    local list = _hooks[packetId]
    if list then
        for _, fn in ipairs(list) do
            local ok, err = pcall(fn, data, packetId)
            if not ok then
                warn("[NX.Network] Hook error pkt 0x"
                    .. string.format("%04X", packetId) .. ": " .. tostring(err))
            end
        end
    end
    if Events then Events.Emit("packet:" .. packetId, data) end
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Network.SendPkt(packetRef, data)
    if type(data) ~= "table" then
        warn("[NX.Network] SendPkt: data must be a table")
        return
    end

    local id = _resolveId(packetRef)

    -- Try typed packet object first
    if _packetMap then
        local pkt = _packetMap[id]
        if pkt and type(pkt.send) == "function" then
            if SmoothBuf and SmoothBuf.SmoothBuf then
                SmoothBuf.Queue(id, pkt, data)
            else
                pcall(pkt.send, data)
            end
            return
        end
    end

    -- Fallback: raw ByteNet buffer for known packets
    if id == 0x0002 then
        -- MovementPacket — raw send (most common case)
        _sendMovementRaw(data)
        return
    end

    -- Fallback: generic raw send via reliable remote
    if _reliableRemote then
        local buf = buffer.create(2)
        buffer.writeu16(buf, 0, id)
        pcall(_reliableRemote.FireServer, _reliableRemote, buf, nil)
        return
    end

    -- Only warn ONCE per missing packet ID (no spam)
    if not _warnedMissing[id] then
        _warnedMissing[id] = true
        warn("[NX.Network] No packet object for 0x" .. string.format("%04X", id)
            .. " and no remote found. SendPkt skipped.")
    end
end

function Network.SendRaw(buf)
    local remote = _reliableRemote
    if remote then
        pcall(remote.FireServer, remote, buf, nil)
    else
        warn("[NX.Network] SendRaw: reliable remote not found.")
    end
end

function Network.HookPkt(packetRef, callback)
    assert(type(callback) == "function", "[NX.Network] callback must be function")
    local id = _resolveId(packetRef)
    if not _hooks[id] then _hooks[id] = {} end
    local handle = { id = id, fn = callback }
    table.insert(_hooks[id], callback)
    return handle
end

function Network.UnhookPkt(handle)
    if type(handle) ~= "table" or not handle.id then return end
    local list = _hooks[handle.id]
    if not list then return end
    for i, fn in ipairs(list) do
        if fn == handle.fn then table.remove(list, i); break end
    end
end

function Network.ResolveId(ref) return _resolveId(ref) end

-- ── Startup ───────────────────────────────────────────────────────────────────

function Network.Start(smoothBufModule, eventsModule)
    if _started then return end
    _started = true

    if type(smoothBufModule) == "table" then SmoothBuf = smoothBufModule end
    if type(eventsModule) == "table" and type(eventsModule.On) == "function" then
        Events = eventsModule
    end

    -- Resolve remotes — ByteNet uses "ByteNetReliable" / "ByteNetUnreliable"
    -- (confirmed from Decompiled/ReplicatedStorage/ByteNet/process/client.lua)
    local function tryRemote(name)
        local ok, r = pcall(function()
            return ReplicatedStorage:WaitForChild(name, 5)
        end)
        return (ok and r) and r or nil
    end

    _reliableRemote   = tryRemote("ByteNetReliable")
    _unreliableRemote = tryRemote("ByteNetUnreliable")

    if not _reliableRemote then
        warn("[NX.Network] ByteNetReliable not found — SendPkt may not work.")
    end

    -- Try to load Packets module (optional — game may not have one)
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    if shared then
        local pkts = shared:FindFirstChild("Packets")
        if pkts then
            local ok, result = pcall(require, pkts)
            if ok and type(result) == "table" then
                _Packets = result
                _buildPacketMap()
            end
        end
    end

    -- Bind incoming ByteNet listeners via packet objects if available
    if _packetMap then
        for id, pkt in pairs(_packetMap) do
            if pkt and type(pkt.listen) == "function" then
                pcall(pkt.listen, function(data)
                    _dispatch(id, data)
                end)
            end
        end
    end

    -- Also listen on raw ByteNet remote for packets without typed objects
    -- (parse minimal header: u8 packetId)
    if _reliableRemote and Events then
        _reliableRemote.OnClientEvent:Connect(function(buf, refs)
            if typeof(buf) ~= "buffer" or buffer.len(buf) < 1 then return end
            local ok, id = pcall(buffer.readu8, buf, 0)
            if ok and id then _dispatch(id, { _raw = buf }) end
        end)
    end
end

return Network
