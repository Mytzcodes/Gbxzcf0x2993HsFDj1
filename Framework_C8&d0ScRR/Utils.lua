--[[
╔══════════════════════════════════════════════════════════════════════════╗
║  NXroENinD_DPcKage.Utils — General Utility Functions                            ║
╚══════════════════════════════════════════════════════════════════════════╝
--]]

local Utils = {}

-- ──────────────────────────────────────────────
--  String Utilities
-- ──────────────────────────────────────────────

function Utils.trim(s)
    return s:match("^%s*(.-)%s*$")
end

function Utils.split(s, sep)
    local result = {}
    for part in s:gmatch("[^" .. sep .. "]+") do
        table.insert(result, part)
    end
    return result
end

function Utils.startsWith(s, prefix)
    return s:sub(1, #prefix) == prefix
end

function Utils.endsWith(s, suffix)
    return s:sub(-#suffix) == suffix
end

-- ──────────────────────────────────────────────
--  Table Utilities
-- ──────────────────────────────────────────────

function Utils.deepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = type(v) == "table" and Utils.deepCopy(v) or v
    end
    return copy
end

function Utils.keys(t)
    local k = {}
    for key in pairs(t) do table.insert(k, key) end
    return k
end

function Utils.values(t)
    local v = {}
    for _, val in pairs(t) do table.insert(v, val) end
    return v
end

function Utils.filter(t, fn)
    local r = {}
    for _, v in ipairs(t) do
        if fn(v) then table.insert(r, v) end
    end
    return r
end

function Utils.map(t, fn)
    local r = {}
    for i, v in ipairs(t) do r[i] = fn(v) end
    return r
end

function Utils.reduce(t, fn, init)
    local acc = init
    for _, v in ipairs(t) do acc = fn(acc, v) end
    return acc
end

function Utils.find(t, fn)
    for _, v in ipairs(t) do
        if fn(v) then return v end
    end
    return nil
end

-- ──────────────────────────────────────────────
--  Math Utilities
-- ──────────────────────────────────────────────

function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

function Utils.clamp(v, min, max)
    return math.max(min, math.min(max, v))
end

function Utils.round(n, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(n * mult + 0.5) / mult
end

function Utils.dist2D(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx*dx + dy*dy)
end

function Utils.dist3D(a, b)
    return (b - a).Magnitude
end

-- ──────────────────────────────────────────────
--  Color Utilities
-- ──────────────────────────────────────────────

function Utils.color32ToColor3(c)
    local r = bit32.rshift(bit32.band(c, 0xFF0000), 16)
    local g = bit32.rshift(bit32.band(c, 0x00FF00), 8)
    local b = bit32.band(c, 0x0000FF)
    return Color3.fromRGB(r, g, b)
end

function Utils.color3To32(c)
    local r = math.floor(c.R * 255)
    local g = math.floor(c.G * 255)
    local b = math.floor(c.B * 255)
    return bit32.bor(bit32.lshift(r, 16), bit32.lshift(g, 8), b)
end

-- ──────────────────────────────────────────────
--  Time Utilities
-- ──────────────────────────────────────────────

function Utils.formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

function Utils.timestamp()
    return os.time()
end

-- ──────────────────────────────────────────────
--  Packet Utilities
-- ──────────────────────────────────────────────

function Utils.pktIdToHex(id)
    return string.format("0x%04X", id)
end

function Utils.pktIdToName(id)
    local names = {
        [0x0001]="InputPacket", [0x0002]="MovementPacket",
        [0x0003]="ChatPacket",  [0x0004]="PlaceBlockPacket",
        [0x0005]="BreakBlockPacket", [0x0006]="DropItemPacket",
        [0x0007]="CollectItemPacket",[0x0008]="WearItemPacket",
        [0x0009]="RemoveItemPacket", [0x000A]="TrashItemPacket",
        [0x000B]="UseItemPacket",    [0x000C]="EnterDoorPacket",
        [0x000D]="WorldRequestPacket",[0x000E]="WorldDataPacket",
        [0x000F]="TileUpdatePacket", [0x0010]="InventoryUpdatePacket",
        [0x0011]="PlayerJoinPacket", [0x0012]="PlayerLeavePacket",
        [0x0013]="PlayerUpdatePacket",[0x0014]="ConsoleMessagePacket",
        [0x0015]="DialogPacket",     [0x0016]="TradeRequestPacket",
        [0x0017]="TradeUpdatePacket",[0x0018]="PingPacket",
        [0x0019]="SyncClockPacket",  [0x001A]="AdminCommandPacket",
        [0x001B]="NpcInteractPacket",[0x001C]="CraftPacket",
        [0x001D]="BuyPacket",        [0x001E]="SellPacket",
        [0x001F]="SignEditPacket",   [0x0020]="LockPacket",
        [0x0021]="FriendPacket",     [0x0022]="EmotePacket",
        [0x0023]="RespawnPacket",    [0x0024]="GrowthUpdatePacket",
        [0x0025]="WeatherPacket",    [0x0026]="EffectPacket",
        [0x0027]="SoundPacket",
    }
    return names[id] or ("Pkt_" .. Utils.pktIdToHex(id))
end

return Utils
