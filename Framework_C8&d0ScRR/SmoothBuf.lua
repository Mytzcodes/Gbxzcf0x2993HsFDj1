-- NXroENinD_DPcKage.SmoothBuf
-- Packet batching layer. Deps resolved lazily inside Start().

local SmoothBuf = {}

local RunService = game:GetService("RunService")

-- Lazy dep: injected by loader before Start() runs
local Events = nil

SmoothBuf.SmoothBuf = true
local _flushRate  = 1
local _frameCount = 0
local _queue      = {}
local _started    = false

local function _flush()
    if #_queue == 0 then return end
    local batch = _queue
    _queue = {}
    for _, item in ipairs(batch) do
        local ok, err = pcall(item.pkt.send, item.data)
        if not ok then
            warn("[NX.SmoothBuf] Send error: " .. tostring(err))
        end
    end
    if Events then Events.Emit("smoothbuf:flush", #batch) end
end

function SmoothBuf.Queue(id, pkt, data)
    table.insert(_queue, { id = id, pkt = pkt, data = data })
end

function SmoothBuf.Flush()
    _flush()
end

function SmoothBuf.SetSmoothBuf(enabled)
    SmoothBuf.SmoothBuf = enabled == true
    if not enabled then _flush() end
end

function SmoothBuf.SetFlushRate(n)
    _flushRate = math.max(1, math.floor(n))
end

function SmoothBuf.GetQueueSize()
    return #_queue
end

function SmoothBuf.Start(eventsModule)
    if _started then return end
    _started = true
    Events = eventsModule  -- injected dependency

    RunService.Heartbeat:Connect(function()
        if not SmoothBuf.SmoothBuf then return end
        _frameCount += 1
        if _frameCount >= _flushRate then
            _frameCount = 0
            _flush()
        end
    end)
end

return SmoothBuf
