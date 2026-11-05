-- NXroENinD_DPcKage.Scheduler v2.1
-- After / Every / Cancel / NextFrame / PauseAll / ResumeAll
-- No external dependencies.

local Scheduler = {}

local RunService = game:GetService("RunService")

local _tasks   = {}
local _nextId  = 0
local _paused  = false   -- global pause flag for ModDetect

local function _newId()
    _nextId += 1
    return _nextId
end

--[[
    After(seconds, fn) → handle
    Call fn once after delay. Respects PauseAll.
]]
function Scheduler.After(seconds, fn)
    local id     = _newId()
    local handle = { id = id, active = true }
    _tasks[id] = task.delay(seconds, function()
        if handle.active and not _paused then
            _tasks[id] = nil
            fn()
        elseif handle.active and _paused then
            -- re-schedule check until unpaused
            repeat task.wait(0.5) until not _paused or not handle.active
            if handle.active then
                _tasks[id] = nil
                pcall(fn)
            end
        end
    end)
    return handle
end

--[[
    Every(seconds, fn) → handle
    Call fn repeatedly every `seconds`. fn can return false to self-cancel.
    Respects PauseAll — skips tick when paused.
]]
function Scheduler.Every(seconds, fn)
    local id     = _newId()
    local handle = { id = id, active = true }
    _tasks[id] = task.spawn(function()
        while handle.active do
            task.wait(seconds)
            if not handle.active then break end
            if _paused then continue end   -- skip tick when paused
            local ok, result = pcall(fn)
            if not ok then
                -- silent: no warn() (visual only policy)
            elseif result == false then
                handle.active = false
                _tasks[id] = nil
                break
            end
        end
    end)
    return handle
end

--[[
    Cancel(handle)
    Stop a task created by After() or Every().
]]
function Scheduler.Cancel(handle)
    if not handle then return end
    handle.active = false
    local t = _tasks[handle.id]
    if t then
        pcall(task.cancel, t)
        _tasks[handle.id] = nil
    end
end

--[[
    NextFrame(fn)
    Run fn on the very next Heartbeat frame.
]]
function Scheduler.NextFrame(fn)
    local conn
    conn = RunService.Heartbeat:Connect(function()
        conn:Disconnect()
        pcall(fn)
    end)
end

--[[
    CancelAll()
    Cancel all active scheduled tasks.
]]
function Scheduler.CancelAll()
    for id, t in pairs(_tasks) do
        pcall(task.cancel, t)
        _tasks[id] = nil
    end
end

--[[
    PauseAll()
    Pause all Every() ticks. Used by ModDetect on mod detection.
    After() tasks will wait until ResumeAll() is called.
]]
function Scheduler.PauseAll()
    _paused = true
end

--[[
    ResumeAll()
    Resume all paused ticks.
]]
function Scheduler.ResumeAll()
    _paused = false
end

function Scheduler.IsPaused()
    return _paused
end

return Scheduler
