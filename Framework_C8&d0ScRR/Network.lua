--[[
    NXroENinD_DPcKage.Network v2.0
    
    Sends packets via game's native Net module (ReplicatedStorage.Shared.Net).
    Chat via TextChatService WorldChannels.
    
    Key fix: Use require() on already-loaded module = gets cached copy.
    All sends are wrapped in pcall so nothing ever throws.
]]

local Network = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local SmoothBuf = nil
local Events    = nil

local _Net     = nil
local _started = false
local _hooks   = {}
local _reliableRemote   = nil
local _unreliableRemote = nil
local _warnOnce = {}

-- ── Resolve Net ───────────────────────────────────────────────────────────────

local function _getNet()
    if _Net then return _Net end
    local ok, res = pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        if not shared then return nil end
        local netMod = shared:FindFirstChild("Net")
        if not netMod then return nil end
        return require(netMod)
    end)
    if ok and type(res) == "table" then
        _Net = res
    end
    return _Net
end

-- ── Dispatch ──────────────────────────────────────────────────────────────────

local function _dispatch(id, data)
    local list = _hooks[id]
    if list then
        for _, fn in ipairs(list) do pcall(fn, data, id) end
    end
    if Events and type(Events.Emit) == "function" then
        Events.Emit("packet:" .. tostring(id), data)
    end
end

-- ── Warn once ─────────────────────────────────────────────────────────────────

local function _warnOnce_(key, msg)
    if _warnOnce[key] then return end
    _warnOnce[key] = true
    if Events and type(Events.Emit) == "function" then
        Events.Emit("network:warn", msg)
    end
end

-- ── Send helpers ──────────────────────────────────────────────────────────────

local function _sendViaNativeNet(nameOrId, data)
    local net = _getNet()
    if not net then
        _warnOnce_("no_net", "ReplicatedStorage.Shared.Net not found")
        return false
    end
    data = data or {}

    local n = type(nameOrId) == "string" and nameOrId:lower() or ""

    -- Move / Teleport
    if n == "move" or n == "movementpacket" or nameOrId == 0x0002 then
        if net.move and type(net.move.send) == "function" then
            pcall(net.move.send, {
                x     = tonumber(data.x) or 0,
                y     = tonumber(data.y) or 0,
                vx    = tonumber(data.vx) or 0,
                vy    = tonumber(data.vy) or 0,
                flags = data.flags ~= nil and data.flags or 2,
                t     = data.t ~= nil and data.t or 65535,
            })
            return true
        end
        _warnOnce_("no_move", "net.move.send not available")
        return false
    end

    -- Act (punch / build / etc)
    if n == "act" or n == "punch" or n == "breakblockpacket" or nameOrId == 0x0005 then
        if net.act and type(net.act.send) == "function" then
            pcall(net.act.send, {
                kind = data.kind or 1,
                x    = tonumber(data.x) or 0,
                y    = tonumber(data.y) or 0,
            })
            return true
        end
        return false
    end

    -- Tile (place block)
    if n == "tile" or n == "placeblockpacket" or nameOrId == 0x0004 then
        if net.tile and type(net.tile.send) == "function" then
            pcall(net.tile.send, {
                layer = data.layer or 0,
                x     = math.floor(tonumber(data.x) or 0),
                y     = math.floor(tonumber(data.y) or 0),
                id    = data.id or data.itemId or 0,
                flip  = data.flip or false,
            })
            return true
        end
        return false
    end

    -- Drop item
    if n == "drop" or n == "dropitempacket" or nameOrId == 0x0006 then
        if net.drop and type(net.drop.send) == "function" then
            pcall(net.drop.send, {
                id = data.id or 0,
                n  = data.n or data.count or 1,
                x  = tonumber(data.x) or 0,
                y  = tonumber(data.y) or 0,
            })
            return true
        end
        return false
    end

    -- Take / Collect item
    if n == "take" or n == "collectitempacket" or nameOrId == 0x0007 then
        if net.take and type(net.take.send) == "function" then
            pcall(net.take.send, {
                seq  = data.seq or 0,
                uid  = data.uid or 0,
                want = data.want or data.itemId or 0,
            })
            return true
        end
        return false
    end

    -- Wear / Equip
    if n == "wear" or n == "wearitempacket" or nameOrId == 0x0008 then
        if net.wear and type(net.wear.send) == "function" then
            pcall(net.wear.send, type(data) == "table" and data or {})
            return true
        end
        return false
    end

    -- Harvest
    if n == "harvest" then
        if net.harvest and type(net.harvest.send) == "function" then
            pcall(net.harvest.send, {
                x = math.floor(tonumber(data.x) or 0),
                y = math.floor(tonumber(data.y) or 0),
            })
            return true
        end
        return false
    end

    -- Toggle (door / switch)
    if n == "toggle" then
        if net.toggle and type(net.toggle.send) == "function" then
            pcall(net.toggle.send, {
                x = math.floor(tonumber(data.x) or 0),
                y = math.floor(tonumber(data.y) or 0),
            })
            return true
        end
        return false
    end

    -- Spin (wheel)
    if n == "spin" then
        if net.spin and type(net.spin.send) == "function" then
            pcall(net.spin.send, {
                x = math.floor(tonumber(data.x) or 0),
                y = math.floor(tonumber(data.y) or 0),
            })
            return true
        end
        return false
    end

    -- Splice (plant seed)
    if n == "splice" then
        if net.splice and type(net.splice.send) == "function" then
            pcall(net.splice.send, {
                seq  = data.seq or 0,
                x    = math.floor(tonumber(data.x) or 0),
                y    = math.floor(tonumber(data.y) or 0),
                seed = data.seed or 0,
            })
            return true
        end
        return false
    end

    -- Chat — via TextChatService WorldChannels
    if n == "chat" or n == "chatpacket" or nameOrId == 0x0003 then
        local msg = type(data) == "string" and data or (data.text or data.message or "")
        local channel = data.channel or "world"
        local ok = pcall(function()
            local tcs = game:GetService("TextChatService")
            local wc = tcs:FindFirstChild("WorldChannels")
            if not wc then error("No WorldChannels") end
            local ch = wc:FindFirstChild(channel) or wc:FindFirstChild("world") or wc:GetChildren()[1]
            if not ch then error("No channel found") end
            ch:SendAsync(msg)
        end)
        return ok
    end

    -- Net.call (RPC)
    if n == "call" then
        if net.call and type(net.call) == "function" then
            local args = type(data.args) == "table" and data.args or {}
            pcall(net.call, data.name or "", table.unpack(args))
            return true
        end
        return false
    end

    -- Leave world
    if n == "leave" or n == "leaveworld" then
        if net.leave and type(net.leave.send) == "function" then
            pcall(net.leave.send)
            return true
        end
        return false
    end

    return false
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Network.SendPkt(packetRef, data)
    if packetRef == nil then return end
    data = data or {}
    local sent = _sendViaNativeNet(packetRef, data)
    if sent then return end
    -- Throttled warning
    _warnOnce_(tostring(packetRef), "SendPkt: no handler for " .. tostring(packetRef))
end

--[[
    SendChat(message, channel?)
    channel: "world" (default), "global", "private"
]]
function Network.SendChat(message, channel)
    message = tostring(message or "")
    channel = channel or "world"
    local ok, err = pcall(function()
        local tcs = game:GetService("TextChatService")
        local wc = tcs:FindFirstChild("WorldChannels")
        if not wc then error("WorldChannels not found in TextChatService") end
        local ch = wc:FindFirstChild(channel)
        if not ch then
            -- Try first available channel
            local children = wc:GetChildren()
            if #children > 0 then
                ch = children[1]
            else
                error("No text channels available")
            end
        end
        ch:SendAsync(message)
    end)
    return ok, err
end

--[[
    SendRaw(buf)
    Sends a raw buffer through ByteNetReliable remote.
    Note: This only works if the game's ByteNet is expecting raw fire.
    For most packets, use SendPkt instead.
]]
function Network.SendRaw(buf)
    if typeof(buf) ~= "buffer" then return end
    local remote = _reliableRemote or _unreliableRemote
    if remote then
        pcall(function() remote:FireServer(buf, nil) end)
    end
end

--[[
    Call(name, ...)
    Calls Net.call(name, ...) — server RPC
]]
function Network.Call(name, ...)
    local net = _getNet()
    if net and type(net.call) == "function" then
        return pcall(net.call, name, ...)
    end
    return false, "Net.call not available"
end

--[[
    HookPkt(ref, callback) — register listener
]]
function Network.HookPkt(ref, callback)
    if type(callback) ~= "function" then return { id = ref } end
    local id = tostring(ref)
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

function Network.GetNet() return _getNet() end

-- ── Start ─────────────────────────────────────────────────────────────────────

function Network.Start(smoothBufModule, eventsModule)
    if _started then return end
    _started = true

    SmoothBuf = smoothBufModule
    if type(eventsModule) == "table" then Events = eventsModule end

    -- Grab ByteNet remotes (for SendRaw)
    pcall(function()
        _reliableRemote   = ReplicatedStorage:FindFirstChild("ByteNetReliable")
        _unreliableRemote = ReplicatedStorage:FindFirstChild("ByteNetUnreliable")
    end)

    -- Hook native Net listeners for incoming packets
    local net = _getNet()
    if net then
        -- Player entered world
        if net.entered and type(net.entered.listen) == "function" then
            pcall(net.entered.listen, function(p)
                _dispatch("entered", p)
                _dispatch(0x0011, p)
            end)
        end
        -- Other player moved
        if net.moved and type(net.moved.listen) == "function" then
            pcall(net.moved.listen, function(p)
                _dispatch("moved", p)
                _dispatch(0x0013, p)
            end)
        end
        -- Player left
        if net.left and type(net.left.listen) == "function" then
            pcall(net.left.listen, function(id)
                _dispatch("left", id)
                _dispatch(0x0012, { id = id })
            end)
        end
        -- Tile changed
        if net.tileChanged and type(net.tileChanged.listen) == "function" then
            pcall(net.tileChanged.listen, function(p)
                _dispatch("tileChanged", p)
                _dispatch(0x000F, p)
            end)
        end
        -- Inventory sync
        if net.inventorySync and type(net.inventorySync.listen) == "function" then
            pcall(net.inventorySync.listen, function(p)
                _dispatch("inventorySync", p)
                _dispatch(0x0010, p)
            end)
        end
        -- World notice (system messages)
        if net.worldNotice and type(net.worldNotice.listen) == "function" then
            pcall(net.worldNotice.listen, function(p)
                _dispatch("worldNotice", p)
                _dispatch(0x0014, p)
            end)
        end
    end
end

return Network
