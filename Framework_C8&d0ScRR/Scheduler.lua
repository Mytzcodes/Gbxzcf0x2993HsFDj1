-- NXroENinD_DPcKage.Scheduler
-- After / Every / Cancel / NextFrame
-- No external dependencies.

local Scheduler = {}

local RunService = game:GetService("RunService")

local _tasks  = {}
local _nextId = 0

local function _newId()
    _nextId += 1
    return _nextId
end

--[[
    After(seconds, fn) → handle
    Call fn once after delay. Handle can be cancelled before it fires.

    NX.After(5, function() NX.ConsoleMsg("5s done") end)
]]
function Scheduler.After(seconds, fn)
    local id     = _newId()
    local handle = { id = id, active = true }
    _tasks[id] = task.delay(seconds, function()
        if handle.active then
            _tasks[id] = nil
            fn()
        end
    end)
    return handle
end

--[[
    Every(seconds, fn) → handle
    Call fn repeatedly every `seconds`. fn can return false to self-cancel.

    local t = NX.Every(1, function() print("tick") end)
    NX.Cancel(t)
]]
function Scheduler.Every(seconds, fn)
    local id     = _newId()
    local handle = { id = id, active = true }
    _tasks[id] = task.spawn(function()
        while handle.active do
            task.wait(seconds)
            if handle.active then
                local ok, result = pcall(fn)
                if not ok then
                    warn("[NX.Scheduler] Every error: " .. tostring(result))
                elseif result == false then
                    handle.active = false
                    _tasks[id] = nil
                    break
                end
            end
        end
    end)
    return handle
end

--[[
    Cancel(handle)
    Stop a task created by After() or Every().

    NX.Cancel(myTimer)
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

    NX.NextFrame(function() print("next frame!") end)
]]
function Scheduler.NextFrame(fn)
    local conn
    conn = RunService.Heartbeat:Connect(function()
        conn:Disconnect()
        fn()
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

return Scheduler
