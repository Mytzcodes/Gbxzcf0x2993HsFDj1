--[[
╔══════════════════════════════════════════════════════════════════════════╗
║  NXroENinD_DPcKage.Scheduler — After / Every / Cancel                           ║
╚══════════════════════════════════════════════════════════════════════════╝
  Provides:
    After(seconds, fn)       → Run fn once after delay
    Every(seconds, fn)       → Run fn repeatedly, returns handle
    Cancel(handle)           → Stop a recurring task
    NextFrame(fn)            → Run fn on next Heartbeat
--]]

local Scheduler = {}

local RunService = game:GetService("RunService")

local _tasks = {}
local _nextId = 0

local function _newId()
    _nextId += 1
    return _nextId
end

--[[
    After(seconds, fn)
    
    Call fn once after `seconds` delay.
    Returns a handle (can be cancelled if not yet fired).
    
    Example:
        NX.After(5, function()
            NX.ConsoleMsg("5 seconds passed!")
        end)
]]
function Scheduler.After(seconds, fn)
    local id = _newId()
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
    Every(seconds, fn)
    
    Call fn every `seconds`. Returns handle.
    fn can return false to self-cancel.
    
    Example:
        local t = NX.Every(1, function()
            NX.ConsoleMsg("Tick!")
        end)
        -- Later:
        NX.Cancel(t)
]]
function Scheduler.Every(seconds, fn)
    local id = _newId()
    local handle = { id = id, active = true }
    local function loop()
        while handle.active do
            task.wait(seconds)
            if handle.active then
                local ok, result = pcall(fn)
                if not ok then
                    warn("[NXroENinD_DPcKage.Scheduler] Every error:", result)
                elseif result == false then
                    handle.active = false
                    _tasks[id] = nil
                    break
                end
            end
        end
    end
    _tasks[id] = task.spawn(loop)
    return handle
end

--[[
    Cancel(handle)
    
    Cancel a task created with After() or Every().
    
    Example:
        local t = NX.Every(1, fn)
        NX.Cancel(t)
]]
function Scheduler.Cancel(handle)
    if not handle then return end
    handle.active = false
    local t = _tasks[handle.id]
    if t then
        task.cancel(t)
        _tasks[handle.id] = nil
    end
end

--[[
    NextFrame(fn)
    
    Run fn on the very next Heartbeat frame.
    
    Example:
        NX.NextFrame(function()
            print("Next frame!")
        end)
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
    
    Cancel ALL active tasks.
]]
function Scheduler.CancelAll()
    for id, t in pairs(_tasks) do
        pcall(task.cancel, t)
        _tasks[id] = nil
    end
end

return Scheduler
