--[[
    LX&80.lua  —  GrowBlox backend  v2.0.0
    ==========================================================
    Semua fitur memakai API asli game:
      Game table (gt) via getgc  ·  render upvalues via getconnections/debug
      Net (ByteNet) packets      ·  ItemDB  ·  ItemIcon  ·  TextChatService

    Kontrak UI: lihat daftar function LX.* di bagian bawah file.
]]

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TCS          = game:GetService("TextChatService")
local SoundService = game:GetService("SoundService")
local LP           = Players.LocalPlayer

local LX = {}
local S  = {
    godmode        = false,
    antiCheckpoint = false,
    fly            = false,
    flySpeed       = 24,
    zoom           = 1,
    zoomUnlock     = false,
    zoomMin        = 0.2,
    zoomMax        = 5,
    performance    = false,
    renderScale    = 0.75,
    loadingScale   = 0.5,
    spamRunning    = false,
    spamMsg        = "",
    spamDelay      = 1.5,
    spamRandom     = false,
    spamColor      = "w",
    pnbRunning     = false,
    pnbGrid        = {},
    pnbSeedId      = nil,
    pnbDelay       = 0.35,
    pnbAutoCollect = true,
    dfRunning      = false,
    dfDelay        = 0.4,
    clearRunning   = false,
    clearDelay     = 0.5,
    clearBg        = true,
    tpMethod       = 1,
    modWatchOn     = false,
    modAction      = "SLEEP",
    modLog         = {},
    modCount       = 0,
    antiDetect     = false,
    unlockAll      = false,
    voiceAll       = false,
    nametag        = nil,
    namedStyle     = "default",
    namedColor     = "w",
    instantSpin    = true,
    autoSpin       = false,
    spinDelay      = 2.5,
    spinX          = nil,
    spinY          = nil,
    loaded         = false,
    lastError      = nil,
}
LX.State = S
LX.Pos   = { x = 0, y = 0, tx = 0, ty = 0, hp = 5, maxHp = 5, dead = false, loaded = false }
LX.ChatStats = { sent = 0, failed = 0, last = "" }
LX.COLORS = {
    White = "w", Red = "4", Green = "2", Yellow = "9", Cyan = "e", Aqua = "c",
    Orange = "8", Pink = "#", Purple = "m", Blue = "q", Black = "b", Gray = "s",
}

local G = {
    gt = nil, render = nil, Net = nil, ItemDB = nil, Roles = nil, ItemIcon = nil,
    ready = false, ourStaffFrame = nil, connected = false,
    laserOrig = nil, dropOkOrig = nil, areasOrig = nil, areasStaffOrig = nil,
    clampInstalled = false, frameBound = false,
}

local origClamp = math.clamp
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function uv(fn, i)
    if not fn or type(debug) ~= "table" then return nil end
    local ok, value = pcall(function()
        local _, v = debug.getupvalue(fn, i)
        return v
    end)
    if ok then return value end
    return nil
end

local function suv(fn, i, value)
    if not fn or type(debug) ~= "table" then return false end
    return (pcall(function() return debug.setupvalue(fn, i, value) end))
end

local function isInstance(v, class)
    if type(v) ~= "userdata" then return false end
    local ok, res = pcall(function()
        return v:IsA(class)
    end)
    return ok and res == true
end

-- ══════════════════════════════════════════════════════════════
--  DISCOVERY
-- ══════════════════════════════════════════════════════════════
local function validGameTable(t)
    if type(t) ~= "table" then return false end
    local ok = pcall(function()
        return type(rawget(t, "goTo")) == "function"
            and type(rawget(t, "touchBlocks")) == "function"
            and type(rawget(t, "fg")) == "table"
            and type(rawget(t, "bg")) == "table"
            and type(rawget(t, "w")) == "number"
            and type(rawget(t, "h")) == "number"
            and type(rawget(t, "name")) == "string"
    end)
    return ok
end

local function findGameTable()
    if type(getgc) ~= "function" then return nil end
    local ok, gc = pcall(getgc, true)
    if not ok or type(gc) ~= "table" then return nil end
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" and validGameTable(v) then
            return v
        end
    end
    return nil
end

local function renderShape(fn, gt)
    if type(fn) ~= "function" then return false end
    if uv(fn, 1) ~= gt then return false end
    if uv(fn, 42) ~= 64 then return false end
    local x  = uv(fn, 20)
    local y  = uv(fn, 21)
    local z  = uv(fn, 44)
    local us = uv(fn, 41)
    if type(x) ~= "number" or type(y) ~= "number" then return false end
    if type(z) ~= "number" or not isInstance(us, "UIScale") then return false end
    return true
end

local function findRenderFn(gt)
    if type(gt) ~= "table" then return nil end
    if type(getconnections) == "function" then
        local ok, conns = pcall(getconnections, RunService.RenderStepped)
        if ok and type(conns) == "table" then
            for i = 1, #conns do
                local c = conns[i]
                local fn = nil
                if type(c) == "table" then
                    fn = c.Function or c["function"]
                end
                if type(fn) == "function" and renderShape(fn, gt) then
                    return fn
                end
            end
        end
    end
    if type(getgc) == "function" then
        local ok, gc = pcall(getgc, true)
        if ok and type(gc) == "table" then
            for i = 1, #gc do
                local fn = gc[i]
                if type(fn) == "function" and renderShape(fn, gt) then
                    return fn
                end
            end
        end
    end
    return nil
end

local function getShared()
    local s = RS:FindFirstChild("Shared")
    if not s then
        local ok, res = pcall(function() return RS:WaitForChild("Shared", 15) end)
        if ok then s = res end
    end
    return s
end

local function requireShared(name)
    local s = getShared()
    if not s then return nil end
    local m = s:FindFirstChild(name)
    if not m then return nil end
    local ok, res = pcall(require, m)
    if ok then return res end
    return nil
end

local function loadModules()
    if not G.Net then G.Net = requireShared("Net") end
    if not G.ItemDB then G.ItemDB = requireShared("ItemDB") end
    if not G.Roles then G.Roles = requireShared("Roles") end
    if not G.ItemIcon then G.ItemIcon = requireShared("ItemIcon") end
end

-- ══════════════════════════════════════════════════════════════
--  POSITION
-- ══════════════════════════════════════════════════════════════
local function readPos()
    local gt = G.gt
    local staffFresh = S._staffAt and (os.clock() - S._staffAt) < 0.75
    if G.render then
        local hp = uv(G.render, 38)
        if not staffFresh then
            local x = uv(G.render, 20)
            local y = uv(G.render, 21)
            if type(x) == "number" then LX.Pos.x = x end
            if type(y) == "number" then LX.Pos.y = y end
        end
        if type(hp) == "number" then LX.Pos.hp = hp end
        LX.Pos.dead = uv(G.render, 7) == true
    end
    LX.Pos.tx = math.floor(LX.Pos.x)
    LX.Pos.ty = math.floor(LX.Pos.y - 1)
    local maxHp = 5
    if gt and type(gt.maxHp) == "number" then maxHp = gt.maxHp end
    LX.Pos.maxHp = maxHp
    LX.Pos.loaded = gt ~= nil and gt.name ~= ""
    S.loaded = LX.Pos.loaded
    S._x = LX.Pos.x
    S._y = LX.Pos.y
end

-- Set exact world position. goTo() adds (+0.5, +1), so invert it for fallback.
local function setPos(px, py)
    local gt = G.gt
    if G.render then
        suv(G.render, 20, px)
        suv(G.render, 21, py)
        suv(G.render, 17, 0)
        suv(G.render, 18, 0)
        suv(G.render, 23, px)
        suv(G.render, 24, py)
        if gt then
            gt.stuckAt = nil
            gt.portalGo = nil
        end
    elseif gt and type(gt.goTo) == "function" then
        pcall(gt.goTo, px - 0.5, py - 1)
    end
    LX.Pos.x = px
    LX.Pos.y = py
    LX.Pos.tx = math.floor(px)
    LX.Pos.ty = math.floor(py - 1)
    S._x = px
    S._y = py
end

local function sendMove()
    local gt, net = G.gt, G.Net
    if not gt or not net or not net.move then return end
    if gt.name == "" then return end
    pcall(function()
        net.move.send({
            x = LX.Pos.x, y = LX.Pos.y, vx = 0, vy = 0, flags = 2,
            t = math.floor((os.clock() * 1000) % 65535),
        })
    end)
end

-- Authoritative one-shot move: gt.goTo() is the same function the game uses
-- for spawn/home/door teleports, so it updates the real position variables.
-- (Not used per-frame because goTo rewrites portalIn and could retrigger doors.)
local function teleportTo(px, py)
    local gt = G.gt
    if gt and type(gt.goTo) == "function" then
        pcall(gt.goTo, px - 0.5, py - 1)
    end
    setPos(px, py)
    sendMove()
end

-- ══════════════════════════════════════════════════════════════
--  CHAT
-- ══════════════════════════════════════════════════════════════
local function getWorldChannel()
    local wc = TCS:FindFirstChild("WorldChannels")
    if not wc then return nil end
    local worldName = G.gt and G.gt.name or ""
    if worldName ~= "" then
        local exact = wc:FindFirstChild(worldName)
        if exact then return exact end
    end
    for _, c in ipairs(wc:GetChildren()) do
        if c:IsA("TextChannel") then return c end
    end
    return nil
end

function LX.SendChat(text)
    if type(text) ~= "string" or text == "" then return false, "empty message" end
    if #text > 120 then text = string.sub(text, 1, 120) end
    local ch = getWorldChannel()
    if not ch then
        LX.ChatStats.failed = LX.ChatStats.failed + 1
        LX.ChatStats.last = "world channel belum ada (masuk world dulu)"
        return false, LX.ChatStats.last
    end
    local ok, err = pcall(function() ch:SendAsync(text) end)
    if ok then
        LX.ChatStats.sent = LX.ChatStats.sent + 1
        LX.ChatStats.last = "sent"
    else
        LX.ChatStats.failed = LX.ChatStats.failed + 1
        LX.ChatStats.last = tostring(err)
    end
    return ok, err
end

local function buildSpamText()
    local msg = S.spamMsg or ""
    if msg == "" then return "" end
    local body = msg
    if S.spamRandom then
        body = "[" .. math.random(1, 99) .. "] " .. body
    end
    local code = S.spamColor or "w"
    return "`" .. code .. body .. "``"
end

function LX.Spam_Start(msg, delay, randomPrefix, colorCode)
    if type(msg) == "string" and msg ~= "" then S.spamMsg = msg end
    if type(delay) == "number" then S.spamDelay = math.max(0.8, delay) end
    if randomPrefix ~= nil then S.spamRandom = randomPrefix == true end
    if type(colorCode) == "string" and colorCode ~= "" then S.spamColor = colorCode end
    if S.spamMsg == "" then return false, "message kosong" end
    if S.spamRunning then return true end
    S.spamRunning = true
    task.spawn(function()
        while S.spamRunning do
            local text = buildSpamText()
            if text == "" then break end
            local ok = LX.SendChat(text)
            if not ok and S.antiDetect then
                task.wait(0.75)
            end
            local jitter = 0
            if S.antiDetect then jitter = math.random() * 0.35 end
            task.wait(math.max(0.8, S.spamDelay) + jitter)
        end
        S.spamRunning = false
    end)
    return true
end

function LX.Spam_Stop()
    S.spamRunning = false
end

-- ══════════════════════════════════════════════════════════════
--  GODMODE / HAZARDS
-- ══════════════════════════════════════════════════════════════
local hazardBackup = {}

local function stripHazards()
    local db = G.ItemDB
    if not db then return end
    for id, e in pairs(db) do
        if type(e) == "table" and (e.hurts or e.deadly) then
            if hazardBackup[id] == nil then
                hazardBackup[id] = { hurts = e.hurts, deadly = e.deadly }
            end
            e.hurts = nil
            e.deadly = nil
        end
    end
end

local function restoreHazards()
    local db = G.ItemDB
    if not db then return end
    for id, saved in pairs(hazardBackup) do
        local e = db[id]
        if type(e) == "table" then
            e.hurts = saved.hurts
            e.deadly = saved.deadly
        end
    end
    hazardBackup = {}
end

local function wrapLaser()
    local gt = G.gt
    if not gt or type(gt.laserAt) ~= "function" then return end
    if G.laserOrig then
        gt.laserAt = function(...)
            if S.godmode then return nil, nil end
            return G.laserOrig(...)
        end
        return
    end
    G.laserOrig = gt.laserAt
    gt.laserAt = function(...)
        if S.godmode then return nil, nil end
        return G.laserOrig(...)
    end
end

function LX.Godmode_On()
    S.godmode = true
    loadModules()
    stripHazards()
    wrapLaser()
    readPos()
    LX.Pos.hp = LX.Pos.maxHp
    if G.render then suv(G.render, 38, 5) end
end

function LX.Godmode_Off()
    S.godmode = false
    restoreHazards()
end

function LX.AntiCheckpoint_On()
    S.antiCheckpoint = true
    local gt = G.gt
    if gt and gt.checkpoint ~= nil then
        if S._cpBackup == nil then S._cpBackup = gt.checkpoint end
        gt.checkpoint = nil
    end
end

function LX.AntiCheckpoint_Off()
    S.antiCheckpoint = false
    if G.gt and S._cpBackup ~= nil then
        G.gt.checkpoint = S._cpBackup
        S._cpBackup = nil
    end
end

-- ══════════════════════════════════════════════════════════════
--  FLY / TELEPORT
-- ══════════════════════════════════════════════════════════════
function LX.Fly_On(speed)
    if type(speed) == "number" then S.flySpeed = speed end
    S.fly = true
    if G.render then suv(G.render, 18, 0) end
end

function LX.Fly_Off()
    S.fly = false
end

function LX.SetFlySpeed(v)
    if type(v) == "number" then S.flySpeed = math.max(1, v) end
end

function LX.Teleport(tx, ty, method)
    if type(tx) ~= "number" or type(ty) ~= "number" then return false, "koordinat invalid" end
    tx, ty = math.floor(tx), math.floor(ty)
    local gt = G.gt
    if gt then
        if type(gt.w) == "number" and gt.w > 0 then tx = clamp(tx, 0, gt.w - 1) end
        if type(gt.h) == "number" and gt.h > 0 then ty = clamp(ty, 0, gt.h - 1) end
    end
    local px, py = tx + 0.5, ty + 1
    local m = method or S.tpMethod or 1
    if m == 2 then
        local sx, sy = LX.Pos.x, LX.Pos.y
        for i = 1, 3 do
            local a = i / 3
            setPos(sx + (px - sx) * a, sy + (py - sy) * a)
            task.wait(0.06)
        end
    end
    teleportTo(px, py)
    return true, tx, ty
end

function LX.TeleportWorld(px, py, method)
    if type(px) ~= "number" or type(py) ~= "number" then return false, "koordinat invalid" end
    teleportTo(px, py)
    return true
end

function LX.TeleportToPlayer(userId)
    local eid = S.userEntity and S.userEntity[userId]
    local e = eid and S.entities and S.entities[eid]
    if not e or not e.seen or type(e.x) ~= "number" or type(e.y) ~= "number" then
        return false, "posisi player belum diketahui"
    end
    local tx = math.floor(e.x)
    local ty = math.floor(e.y - 1)
    teleportTo(tx + 0.5, ty + 1)
    return true, tx, ty
end

function LX.GetPlayerList()
    local out = {}
    for _, e in pairs(S.entities or {}) do
        if e.userId ~= LP.UserId then
            out[#out + 1] = {
                userId = e.userId, name = e.name or "?",
                x = e.x, y = e.y, seen = e.seen == true,
            }
        end
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end

-- ══════════════════════════════════════════════════════════════
--  ZOOM / RENDER SCALE
-- ══════════════════════════════════════════════════════════════
-- The game caps zoom only inside its own MouseWheel/TouchPinch handlers
-- (clamp(.., zoomMin or 0.6, 1.6)) and sizes the tile pool from gt.zoomMin;
-- changing the ModZoom attribute makes it rebuild that pool (buildPool).
local function rebuildTilePool()
    G.modZoomTick = (G.modZoomTick or 0) + 1
    pcall(function() LP:SetAttribute("ModZoom", G.modZoomTick) end)
end

local function syncZoomMin()
    local gt = G.gt
    if not gt then return end
    if S._zoomWorld ~= gt.name then
        S._zoomWorld = gt.name
        if gt.zoomMin ~= S._zoomApplied then S._zoomMinBackup = gt.zoomMin end
    end
    if gt.zoomMin ~= S.zoomMin then
        gt.zoomMin = S.zoomMin
        S._zoomApplied = S.zoomMin
        rebuildTilePool()
    end
end

local function restoreZoomMin()
    local gt = G.gt
    if gt and S._zoomApplied ~= nil and gt.zoomMin == S._zoomApplied then
        gt.zoomMin = S._zoomMinBackup
    end
    S._zoomWorld = nil
    S._zoomMinBackup = nil
    S._zoomApplied = nil
    if G.modZoomTick then
        G.modZoomTick = nil
        pcall(function() LP:SetAttribute("ModZoom", G.modZoomOrig) end)
    end
end

local function zoomBounds()
    if S.zoomUnlock then return S.zoomMin, S.zoomMax end
    return (G.gt and G.gt.zoomMin) or 0.6, 1.6
end

local function installZoomInput()
    if G.zoomInput then return end
    G.zoomInput = true
    G.modZoomOrig = LP:GetAttribute("ModZoom")
    UIS.InputChanged:Connect(function(input, processed)
        if not S.zoomUnlock or processed then return end
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            LX.SetZoom((S.zoom or 1) * 1.12 ^ input.Position.Z)
        end
    end)
    local pinchBase = nil
    UIS.TouchPinch:Connect(function(_, scale, _, state, processed)
        if not S.zoomUnlock then return end
        if state == Enum.UserInputState.Begin then
            pinchBase = (not processed) and (S.zoom or 1) or nil
        end
        if pinchBase and type(scale) == "number" then
            LX.SetZoom(pinchBase * scale)
        end
        if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
            pinchBase = nil
        end
    end)
end

local function getUIScale()
    if G.render then
        local s = uv(G.render, 41)
        if isInstance(s, "UIScale") then return s end
    end
    local pg = LP:FindFirstChild("PlayerGui")
    local gg = pg and pg:FindFirstChild("GameGui")
    local world = gg and gg:FindFirstChild("World")
    local cam = world and world:FindFirstChild("Camera")
    if cam then
        local s = cam:FindFirstChildOfClass("UIScale")
        if s then return s end
    end
    return nil
end

local function applyScale(scale)
    if type(scale) ~= "number" or scale <= 0.05 then return end
    local s = getUIScale()
    if s then pcall(function() s.Scale = scale end) end
    if G.render then
        suv(G.render, 40, scale)
        suv(G.render, 44, scale)
        local worldFrame = uv(G.render, 6)
        if isInstance(worldFrame, "GuiObject") then
            local size = worldFrame.AbsoluteSize
            suv(G.render, 43, Vector2.new(size.X / scale, size.Y / scale))
        end
    end
end

function LX.SetZoom(z)
    if type(z) ~= "number" then return end
    local lo, hi = zoomBounds()
    z = clamp(z, lo, hi)
    S.zoom = z
    if G.render then suv(G.render, 44, z) end
end

function LX.ZoomIn(factor)
    local cur = S.zoom or 1
    if G.render then
        local t = uv(G.render, 44)
        if type(t) == "number" then cur = t end
    end
    LX.SetZoom(cur * (factor or 1.15))
end

function LX.ZoomOut(factor)
    local cur = S.zoom or 1
    if G.render then
        local t = uv(G.render, 44)
        if type(t) == "number" then cur = t end
    end
    LX.SetZoom(cur / (factor or 1.15))
end

function LX.SetZoomLimits(lo, hi)
    if type(lo) == "number" then S.zoomMin = clamp(lo, 0.05, 1.5) end
    if type(hi) == "number" then S.zoomMax = clamp(hi, 1.6, 200) end
    if S.zoomMax < S.zoomMin then S.zoomMax = S.zoomMin end
    if S.zoomUnlock then
        syncZoomMin()
        LX.SetZoom(S.zoom or 1)
    end
end

function LX.ZoomUnlock_On()
    installZoomInput()
    if G.render then
        local cur = uv(G.render, 44)
        if type(cur) == "number" then S.zoom = cur end
    end
    S.zoomUnlock = true
    syncZoomMin()
end

function LX.ZoomUnlock_Off()
    S.zoomUnlock = false
    restoreZoomMin()
    LX.SetZoom(S.zoom or 1)
end

function LX.Performance_On()
    if S.performance then return end
    S.performance = true
    local gt = G.gt
    if gt then
        S._perfBackup = {
            lowGfx = gt.lowGfx,
            lowRange = gt.LOW_RANGE,
            zoom = G.render and uv(G.render, 40) or nil,
            target = G.render and uv(G.render, 44) or nil,
            scale = getUIScale() and getUIScale().Scale or nil,
        }
        gt.lowGfx = true
        gt.LOW_RANGE = math.min(tonumber(gt.LOW_RANGE) or 1e6, 48)
    end
    applyScale(S.renderScale)
end

function LX.Performance_Off()
    S.performance = false
    local gt = G.gt
    if gt and S._perfBackup then
        gt.lowGfx = S._perfBackup.lowGfx
        gt.LOW_RANGE = S._perfBackup.lowRange
        local target = S._perfBackup.target or S._perfBackup.zoom
        if type(target) == "number" then
            applyScale(target)
            if G.render then suv(G.render, 40, S._perfBackup.zoom or target) end
        end
        S._perfBackup = nil
    end
end

function LX.SetRenderScale(v)
    if type(v) == "number" then
        S.renderScale = clamp(v, 0.25, 2)
        if S.performance then applyScale(S.renderScale) end
    end
end

function LX.SetLoadingScale(v)
    if type(v) == "number" then S.loadingScale = clamp(v, 0.2, 1.5) end
end

-- ══════════════════════════════════════════════════════════════
--  FARMING HELPERS
-- ══════════════════════════════════════════════════════════════
local lastTileSend = 0
local function sendTile(layer, x, y, id)
    local net = G.Net
    if not net or not net.tile then return false end
    if S.antiDetect then
        local now = os.clock()
        local gap = now - lastTileSend
        if gap < 0.09 then
            task.wait(0.09 - gap)
        end
        lastTileSend = os.clock()
    end
    local ok = pcall(function()
        net.tile.send({ layer = layer, x = math.floor(x), y = math.floor(y), id = math.floor(id), flip = false })
    end)
    return ok
end

local function itemName(id)
    local e = G.ItemDB and G.ItemDB[id]
    return e and e.name or ""
end

local function isProtected(id, e)
    if id == 0 then return true end
    e = e or (G.ItemDB and G.ItemDB[id])
    if not e then return true end
    local n = string.lower(e.name or "")
    if n == "blank" then return true end
    if string.find(n, "door", 1, true) then return true end
    if string.find(n, "bedrock", 1, true) then return true end
    if string.find(n, "white", 1, true) then return true end
    if e.lock or e.area or e.entrance or e.vip or e.combiner or e.display then return true end
    return false
end

local function collectDrops(maxCount)
    local gt = G.gt
    if not gt or type(gt.dropList) ~= "function" then return 0 end
    local ok, drops = pcall(gt.dropList)
    if not ok or type(drops) ~= "table" then return 0 end
    local copy = {}
    for i = 1, #drops do copy[i] = drops[i] end
    local taken = 0
    for _, d in ipairs(copy) do
        if taken >= (maxCount or 8) then break end
        if type(d) == "table" and d.uid and d.x and d.y then
            setPos(d.x, d.y + 0.35)
            task.wait(0.03)
            local ok2, got = pcall(function() return gt.takeDrop(d.uid, d.n or 1) end)
            if ok2 and got ~= nil then taken = taken + 1 end
        end
    end
    return taken
end

local function farmTile(tx, ty, seedId)
    local gt = G.gt
    if not gt then return false end
    if tx < 0 or tx >= gt.w or ty < 0 or ty >= gt.h then return false end
    setPos(tx + 0.5, ty + 1)
    task.wait(0.06)
    local row = gt.fg and gt.fg[ty]
    local id = row and row[tx] or 0
    local e = G.ItemDB and G.ItemDB[id]
    local broke = false
    if id ~= 0 and e then
        if e.kind == "seed" then
            if e.provider then
                pcall(function() G.Net.harvest.send({ x = tx, y = ty }) end)
            else
                sendTile(1, tx, ty, 0)
            end
            broke = true
        elseif e.solid or e.hits then
            sendTile(1, tx, ty, 0)
            broke = true
        elseif e.spin or e.dice then
            if S.instantSpin then
                pcall(function() G.Net.spin.send({ x = tx, y = ty }) end)
            end
        end
    end
    if (id == 0 or broke) and seedId and seedId > 0 then
        if broke then task.wait(0.15) end
        sendTile(1, tx, ty, seedId)
    end
    return true
end

function LX.PNB_SetBase()
    readPos()
    S.pnbBase = { x = math.floor(LX.Pos.x), y = math.floor(LX.Pos.y - 1) }
    return S.pnbBase
end

local function gridCellOffset(r, c)
    return c - 3, 3 - r
end

function LX.PNB_Start(seedId, delay)
    if type(seedId) == "number" and seedId > 0 then S.pnbSeedId = seedId end
    if type(delay) == "number" then S.pnbDelay = math.max(0.12, delay) end
    if S.pnbRunning then return true end
    if not G.gt then return false, "game belum siap" end
    local base = S.pnbBase
    if not base then base = LX.PNB_SetBase() end
    S.pnbRunning = true
    task.spawn(function()
        while S.pnbRunning do
            local gt = G.gt
            if not gt then task.wait(0.5) else
                for r = 1, 5 do
                    for c = 1, 5 do
                        if not S.pnbRunning then break end
                        local row = S.pnbGrid and S.pnbGrid[r]
                        local on = row and row[c]
                        if on and not (r == 3 and c == 3) then
                            local dx, dy = gridCellOffset(r, c)
                            farmTile(base.x + dx, base.y + dy, S.pnbSeedId)
                            if S.antiDetect then task.wait(math.random() * 0.12) end
                        end
                    end
                end
                if S.pnbAutoCollect then collectDrops(6) end
                task.wait(math.max(0.12, S.pnbDelay))
            end
        end
        S.pnbRunning = false
    end)
    return true
end

function LX.PNB_Stop()
    S.pnbRunning = false
end

function LX.DF_Start(delay)
    if type(delay) == "number" then S.dfDelay = math.max(0.15, delay) end
    if S.dfRunning then return true end
    S.dfRunning = true
    task.spawn(function()
        while S.dfRunning do
            collectDrops(10)
            task.wait(math.max(0.15, S.dfDelay))
        end
        S.dfRunning = false
    end)
    return true
end

function LX.DF_Stop()
    S.dfRunning = false
end

function LX.Clear_Start(delay)
    if type(delay) == "number" then S.clearDelay = math.max(0.08, delay) end
    if S.clearRunning then return true end
    local gt = G.gt
    if not gt then return false, "game belum siap" end
    S.clearRunning = true
    task.spawn(function()
        local w, h = gt.w, gt.h
        for y = 0, h - 1 do
            if not S.clearRunning then break end
            for x = 0, w - 1 do
                if not S.clearRunning then break end
                local fgId = gt.fg[y] and gt.fg[y][x] or 0
                if fgId ~= 0 and not isProtected(fgId) then
                    sendTile(1, x, y, 0)
                    if S.antiDetect then task.wait(math.random() * 0.03) end
                end
                if S.clearBg then
                    local bgId = gt.bg[y] and gt.bg[y][x] or 0
                    if bgId ~= 0 and not isProtected(bgId) then
                        sendTile(2, x, y, 0)
                    end
                end
                task.wait(S.clearDelay)
            end
        end
        S.clearRunning = false
    end)
    return true
end

function LX.Clear_Stop()
    S.clearRunning = false
end

-- ══════════════════════════════════════════════════════════════
--  ROULETTE / DICE
-- ══════════════════════════════════════════════════════════════
local spinHandlers = {}
local rollBackup = {}

function LX.FastSpin_SetInstant(on)
    S.instantSpin = on == true
    local db = G.ItemDB
    if not db then return end
    for id, e in pairs(db) do
        if type(e) == "table" and (e.spin or e.dice) then
            if rollBackup[id] == nil then
                rollBackup[id] = e.rollTime or 2.2
            end
            if S.instantSpin then
                e.rollTime = 0
            else
                e.rollTime = rollBackup[id]
            end
        end
    end
end

function LX.FindSpin()
    local gt = G.gt
    if not gt then return nil end
    local db = G.ItemDB
    if not db then return nil end
    local best = nil
    for y = 0, gt.h - 1 do
        local row = gt.fg[y]
        if row then
            for x = 0, gt.w - 1 do
                local id = row[x]
                local e = id and db[id]
                if e and (e.spin or e.dice) then
                    local dx = x - LX.Pos.x
                    local dy = y - (LX.Pos.y - 1)
                    local d = dx * dx + dy * dy
                    if not best or d < best.d then
                        best = { x = x, y = y, id = id, name = e.name, d = d }
                    end
                end
            end
        end
    end
    return best
end

function LX.FastSpin_Once(x, y)
    if not G.gt then return false, "game belum siap" end
    if not G.Net or not G.Net.spin then return false, "Net.spin tidak ada" end
    if not x or not y then
        local w = LX.FindSpin()
        if not w then return false, "tidak ada roulette/dice di world ini" end
        x, y = w.x, w.y
    end
    x, y = math.floor(x), math.floor(y)
    if S.instantSpin then LX.FastSpin_SetInstant(true) end
    local ok = pcall(function() G.Net.spin.send({ x = x, y = y }) end)
    if ok then
        S.spinX, S.spinY = x, y
        return true, x, y
    end
    return false, "spin packet gagal"
end

function LX.FastSpin_HookResults(cb)
    if type(cb) ~= "function" then return function() end end
    spinHandlers[#spinHandlers + 1] = cb
    local idx = #spinHandlers
    return function()
        spinHandlers[idx] = nil
    end
end

function LX.AutoSpin_Start(x, y)
    S.spinX, S.spinY = x, y
    if S.autoSpin then return true end
    S.autoSpin = true
    task.spawn(function()
        while S.autoSpin do
            local sx, sy = S.spinX, S.spinY
            if not sx or not sy then
                local w = LX.FindSpin()
                if w then sx, sy = w.x, w.y end
            end
            if sx and sy then
                LX.FastSpin_Once(sx, sy)
            end
            task.wait(math.max(1, S.spinDelay))
        end
        S.autoSpin = false
    end)
    return true
end

function LX.AutoSpin_Stop()
    S.autoSpin = false
end

-- ══════════════════════════════════════════════════════════════
--  MOD WATCH
-- ══════════════════════════════════════════════════════════════
local watched = {}
local checkStaff

local function addModLog(p, role)
    local entry = {
        time = os.date("%H:%M:%S"),
        name = p.Name,
        role = role or "staff",
        userId = p.UserId,
    }
    table.insert(S.modLog, 1, entry)
    while #S.modLog > 50 do table.remove(S.modLog) end
    S.modCount = S.modCount + 1
    if S.onMod then pcall(S.onMod, entry) end
end

local function runModAction()
    local action = S.modAction or "SLEEP"
    if action == "SLEEP" then
        LX.PNB_Stop()
        LX.DF_Stop()
        LX.Clear_Stop()
        LX.Spam_Stop()
        LX.AutoSpin_Stop()
        LX.Fly_Off()
    elseif action == "LEAVE" then
        local gt = G.gt
        local done = false
        if gt and type(gt.call) == "function" then
            done = pcall(function() gt.call("LeaveWorld") end)
        end
        if not done then
            pcall(function()
                game:GetService("TeleportService"):Teleport(game.PlaceId)
            end)
        end
    elseif action == "FLY_OFF" then
        LX.Fly_Off()
    end
end

checkStaff = function(p)
    if not p or p == LP then return end
    local tag = p:GetAttribute("Tag")
    if type(tag) == "string" and tag ~= "" then
        if not watched[p.UserId] then
            watched[p.UserId] = true
            addModLog(p, tag)
            runModAction()
        end
    else
        watched[p.UserId] = nil
    end
end

local watchConns = {}

local function watchPlayer(p)
    if not p then return end
    checkStaff(p)
    if not watchConns[p.UserId] then
        watchConns[p.UserId] = p.AttributeChanged:Connect(function(attr)
            if attr == "Tag" then checkStaff(p) end
        end)
    end
end

function LX.ModWatch_On(action, callback)
    S.modWatchOn = true
    if action then S.modAction = action end
    if type(callback) == "function" then S.onMod = callback end
    for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
    if not S._modConns then
        S._modConns = true
        Players.PlayerAdded:Connect(function(p)
            if S.modWatchOn then watchPlayer(p) end
        end)
        Players.PlayerRemoving:Connect(function(p)
            watched[p.UserId] = nil
        end)
    end
    if not S._modPolling then
        S._modPolling = true
        task.spawn(function()
            while S._modPolling do
                if S.modWatchOn then
                    for _, p in ipairs(Players:GetPlayers()) do checkStaff(p) end
                end
                task.wait(3)
            end
        end)
    end
end

function LX.ModWatch_Off()
    S.modWatchOn = false
end

-- ══════════════════════════════════════════════════════════════
--  NAMETAG
-- ══════════════════════════════════════════════════════════════
function LX.SetNametag(text, style, colorCode)
    if type(text) ~= "string" or text == "" then return false end
    S.nametag = text
    S.namedStyle = style or "default"
    if type(colorCode) == "string" and colorCode ~= "" then S.namedColor = colorCode end
    if S._nameBackup == nil then
        S._nameBackup = { nick = LP:GetAttribute("Nick"), game = LP:GetAttribute("GameName") }
    end
    local display = text
    if S.namedStyle ~= "plain" then
        display = "`" .. (S.namedColor or "w") .. text .. "``"
    end
    LP:SetAttribute("Nick", display)
    return true
end

function LX.RemoveNametag()
    S.nametag = nil
    if S._nameBackup then
        LP:SetAttribute("Nick", S._nameBackup.nick)
        LP:SetAttribute("GameName", S._nameBackup.game)
        S._nameBackup = nil
    else
        LP:SetAttribute("Nick", nil)
    end
end

function LX.WearVisual(tbl)
    if type(tbl) ~= "table" or not G.Net or not G.Net.wear then return false end
    return pcall(function() G.Net.wear.send(tbl) end)
end

-- ══════════════════════════════════════════════════════════════
--  VOICE ALL
-- ══════════════════════════════════════════════════════════════
function LX.VoiceAll_On()
    S.voiceAll = true
end

function LX.VoiceAll_Off()
    S.voiceAll = false
end

local function forceVoice()
    local folder = SoundService:FindFirstChild("ProximityVoice")
    if not folder then return end
    for _, c in ipairs(folder:GetChildren()) do
        if isInstance(c, "AudioFader") then
            pcall(function()
                if c.Volume < 1 then c.Volume = 1 end
            end)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  ANNOUNCE (MEGAPHONE / CROSS-WORLD)
-- ══════════════════════════════════════════════════════════════
function LX.AnnounceAll(text)
    if type(text) ~= "string" or text:match("^%s*$") then return false, "message kosong" end
    if not G.Net or not G.gt then return false, "game belum siap" end
    if S.announceBusy then return false, "masih mengirim" end
    S.announceBusy = true
    task.spawn(function()
        local ok, res, reason = pcall(function() return G.Net.call("Broadcast", text) end)
        S.announceBusy = false
        local success = ok and res ~= nil and res ~= false
        local err = nil
        if not ok then
            err = tostring(res)
        elseif not success then
            err = tostring(reason or "server menolak (butuh item Megaphone)")
        end
        S.lastAnnounce = { ok = success, text = text, error = err, at = os.time() }
        if S.onAnnounce then pcall(S.onAnnounce, success, err) end
    end)
    return true
end

-- ══════════════════════════════════════════════════════════════
--  ANTI DETECT / UNLOCK
-- ══════════════════════════════════════════════════════════════
function LX.AntiDetect_On()
    S.antiDetect = true
    if S.spamDelay < 1.2 then S.spamDelay = 1.2 end
    if S.pnbDelay < 0.2 then S.pnbDelay = 0.2 end
    LX.ModWatch_On(S.modAction, S.onMod)
end

function LX.AntiDetect_Off()
    S.antiDetect = false
end

function LX.UnlockAll_On()
    S.unlockAll = true
    loadModules()
    local gt = G.gt
    if gt then
        if type(gt.dropOk) == "function" and not G.dropOkOrig then
            G.dropOkOrig = gt.dropOk
            gt.dropOk = function() return true end
        end
        if type(gt.areas) == "table" then
            G.areasOrig = G.areasOrig or {}
            for _, key in ipairs({ "canEdit", "mayBuild", "canBuild" }) do
                if type(gt.areas[key]) == "function" and not G.areasOrig[key] then
                    G.areasOrig[key] = gt.areas[key]
                    gt.areas[key] = function() return true end
                end
            end
            if G.areasStaffOrig == nil and gt.areas.staff ~= nil then
                G.areasStaffOrig = gt.areas.staff
                gt.areas.staff = true
            end
        end
    end
    if S._levelBackup == nil then
        S._levelBackup = { level = LP:GetAttribute("Level"), splvl = LP:GetAttribute("PlayerLevel") }
    end
    LP:SetAttribute("Level", 100)
    LP:SetAttribute("PlayerLevel", 100)
    return true
end

function LX.UnlockAll_Off()
    S.unlockAll = false
    local gt = G.gt
    if gt and G.dropOkOrig then
        gt.dropOk = G.dropOkOrig
        G.dropOkOrig = nil
    end
    if gt and type(gt.areas) == "table" then
        for key, fn in pairs(G.areasOrig or {}) do
            gt.areas[key] = fn
        end
        G.areasOrig = {}
        if G.areasStaffOrig ~= nil then
            gt.areas.staff = G.areasStaffOrig
            G.areasStaffOrig = nil
        end
    end
    if S._levelBackup then
        LP:SetAttribute("Level", S._levelBackup.level)
        LP:SetAttribute("PlayerLevel", S._levelBackup.splvl)
        S._levelBackup = nil
    end
end

function LX.TryDrop(id, tx, ty, count)
    if not G.Net or not G.Net.drop then return false, "Net.drop tidak ada" end
    if type(id) ~= "number" then return false, "id invalid" end
    local x = tx or math.floor(LX.Pos.x)
    local y = ty or math.floor(LX.Pos.y - 1)
    local n = count or 1
    return pcall(function()
        G.Net.drop.send({ id = id, n = n, x = math.floor(x), y = math.floor(y) })
    end)
end

-- ══════════════════════════════════════════════════════════════
--  ITEM DATABASE
-- ══════════════════════════════════════════════════════════════
function LX.GetItemDB()
    loadModules()
    return G.ItemDB or {}
end

function LX.GetItemInfo(id)
    local db = LX.GetItemDB()
    local e = db[id]
    if type(e) ~= "table" then return nil end
    return {
        id = id,
        name = e.name or ("Item " .. tostring(id)),
        desc = e.desc or "",
        rarity = e.rarity,
        kind = e.kind or (e.seed and "seed") or (e.spin and "roulette") or (e.dice and "dice") or "",
        solid = e.solid, seed = e.seed, atlas = e.atlas,
        entry = e,
    }
end

function LX.SearchItems(query, maxResults)
    local db = LX.GetItemDB()
    local q = string.lower(tostring(query or ""))
    local out = {}
    for id, e in pairs(db) do
        if type(id) == "number" and type(e) == "table" and type(e.name) == "string" then
            if e.name ~= "" and not e.hidden then
                local match = q == "" or tostring(id) == q or string.find(string.lower(e.name), q, 1, true) ~= nil
                if match then
                    out[#out + 1] = {
                        id = id,
                        name = e.name,
                        desc = e.desc or "",
                        rarity = e.rarity,
                        kind = e.kind or (e.seed and "seed") or "",
                    }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)
    if type(maxResults) == "number" and #out > maxResults then
        local trimmed = {}
        for i = 1, maxResults do trimmed[i] = out[i] end
        return trimmed
    end
    return out
end

function LX.MakeItemIcon(parent, sizePx, zIndex)
    loadModules()
    if not G.ItemIcon then return nil end
    local ok, icon = pcall(function()
        return G.ItemIcon.new(parent, UDim2.fromOffset(sizePx, sizePx), zIndex or 5)
    end)
    if ok then return icon end
    return nil
end

function LX.SetItemIcon(icon, id)
    if not icon or not G.ItemIcon then return false end
    return pcall(function() G.ItemIcon.set(icon, id) end)
end

-- ══════════════════════════════════════════════════════════════
--  NET EVENT TRACKING
-- ══════════════════════════════════════════════════════════════
local function worldTag()
    local net = G.Net
    local gt = G.gt
    if net and type(net.worldTag) == "function" and gt then
        return net.worldTag(gt.name or "")
    end
    return nil
end

local function connectNet()
    local net = G.Net
    if not net or G.connected then return end
    G.connected = true
    S.entities = S.entities or {}
    S.userEntity = S.userEntity or {}

    if net.entered then
        net.entered.listen(function(p)
            if type(p) ~= "table" or not p.id then return end
            local e = { id = p.id, userId = p.userId, name = p.name, x = 0, y = 0, seen = false }
            S.entities[p.id] = e
            if p.userId then S.userEntity[p.userId] = p.id end
            local plr = p.userId and Players:GetPlayerByUserId(p.userId)
            if plr then watchPlayer(plr) end
        end)
    end

    if net.moved then
        net.moved.listen(function(p)
            if type(p) ~= "table" or not p.id then return end
            local e = S.entities[p.id]
            if not e then
                e = { id = p.id }
                S.entities[p.id] = e
            end
            e.x, e.y = p.x, p.y
            e.seen = true
        end)
    end

    if net.left then
        net.left.listen(function(id)
            if type(id) ~= "number" then return end
            local e = S.entities[id]
            if e then
                if e.userId and S.userEntity[e.userId] == id then
                    S.userEntity[e.userId] = nil
                end
                S.entities[id] = nil
            end
        end)
    end

    if type(net.on) == "function" then
        pcall(function()
            net.on("WheelSpun", function(x, y, n, name, userId)
                S.lastSpin = { x = x, y = y, n = n, name = name, userId = userId, at = os.clock() }
                for _, cb in pairs(spinHandlers) do
                    pcall(cb, x, y, n, name, userId)
                end
            end, function()
                return G.gt and G.gt.name or ""
            end)
        end)
    end

    if TCS then
        pcall(function()
            TCS.MessageReceived:Connect(function(msg)
                local src = msg.TextSource
                if src and src.UserId == LP.UserId then
                    LX.ChatStats.last = "delivered"
                end
            end)
        end)
    end
end

-- ══════════════════════════════════════════════════════════════
--  MAIN FRAME
-- ══════════════════════════════════════════════════════════════
local frameAcc = 0
local function onFrame(dt)
    if not G.gt then return end
    readPos()
    frameAcc = frameAcc + dt

    if S.godmode and G.render then
        suv(G.render, 38, 5)
        suv(G.render, 37, os.clock())
        if uv(G.render, 7) == true then
            local respawn = uv(G.render, 8)
            if type(respawn) == "function" then pcall(respawn) end
        end
        LX.Pos.hp = 5
    end

    if S.fly then
        local gt = G.gt
        local speed = math.max(1, S.flySpeed or 24)
        local dx, dy = 0, 0
        if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then dx = dx - 1 end
        if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then dx = dx + 1 end
        if UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Space) then dy = dy + 1 end
        if UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dy = dy - 1 end
        local norm = (dx ~= 0 and dy ~= 0) and 0.70710678 or 1
        local maxX = (gt and gt.w or 100000) - 0.4
        local maxY = (gt and gt.h or 100000)
        local px = clamp((S._x or LX.Pos.x) + dx * speed * dt * norm, 0.4, math.max(0.5, maxX))
        local py = clamp((S._y or LX.Pos.y) + dy * speed * dt * norm, 0.95, math.max(1, maxY))
        setPos(px, py)
        if G.render then
            suv(G.render, 22, true)
            suv(G.render, 17, 0)
            suv(G.render, 18, 0)
        end
        if frameAcc > 0.25 then
            frameAcc = 0
            if not S._flySent or os.clock() - S._flySent > 0.2 then
                S._flySent = os.clock()
                sendMove()
            end
        end
    end

    if S.performance then
        applyScale(S.renderScale)
        if G.gt then
            G.gt.lowGfx = true
            if tonumber(G.gt.LOW_RANGE) and G.gt.LOW_RANGE > 48 then G.gt.LOW_RANGE = 48 end
        end
        S._forced = true
    elseif not S.loaded then
        applyScale(S.loadingScale)
        S._forced = true
    elseif S._forced then
        S._forced = false
        applyScale(S.zoom or 1)
    elseif S.zoomUnlock then
        syncZoomMin()
        if G.render and uv(G.render, 44) ~= S.zoom then suv(G.render, 44, S.zoom) end
    elseif G.render then
        local t = uv(G.render, 44)
        if type(t) == "number" then S.zoom = t end
    end

    if S.voiceAll then forceVoice() end

    if S.loaded and G.gt and S._lastWorld ~= G.gt.name then
        if S._lastWorld ~= nil then
            S.entities = {}
            S.userEntity = {}
        end
        S._lastWorld = G.gt.name
    end
end

-- ══════════════════════════════════════════════════════════════
--  INIT
-- ══════════════════════════════════════════════════════════════
local function installStaffFrame()
    local gt = G.gt
    if not gt then return end
    local current = gt.staffFrame
    if current and current ~= G.ourStaffFrame then
        local original = current
        local wrapper = function(dt, x, y, hp, maxHp, grounded)
            if type(x) == "number" then LX.Pos.x = x end
            if type(y) == "number" then LX.Pos.y = y end
            if type(hp) == "number" then LX.Pos.hp = hp end
            LX.Pos.tx = math.floor(LX.Pos.x)
            LX.Pos.ty = math.floor(LX.Pos.y - 1)
            LX.Pos.dead = uv(G.render, 7) == true
            S._x = LX.Pos.x
            S._y = LX.Pos.y
            S._staffX = LX.Pos.x
            S._staffY = LX.Pos.y
            S._staffAt = os.clock()
            return original(dt, x, y, hp, maxHp, grounded)
        end
        gt.staffFrame = wrapper
        G.ourStaffFrame = wrapper
    elseif not current then
        local wrapper = function(dt, x, y, hp, maxHp, grounded)
            if type(x) == "number" then LX.Pos.x = x end
            if type(y) == "number" then LX.Pos.y = y end
            if type(hp) == "number" then LX.Pos.hp = hp end
            LX.Pos.tx = math.floor(LX.Pos.x)
            LX.Pos.ty = math.floor(LX.Pos.y - 1)
            S._x = LX.Pos.x
            S._y = LX.Pos.y
            S._staffX = LX.Pos.x
            S._staffY = LX.Pos.y
            S._staffAt = os.clock()
        end
        gt.staffFrame = wrapper
        G.ourStaffFrame = wrapper
    end
end

local function tryDiscover()
    loadModules()
    if not G.gt then
        local found = findGameTable()
        if found then
            G.gt = found
        end
    end
    if G.gt then
        if not G.render then
            G.render = findRenderFn(G.gt)
        end
        installStaffFrame()
        wrapLaser()
        if not S._zoomSeeded and G.render then
            local z = uv(G.render, 44)
            if type(z) == "number" then S.zoom = z end
            S._zoomSeeded = true
        end
    end
    if G.gt and G.Net and not G.connected then
        connectNet()
    end
    if G.gt and G.Net and G.ItemDB and G.ItemIcon and G.Roles then
        G.ready = true
    end
    if G.ready and not S._postReady then
        S._postReady = true
        if S.instantSpin then LX.FastSpin_SetInstant(true) end
        if S.nametag then LX.SetNametag(S.nametag, S.namedStyle, S.namedColor) end
    end
end

function LX.IsReady()
    return G.ready == true
end

function LX.GetGameTable()
    return G.gt
end

-- UI convenience
function LX.Cache_Changed() return true end
function LX.Cache_Reset() return true end
function LX.Cache_ResetAll() return true end

function LX.Init()
    if S._inited then return end
    S._inited = true
    installClamp()
    tryDiscover()
    if not G.frameBound then
        G.frameBound = true
        pcall(function() RunService:UnbindFromRenderStep("LX_MAIN_FRAME") end)
        pcall(function()
            RunService:BindToRenderStep("LX_MAIN_FRAME", Enum.RenderPriority.Last.Value, onFrame)
        end)
    end
    task.spawn(function()
        while true do
            local ok, err = pcall(tryDiscover)
            if not ok then S.lastError = tostring(err) end
            task.wait(G.ready and 3 or 0.5)
        end
    end)
end

LX.Init()

return LX
