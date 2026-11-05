--[[
╔══════════════════════════════════════════════════════════════════════════╗
║  NXroENinD_DPcKage.SmoothBuf — Smooth Buffer (Packet Batching)                  ║
╚══════════════════════════════════════════════════════════════════════════╝
  SmoothBuf batches multiple outgoing packets into one frame flush
  instead of sending them one-by-one (reduces RemoteEvent overhead).

  Config:
    SmoothBuf = true/false   → Enable/disable smooth buffering
    FlushRate  = number       → Frames between flushes (default 1 = every frame)

  API (internal, used by Network):
    Queue(id, pkt, data)   → Add packet to current frame queue
    Flush()                → Flush all queued packets now
    SetSmoothBuf(bool)     → Toggle at runtime
--]]

local SmoothBuf = {}

local RunService = game:GetService("RunService")
local Events     = require(script.Parent.Events)

-- ──────────────────────────────────────────────
--  State
-- ──────────────────────────────────────────────
SmoothBuf.SmoothBuf = true    -- Default: enabled
local _flushRate    = 1       -- Every N frames
local _frameCount   = 0
local _queue        = {}      -- { id, pkt, data }[]
local _started      = false
local _conn         = nil

-- ──────────────────────────────────────────────
--  Internal flush
-- ──────────────────────────────────────────────
local function _flush()
    if #_queue == 0 then return end
    local batch = _queue
    _queue = {}
    for _, item in ipairs(batch) do
        local ok, err = pcall(item.pkt.send, item.data)
        if not ok then
            warn("[NXroENinD_DPcKage.SmoothBuf] Send error: " .. tostring(err))
        end
    end
    Events.Emit("smoothbuf:flush", #batch)
end

-- ──────────────────────────────────────────────
--  Public API
-- ──────────────────────────────────────────────

--[[
    Queue(id, pkt, data)
    
    Queue a packet for the next flush cycle.
    Called internally by Network.SendPkt when SmoothBuf is enabled.
]]
function SmoothBuf.Queue(id, pkt, data)
    table.insert(_queue, { id = id, pkt = pkt, data = data })
end

--[[
    Flush()
    
    Manually flush all queued packets immediately.
    Useful before a time-sensitive action.
    
    Example:
        NX.SmoothBuf.Flush()
]]
function SmoothBuf.Flush()
    _flush()
end

--[[
    SetSmoothBuf(enabled)
    
    Toggle SmoothBuf mode at runtime.
    When disabled, packets are sent immediately (old behavior).
    When enabled, packets are batched per frame.
    
    Example:
        NX.SetSmoothBuf(true)   -- enable batching
        NX.SetSmoothBuf(false)  -- direct send mode
]]
function SmoothBuf.SetSmoothBuf(enabled)
    SmoothBuf.SmoothBuf = enabled == true
    if not enabled then
        -- Flush remaining queue before switching off
        _flush()
    end
end

--[[
    SetFlushRate(n)
    
    Set flush every N frames. Default 1 (every frame).
    Higher values = more batching, more latency.
    
    Example:
        NX.SmoothBuf.SetFlushRate(2)  -- flush every 2 frames
]]
function SmoothBuf.SetFlushRate(n)
    _flushRate = math.max(1, math.floor(n))
end

--[[
    GetQueueSize()
    
    Returns how many packets are currently queued.
]]
function SmoothBuf.GetQueueSize()
    return #_queue
end

-- ──────────────────────────────────────────────
--  Startup: hook into Heartbeat
-- ──────────────────────────────────────────────
function SmoothBuf.Start()
    if _started then return end
    _started = true

    _conn = RunService.Heartbeat:Connect(function()
        if not SmoothBuf.SmoothBuf then return end
        _frameCount += 1
        if _frameCount >= _flushRate then
            _frameCount = 0
            _flush()
        end
    end)
end

return SmoothBuf
