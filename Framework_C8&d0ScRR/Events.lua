-- NXroENinD_DPcKage.Events
-- Internal event bus. No external dependencies.

local Events = {}
local _listeners = {}

function Events.On(event, fn)
    if not _listeners[event] then _listeners[event] = {} end
    local handle = { event = event, fn = fn }
    table.insert(_listeners[event], fn)
    return handle
end

function Events.Off(handle)
    if not handle or not handle.event then return end
    local list = _listeners[handle.event]
    if not list then return end
    for i, fn in ipairs(list) do
        if fn == handle.fn then table.remove(list, i); break end
    end
end

function Events.Once(event, fn)
    local handle
    handle = Events.On(event, function(...)
        Events.Off(handle)
        fn(...)
    end)
    return handle
end

function Events.Emit(event, ...)
    local list = _listeners[event]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok then
            warn("[NX.Events] Error in '" .. event .. "': " .. tostring(err))
        end
    end
end

function Events.Clear(event)
    if event then _listeners[event] = nil
    else _listeners = {} end
end

function Events.ListenerCount(event)
    local list = _listeners[event]
    return list and #list or 0
end

return Events
