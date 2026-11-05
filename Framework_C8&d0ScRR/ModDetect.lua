--[[
  ╔══════════════════════════════════════════════════╗
  ║   NXroENinD_DPcKage · ModDetect                 ║
  ║   Auto-detect Mods/Staff in world               ║
  ║   Auto-action: sleep | leave | pause | custom   ║
  ╚══════════════════════════════════════════════════╝

  Uses game's own Roles module (ReplicatedStorage.Shared.Roles)
  — same method the game itself uses: StaffRoles attribute + ModeratorList.

  On mod detected → triggers configured ACTION:
    "sleep"   — pause all NX macros/scheduler + visual alert
    "leave"   — call Net.call("LeaveWorld") + visual alert  
    "pause"   — fires event "moddetect:alert" (custom handler)
    "custom"  — calls your callback function

  Usage:
    NX.ModWatch({
        action   = "sleep",          -- "sleep" | "leave" | "pause" | "custom"
        onDetect = function(mod) end, -- optional custom callback
        onClear  = function() end,    -- called when mod leaves
        alertMsg = true,             -- show visual alert (default true)
    })
    NX.ModWatchOff()
    NX.IsModPresent()   → bool, modName?

  Config:
    NX.ModDetect.SetAction("leave")
    NX.ModDetect.AddWhitelist(userId)   -- never trigger for this user
]]

local ModDetect = {}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local Console   = nil
local Events    = nil
local Network   = nil
local Scheduler = nil

local _started   = false
local _watching  = false
local _action    = "sleep"
local _onDetect  = nil
local _onClear   = nil
local _alertMsg  = true
local _whitelist = {}   -- userId → true

local _modPresent    = false
local _modName       = nil
local _modUserId     = nil
local _enteredCn     = nil
local _leftCn        = nil
local _checkCn       = nil

-- ── Roles module access ───────────────────────────────────────────────────────

local _Roles = nil
local function _getRoles()
    if _Roles then return _Roles end
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local sh = rs:FindFirstChild("Shared")
        if sh then
            local rm = sh:FindFirstChild("Roles")
            if rm then _Roles = require(rm) end
        end
    end)
    return _Roles
end

-- ── Check if userId is staff ──────────────────────────────────────────────────

local function _isStaff(userId)
    if _whitelist[userId] then return false end

    local roles = _getRoles()
    if roles then
        local ok, result = pcall(roles.isStaff, userId)
        if ok and result then return true end
    end

    -- Fallback: check StaffRoles attribute directly
    local ok2, result2 = pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local sr = rs:FindFirstChild("StaffRoles")
        if not sr then return false end
        local attr = sr:GetAttribute("u" .. tostring(userId))
        return attr == "moderator" or attr == "developer"
    end)
    if ok2 and result2 then return true end

    -- Also check ModeratorList
    local ok3, result3 = pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local ml = rs:FindFirstChild("ModeratorList")
        if not ml then return false end
        return ml:GetAttribute("u" .. tostring(userId)) == true
    end)
    return ok3 and result3
end

-- ── Actions ───────────────────────────────────────────────────────────────────

local _paused = false

local function _doAction(modInfo)
    if _action == "sleep" then
        -- Pause all NX scheduled tasks
        _paused = true
        if Scheduler and type(Scheduler.PauseAll) == "function" then
            Scheduler.PauseAll()
        end
        if Console then
            Console.ConsoleMsg("⚠ MOD DETECTED: " .. (modInfo.name or "?") .. " — Scripts PAUSED", "red")
        end

    elseif _action == "leave" then
        if Console then
            Console.ConsoleMsg("⚠ MOD DETECTED: " .. (modInfo.name or "?") .. " — LEAVING WORLD", "red")
        end
        task.wait(0.5)
        -- Use Net.call to leave world
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local sh = rs:FindFirstChild("Shared")
            if sh then
                local nm = sh:FindFirstChild("Net")
                if nm then
                    local Net = require(nm)
                    if Net and Net.leave and type(Net.leave.send) == "function" then
                        Net.leave.send()
                    elseif Net and type(Net.call) == "function" then
                        Net.call("LeaveWorld")
                    end
                end
            end
        end)

    elseif _action == "pause" then
        if Console then
            Console.ConsoleMsg("⚠ MOD: " .. (modInfo.name or "?") .. " — Paused", "yellow")
        end

    elseif _action == "custom" and type(_onDetect) == "function" then
        _onDetect(modInfo)
        return   -- skip built-in msg
    end

    if _alertMsg and Console and _action ~= "custom" then
        -- already handled above
    end

    if Events then Events.Emit("moddetect:alert", modInfo) end
end

local function _doResume(modInfo)
    if _paused then
        _paused = false
        if Scheduler and type(Scheduler.ResumeAll) == "function" then
            Scheduler.ResumeAll()
        end
        if Console then
            Console.ConsoleMsg("✅ Mod " .. (modInfo.name or "?") .. " left — Scripts RESUMED", "green")
        end
    else
        if Console and _alertMsg then
            Console.ConsoleMsg("✅ Mod left world", "green")
        end
    end

    if type(_onClear) == "function" then _onClear(modInfo) end
    if Events then Events.Emit("moddetect:clear", modInfo) end
end

-- ── Tracking ──────────────────────────────────────────────────────────────────

local function _onPlayerEntered(p)
    if not _watching then return end
    if not p or not p.userId then return end
    if _whitelist[p.userId] then return end

    if _isStaff(p.userId) then
        _modPresent  = true
        _modName     = p.name
        _modUserId   = p.userId
        _doAction({ name = p.name, userId = p.userId })
    end
end

local function _onPlayerLeft(p)
    if not _watching then return end
    if not _modPresent then return end

    -- Check if the leaving player is our tracked mod
    local leftId = type(p) == "number" and p or (type(p) == "table" and p.userId)
    if leftId and leftId == _modUserId then
        _modPresent = false
        local info  = { name = _modName, userId = _modUserId }
        _modName    = nil
        _modUserId  = nil
        _doResume(info)
    end
end

-- ── Scan existing players on start ────────────────────────────────────────────

local function _scanCurrent()
    -- Scan via Roblox Players service (server-side players not always visible)
    -- Also hook via Net.entered if available
    pcall(function()
        for _, rbxPlayer in ipairs(Players:GetPlayers()) do
            if rbxPlayer ~= Players.LocalPlayer then
                _onPlayerEntered({ userId = rbxPlayer.UserId, name = rbxPlayer.Name })
                if _modPresent then break end
            end
        end
    end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

--[[
    Watch(opts?)
    opts.action   : "sleep"|"leave"|"pause"|"custom"
    opts.onDetect : function(modInfo) — called on detection
    opts.onClear  : function(modInfo) — called when mod leaves
    opts.alertMsg : bool (default true)
]]
function ModDetect.Watch(opts)
    opts = opts or {}
    _action   = opts.action   or _action
    _onDetect = opts.onDetect or _onDetect
    _onClear  = opts.onClear  or _onClear
    _alertMsg = opts.alertMsg ~= false

    _watching = true

    -- Hook Net events
    local net = nil
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local sh = rs:FindFirstChild("Shared")
        if sh then net = require(sh:FindFirstChild("Net")) end
    end)

    if net then
        if net.entered and type(net.entered.listen) == "function" then
            pcall(net.entered.listen, _onPlayerEntered)
        end
        if net.left and type(net.left.listen) == "function" then
            pcall(net.left.listen, _onPlayerLeft)
        end
    end

    -- Also hook via Events
    if Events then
        Events.On("entered", _onPlayerEntered)
        Events.On("left",    _onPlayerLeft)
    end

    -- Scan players already in world
    _scanCurrent()

    if Console then
        Console.ConsoleMsg("👁 ModWatch ON [" .. _action .. "]", "yellow")
    end
end

function ModDetect.Off()
    _watching   = false
    _modPresent = false
    _modName    = nil
    _modUserId  = nil
    if Console then Console.ConsoleMsg("👁 ModWatch OFF", "gray") end
end

function ModDetect.IsModPresent()
    return _modPresent, _modName, _modUserId
end

function ModDetect.SetAction(action)
    _action = action
end

function ModDetect.AddWhitelist(userId)
    _whitelist[tonumber(userId)] = true
end

function ModDetect.RemoveWhitelist(userId)
    _whitelist[tonumber(userId)] = nil
end

-- ── Start ─────────────────────────────────────────────────────────────────────

function ModDetect.Start(eventsModule, consoleModule, networkModule, schedulerModule)
    if _started then return end
    _started = true
    if type(eventsModule)   == "table" then Events    = eventsModule    end
    if type(consoleModule)  == "table" then Console   = consoleModule   end
    if type(networkModule)  == "table" then Network   = networkModule   end
    if type(schedulerModule)== "table" then Scheduler = schedulerModule end
end

return ModDetect
