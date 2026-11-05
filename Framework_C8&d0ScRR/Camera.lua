--[[
  ╔══════════════════════════════════════════════════╗
  ║   NXroENinD_DPcKage · Camera                    ║
  ║   Zoom + Camera Lock — elegant & safe           ║
  ╚══════════════════════════════════════════════════╝

  GrowBlox uses a 2D side-scrolling camera via a custom Camera Part
  (v_u_57.Name = "Camera" in Game.lua). The camera is NOT workspace.CurrentCamera.
  
  Strategy:
    - FOV: Adjust workspace.CurrentCamera.FieldOfView (Roblox default 70, we allow up to 110)
    - Zoom: Move camera Z-axis back (CFrame offset) for wider view
    - Game's own camera part is at some Y offset from player position

  Usage:
    NX.SetZoom(level)      — 0-10, default 0
    NX.ZoomIn() / ZoomOut()
    NX.ResetZoom()
    NX.LockCamera(bool)    — lock camera to fixed position
]]

local Camera = {}

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

local Console = nil
local Events  = nil

local _started = false
local _zoomLevel = 0           -- 0 = default
local MIN_ZOOM   = 0
local MAX_ZOOM   = 10          -- cap to prevent crash
local _camCn     = nil         -- heartbeat connection
local _locked    = false
local _lockCFrame = nil

-- ── FOV mapping ───────────────────────────────────────────────────────────────
-- Roblox default FOV = 70
-- GrowBlox is 2D so camera is orthographic-style fixed Z
-- We adjust FieldOfView to simulate zoom

local BASE_FOV = 70
local ZOOM_FOV_STEP = 4   -- each zoom level adds 4 FOV (wider = zoomed out)

local function _getFOV(zoomLv)
    return math.clamp(BASE_FOV + zoomLv * ZOOM_FOV_STEP, 50, BASE_FOV + MAX_ZOOM * ZOOM_FOV_STEP)
end

-- ── Camera Part Z offset ──────────────────────────────────────────────────────
-- GrowBlox camera part sits at some Z distance from the 2D plane
-- Pushing it further back gives wider viewport

local BASE_Z_DIST = 25    -- approximate default camera Z in GrowBlox
local ZOOM_Z_STEP = 3.5   -- units per zoom level

local function _applyZoom(zoomLv)
    local cam = workspace.CurrentCamera
    if not cam then return end

    -- FOV approach (reliable)
    pcall(function()
        cam.FieldOfView = _getFOV(zoomLv)
    end)

    -- Also try to push the game's internal Camera part back
    pcall(function()
        local lp = Players.LocalPlayer
        if not lp then return end
        local pg = lp:FindFirstChild("PlayerGui")
        if not pg then return end
        -- Game.lua: v_u_57.Name = "Camera" — a BasePart in workspace
        local gameCam = workspace:FindFirstChild("Camera")
              or workspace:FindFirstChildWhichIsA("Part", true)
        -- We don't modify game's internal camera part to avoid desync
        -- FOV is sufficient for GrowBlox's fixed Z camera
    end)
end

-- ── Lock / Unlock ──────────────────────────────────────────────────────────────

local function _applyLock()
    if not _locked or not _lockCFrame then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    pcall(function()
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = _lockCFrame
    end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

--[[
    SetZoom(level)
    level: 0 (default view) to 10 (maximum zoom out)
    negative values zoom IN closer (min -5)
]]
function Camera.SetZoom(level)
    _zoomLevel = math.clamp(tonumber(level) or 0, -5, MAX_ZOOM)
    _applyZoom(_zoomLevel)

    if Console and type(Console.ConsoleMsg) == "function" then
        Console.ConsoleMsg("🔭 Zoom: " .. _zoomLevel, "cyan")
    end
end

function Camera.ZoomIn(step)
    Camera.SetZoom(_zoomLevel - (step or 1))
end

function Camera.ZoomOut(step)
    Camera.SetZoom(_zoomLevel + (step or 1))
end

function Camera.ResetZoom()
    Camera.SetZoom(0)
    -- Restore default camera type
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
            cam.FieldOfView = BASE_FOV
            cam.CameraType = Enum.CameraType.Custom
        end
    end)
    if Console and type(Console.ConsoleMsg) == "function" then
        Console.ConsoleMsg("🔭 Zoom reset", "gray")
    end
end

function Camera.GetZoom()
    return _zoomLevel
end

--[[
    LockCamera(bool, cframe?)
    Lock camera to current position or given CFrame
]]
function Camera.LockCamera(enabled, cf)
    _locked = enabled
    if enabled then
        local cam = workspace.CurrentCamera
        _lockCFrame = cf or (cam and cam.CFrame) or nil
        if _lockCFrame then
            _applyLock()
            if Console and type(Console.ConsoleMsg) == "function" then
                Console.ConsoleMsg("📷 Camera LOCKED", "yellow")
            end
        end
    else
        _lockCFrame = nil
        pcall(function()
            local cam = workspace.CurrentCamera
            if cam then cam.CameraType = Enum.CameraType.Custom end
        end)
        if Console and type(Console.ConsoleMsg) == "function" then
            Console.ConsoleMsg("📷 Camera UNLOCKED", "gray")
        end
    end
end

-- ── Start ─────────────────────────────────────────────────────────────────────

function Camera.Start(eventsModule, consoleModule)
    if _started then return end
    _started = true

    if type(eventsModule) == "table"  then Events  = eventsModule  end
    if type(consoleModule) == "table" then Console = consoleModule end

    -- Maintain zoom on camera reset (game may reset CameraType)
    _camCn = RunService.RenderStepped:Connect(function()
        if _zoomLevel ~= 0 then
            pcall(function()
                local cam = workspace.CurrentCamera
                if cam and cam.FieldOfView ~= _getFOV(_zoomLevel) then
                    cam.FieldOfView = _getFOV(_zoomLevel)
                end
            end)
        end
        if _locked then _applyLock() end
    end)
end

return Camera
