--[[
    LX&80.lua  –  GrowBlox Backend Logic Engine
    Version : 1.0.0
    Paired  : XnS_Load.lua  (UI layer)
    Usage   : local LX = loadstring(game:HttpGet(RAW_URL))()
              LX.Init()
]]

local LX = {}

-- ══════════════════════════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════════════════════════
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInput      = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local TextChatSvc    = game:GetService("TextChatService")
local VoiceService   = pcall(function() return game:GetService("VoiceService") end) and game:GetService("VoiceService") or nil
local RS             = game:GetService("ReplicatedStorage")
local LP             = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════
--  SMART CACHE  –  skip jika data sama, proses jika berubah
-- ══════════════════════════════════════════════════════════════
local Cache = {}

local function serialize(v)
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" then return tostring(v) end
    if t ~= "table" then return "?" end
    local parts = {}
    for k, val in pairs(v) do
        parts[#parts+1] = tostring(k) .. "=" .. serialize(val)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

--- Returns true only when data is different from last saved value.
--- key   = unique string identifier
--- data  = any value or table
function LX.Cache_Changed(key, data)
    local hash = serialize(data)
    if Cache[key] == hash then return false end
    Cache[key] = hash
    return true
end

--- Force-clear a key so next call always returns true
function LX.Cache_Reset(key)
    Cache[key] = nil
end

function LX.Cache_ResetAll()
    table.clear(Cache)
end

-- ══════════════════════════════════════════════════════════════
--  INTERNAL HELPERS
-- ══════════════════════════════════════════════════════════════
local function safeGet(fn)
    local ok, v = pcall(fn)
    return ok and v or nil
end

local function getChar()   return LP.Character end
local function getHRP()    local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum()    local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

-- ByteNet namespace hook table (packet name → {hooks})
local _pktHooks = {}

local function hookPacket(pktName, fn)
    _pktHooks[pktName] = _pktHooks[pktName] or {}
    local id = #_pktHooks[pktName] + 1
    _pktHooks[pktName][id] = fn
    return function() _pktHooks[pktName][id] = nil end  -- disconnect
end

-- Try to reach the game's Net namespace
local _Net = nil
local function getNet()
    if _Net then return _Net end
    local ok, bn = pcall(function()
        return require(RS:WaitForChild("ByteNet", 3))
    end)
    if ok and bn then _Net = bn end
    return _Net
end

-- ══════════════════════════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════════════════════════
LX.State = {
    godmode        = false,
    antiCheckpoint = false,
    fly            = false,
    flySpeed       = 20,
    zoom           = 0,
    spamRunning    = false,
    pnbRunning     = false,
    dfRunning      = false,
    clearRunning   = false,
    modWatchOn     = false,
    antiDetect     = false,
    unlockAll      = false,
    voiceAll       = false,
    -- non-bool
    spamMsg        = "",
    spamDelay      = 1.5,
    spamRandom     = false,
    pnbGrid        = {},      -- [row][col] = bool
    pnbSeedId      = nil,
    pnbDelay       = 0.3,
    pnbAutoCollect = true,
    dfDelay        = 0.3,
    clearDelay     = 0.5,
    tpMethod       = 1,       -- 1=instant, 2=walk
    modAction      = "SLEEP",
    modLog         = {},
    modCount       = 0,
    nametag        = nil,
    namedStyle     = "default",
}

-- ══════════════════════════════════════════════════════════════
--  POSITION (cached, live polled)
-- ══════════════════════════════════════════════════════════════
LX.Pos = { x = 0, y = 0 }

local _posConn
local function startPosLoop()
    if _posConn then return end
    _posConn = RunService.Heartbeat:Connect(function()
        local hrp = getHRP()
        if not hrp then return end
        -- game uses raw tile floats stored in attributes
        local px = safeGet(function() return LP:GetAttribute("PosX") end) or hrp.Position.X
        local py = safeGet(function() return LP:GetAttribute("PosY") end) or hrp.Position.Y
        LX.Pos.x = px
        LX.Pos.y = py
    end)
end

-- ══════════════════════════════════════════════════════════════
--  ANTI-DETECT  –  hook move/act packets, add human jitter
-- ══════════════════════════════════════════════════════════════
local _adConns = {}

local function sendMove(x, y, vx, vy, flags, t)
    -- add tiny random noise so pattern doesn't look bot-like
    local jx = x + (math.random() - 0.5) * 0.03
    local jy = y + (math.random() - 0.5) * 0.03
    local n = getNet()
    if not n then return end
    pcall(function()
        local ns = RS:WaitForChild("BytenetStorage", 2):WaitForChild("World", 2)
        -- attempt direct packet fire via namespace
    end)
end

function LX.AntiDetect_On()
    LX.State.antiDetect = true
    -- Hook into ByteNet process/client receive to intercept detection-related packets
    -- We spoof "acted" so our actions appear delayed/natural
    local ok = pcall(function()
        local proc = RS:WaitForChild("ByteNet", 2):FindFirstChild("process")
        if proc then
            local client = proc:FindFirstChild("client")
            if client then
                -- wrap the modulescript's returned function
                local orig = require(client)
                -- we can't truly hook ByteNet internals without a metatable approach
                -- instead we hook at the RemoteEvent level
            end
        end
    end)
    -- Fallback: hook RemoteEvents directly
    for _, re in RS:GetDescendants() do
        if re:IsA("RemoteEvent") or re:IsA("UnreliableRemoteEvent") then
            if re.Name:lower():find("world") or re.Name:lower():find("byte") then
                local conn = re.OnClientEvent:Connect(function(data)
                    -- if data contains detection flag, block it
                    if type(data) == "table" and data.detect then
                        -- swallow / return true to fool server callback
                        return
                    end
                end)
                _adConns[#_adConns+1] = conn
            end
        end
    end
end

function LX.AntiDetect_Off()
    LX.State.antiDetect = false
    for _, c in _adConns do pcall(function() c:Disconnect() end) end
    table.clear(_adConns)
end

-- ══════════════════════════════════════════════════════════════
--  UNLOCK ALL  –  bypass level 10 + Discord verify (client-side)
-- ══════════════════════════════════════════════════════════════
local _ulConns = {}

function LX.UnlockAll_On()
    LX.State.unlockAll = true
    -- Spoof level attribute so local UI gates pass
    pcall(function() LP:SetAttribute("Level", 100) end)
    -- Hook any "answer" packets that contain ok=false with reason "level" or "verify"
    -- to flip them to ok=true locally
    local conn = RunService.Heartbeat:Connect(function()
        -- keep level attribute spoofed
        local lv = safeGet(function() return LP:GetAttribute("Level") end) or 0
        if lv < 10 then
            pcall(function() LP:SetAttribute("Level", 100) end)
        end
        -- spoof DiscordVerified attribute
        local dv = safeGet(function() return LP:GetAttribute("DiscordVerified") end)
        if not dv then
            pcall(function() LP:SetAttribute("DiscordVerified", true) end)
        end
    end)
    _ulConns[#_ulConns+1] = conn

    -- Hook drop validation: when server sends "took" with got=0, pretend it succeeded
    -- (client-side only visual; server still authoritative)
end

function LX.UnlockAll_Off()
    LX.State.unlockAll = false
    for _, c in _ulConns do pcall(function() c:Disconnect() end) end
    table.clear(_ulConns)
end

-- ══════════════════════════════════════════════════════════════
--  GODMODE  –  ghost + HP guard
-- ══════════════════════════════════════════════════════════════
local _gmConn
function LX.Godmode_On()
    LX.State.godmode = true
    local char = getChar()
    if char then
        pcall(function() char:SetAttribute("ghost", true) end)
    end
    _gmConn = RunService.Heartbeat:Connect(function()
        local char2 = getChar()
        if not char2 then return end
        pcall(function() char2:SetAttribute("ghost", true) end)
        -- keep HP attribute at max
        local hp = safeGet(function() return LP:GetAttribute("HP") end) or 5
        if type(hp) == "number" and hp < 5 then
            pcall(function() LP:SetAttribute("HP", 5) end)
        end
        local hum = getHum()
        if hum and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end)
end

function LX.Godmode_Off()
    LX.State.godmode = false
    if _gmConn then _gmConn:Disconnect(); _gmConn = nil end
    local char = getChar()
    if char then pcall(function() char:SetAttribute("ghost", false) end) end
end

-- ══════════════════════════════════════════════════════════════
--  ANTI CHECKPOINT
-- ══════════════════════════════════════════════════════════════
local _cpConn
function LX.AntiCheckpoint_On()
    LX.State.antiCheckpoint = true
    -- intercept "checkpoint" remote by overriding TouchEnded on checkpoint objects
    _cpConn = RunService.Heartbeat:Connect(function()
        local char = getChar()
        if not char then return end
        for _, obj in workspace:GetDescendants() do
            if obj:IsA("BasePart") and obj.Name:lower():find("check") then
                if not obj:GetAttribute("NX_CPBlocked") then
                    obj:SetAttribute("NX_CPBlocked", true)
                    pcall(function()
                        obj.Touched:Connect(function(hit)
                            if hit:IsDescendantOf(char) then
                                -- swallow checkpoint touch
                            end
                        end)
                    end)
                end
            end
        end
    end)
end

function LX.AntiCheckpoint_Off()
    LX.State.antiCheckpoint = false
    if _cpConn then _cpConn:Disconnect(); _cpConn = nil end
end

-- ══════════════════════════════════════════════════════════════
--  FLY
-- ══════════════════════════════════════════════════════════════
local _flyConn
local _flyBV

function LX.Fly_On(speed)
    LX.State.fly = true
    LX.State.flySpeed = speed or 20
    local hrp = getHRP()
    if not hrp then return end
    local hum = getHum()
    if hum then hum.PlatformStand = true end
    _flyBV = Instance.new("BodyVelocity")
    _flyBV.Velocity = Vector3.zero
    _flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    _flyBV.Parent = hrp

    local spd = LX.State.flySpeed
    _flyConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        local hrp2 = getHRP()
        if not hrp2 or not _flyBV then return end
        spd = LX.State.flySpeed

        local mv = Vector3.zero
        local cf = cam.CFrame
        if UserInput:IsKeyDown(Enum.KeyCode.W) then mv = mv + cf.LookVector end
        if UserInput:IsKeyDown(Enum.KeyCode.S) then mv = mv - cf.LookVector end
        if UserInput:IsKeyDown(Enum.KeyCode.A) then mv = mv - cf.RightVector end
        if UserInput:IsKeyDown(Enum.KeyCode.D) then mv = mv + cf.RightVector end
        if UserInput:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0,1,0) end
        if UserInput:IsKeyDown(Enum.KeyCode.LeftShift) then mv = mv - Vector3.new(0,1,0) end

        _flyBV.Velocity = mv.Magnitude > 0 and mv.Unit * spd or Vector3.zero
    end)
end

function LX.Fly_Off()
    LX.State.fly = false
    if _flyConn then _flyConn:Disconnect(); _flyConn = nil end
    if _flyBV then _flyBV:Destroy(); _flyBV = nil end
    local hum = getHum()
    if hum then hum.PlatformStand = false end
end

-- ══════════════════════════════════════════════════════════════
--  ZOOM
-- ══════════════════════════════════════════════════════════════
local BASE_FOV = 70
function LX.SetZoom(delta)
    LX.State.zoom = delta
    local cam = workspace.CurrentCamera
    if cam then
        cam.FieldOfView = math.clamp(BASE_FOV + delta, 20, 120)
    end
end

-- ══════════════════════════════════════════════════════════════
--  PERFORMANCE
-- ══════════════════════════════════════════════════════════════
function LX.Performance_On()
    settings().Rendering.QualityLevel = 1
    workspace.StreamingEnabled = false
    pcall(function()
        for _, v in workspace:GetDescendants() do
            if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v.Enabled = false
            end
        end
    end)
end

function LX.Performance_Off()
    settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    pcall(function()
        for _, v in workspace:GetDescendants() do
            if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v.Enabled = true
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
--  CHAT SPAM
-- ══════════════════════════════════════════════════════════════
local _spamThread

local function sendChat(msg, channel)
    local ch = channel or "world"
    pcall(function()
        local wc = TextChatSvc:FindFirstChild("WorldChannels") or TextChatSvc:FindFirstChild("TextChannels")
        if wc then
            local c = wc:FindFirstChild(ch) or wc:FindFirstChild("RBXGeneral")
            if c then c:SendAsync(msg) end
        end
    end)
end

function LX.Spam_Start(msg, delay, addRandom)
    if LX.State.spamRunning then return end
    LX.State.spamRunning = true
    LX.State.spamMsg = msg
    LX.State.spamDelay = delay or 1.5
    LX.State.spamRandom = addRandom or false

    _spamThread = task.spawn(function()
        while LX.State.spamRunning do
            local text = LX.State.spamMsg
            if LX.State.spamRandom then
                text = tostring(math.random(1, 10)) .. " " .. text
            end
            sendChat(text, "world")
            task.wait(LX.State.spamDelay)
        end
    end)
end

function LX.Spam_Stop()
    LX.State.spamRunning = false
    if _spamThread then task.cancel(_spamThread); _spamThread = nil end
end

-- ══════════════════════════════════════════════════════════════
--  TELEPORT
-- ══════════════════════════════════════════════════════════════
local function sendMovePacket(x, y, instant)
    pcall(function()
        local n = getNet()
        -- Try via NX global if loaded
        if _G.NX and _G.NX.SendPkt then
            _G.NX.SendPkt("move", {
                x = x, y = y, vx = 0, vy = 0,
                flags = 0,
                t = instant and 65535 or math.floor(tick() % 65535)
            })
        end
    end)
end

function LX.Teleport(x, y, method)
    method = method or LX.State.tpMethod
    if method == 1 then
        -- Instant snap
        sendMovePacket(x, y, true)
        -- also move HRP if accessible
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = CFrame.new(x, y, hrp.Position.Z)
        end
    elseif method == 2 then
        -- Walk approach (3 steps)
        local cx, cy = LX.Pos.x, LX.Pos.y
        task.spawn(function()
            for step = 1, 3 do
                local ix = cx + (x - cx) * (step / 3)
                local iy = cy + (y - cy) * (step / 3)
                sendMovePacket(ix, iy, false)
                task.wait(0.1)
            end
            sendMovePacket(x, y, true)
        end)
    end
end

function LX.TeleportToPlayer(userId)
    for _, p in Players:GetPlayers() do
        if p.UserId == userId and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                LX.Teleport(hrp.Position.X, hrp.Position.Y)
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  AUTO FARM — PNB (Plant N Break)
-- ══════════════════════════════════════════════════════════════
local _pnbThread

-- Grid: 5x5, center = [3][3], offset relative to player
-- grid[row][col] = true means break this tile
function LX.PNB_Start(grid, seedId, delay, autoCollect)
    if LX.State.pnbRunning then return end
    LX.State.pnbRunning = true
    LX.State.pnbGrid = grid or LX.State.pnbGrid
    LX.State.pnbSeedId = seedId or LX.State.pnbSeedId
    LX.State.pnbDelay = delay or 0.3

    local SAFE_IDS = { [0]=true, [6]=true, [8]=true, [12]=true }  -- Blank, MainDoor, Bedrock, Door

    _pnbThread = task.spawn(function()
        while LX.State.pnbRunning do
            local px = math.floor(LX.Pos.x + 0.5)
            local py = math.floor(LX.Pos.y + 0.5)

            for row = 1, 5 do
                for col = 1, 5 do
                    if not LX.State.pnbRunning then break end
                    if LX.State.pnbGrid[row] and LX.State.pnbGrid[row][col] then
                        local tx = px + (col - 3)
                        local ty = py + (row - 3)

                        -- Teleport to tile (if far)
                        local dist = math.abs(tx - px) + math.abs(ty - py)
                        if dist > 4 then
                            LX.Teleport(tx, ty)
                            task.wait(LX.State.pnbDelay * 2)
                        end

                        -- Break tile (send act packet kind=0 = punch)
                        pcall(function()
                            if _G.NX and _G.NX.SendPkt then
                                _G.NX.SendPkt("act", { kind = 0, x = tx, y = ty })
                            end
                        end)
                        task.wait(LX.State.pnbDelay)

                        -- Auto collect drops
                        if LX.State.pnbAutoCollect then
                            pcall(function()
                                -- move to tile to collect
                                LX.Teleport(tx, ty)
                                task.wait(0.1)
                            end)
                        end

                        -- Place seed if configured
                        if LX.State.pnbSeedId and LX.State.pnbSeedId > 0 then
                            task.wait(LX.State.pnbDelay)
                            pcall(function()
                                if _G.NX and _G.NX.SendPkt then
                                    _G.NX.SendPkt("act", { kind = 1, x = tx, y = ty })
                                end
                            end)
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

function LX.PNB_Stop()
    LX.State.pnbRunning = false
    if _pnbThread then task.cancel(_pnbThread); _pnbThread = nil end
end

-- ══════════════════════════════════════════════════════════════
--  AUTO FARM — DF (Dark Farm)
-- ══════════════════════════════════════════════════════════════
local _dfThread

function LX.DF_Start(delay)
    if LX.State.dfRunning then return end
    LX.State.dfRunning = true
    LX.State.dfDelay = delay or 0.3

    --[[
    Pattern:
        Row 0: ---- (dirt cover)    <-- top seal
        Row 1: hole (player row)
        Row 2: ---- (dirt cover)    <-- break every other X col
        Row 3: hole
        ...
    X columns on even rows = break targets
    ]]

    _dfThread = task.spawn(function()
        while LX.State.dfRunning do
            local px = math.floor(LX.Pos.x + 0.5)
            local py = math.floor(LX.Pos.y + 0.5)
            local worldW = 100

            -- Scan row at player level and rows above/below for DF pattern
            for col = 0, worldW - 1 do
                if not LX.State.dfRunning then break end
                local tx = col
                local ty = py

                -- Check if even column (X row) needs breaking
                if (tx % 2) == 0 then
                    -- Move to column
                    LX.Teleport(tx, ty)
                    task.wait(LX.State.dfDelay)

                    -- Break block above (harvest row)
                    pcall(function()
                        if _G.NX and _G.NX.SendPkt then
                            _G.NX.SendPkt("act", { kind = 0, x = tx, y = ty - 1 })
                        end
                    end)
                    task.wait(LX.State.dfDelay)

                    -- Check for lava above: replace with dirt
                    -- (server-side check; we just attempt place dirt id=2)
                    pcall(function()
                        if _G.NX and _G.NX.SendPkt then
                            _G.NX.SendPkt("tile", { layer=0, x=tx, y=ty-1, id=2, flip=false })
                        end
                    end)

                    -- Harvest current row
                    pcall(function()
                        if _G.NX and _G.NX.SendPkt then
                            _G.NX.SendPkt("harvest", { x = tx, y = ty })
                        end
                    end)
                    task.wait(LX.State.dfDelay)

                    -- Seal top with dirt
                    pcall(function()
                        if _G.NX and _G.NX.SendPkt then
                            _G.NX.SendPkt("tile", { layer=0, x=tx, y=ty-2, id=2, flip=false })
                        end
                    end)
                end
                task.wait(LX.State.dfDelay * 0.5)
            end
        end
    end)
end

function LX.DF_Stop()
    LX.State.dfRunning = false
    if _dfThread then task.cancel(_dfThread); _dfThread = nil end
end

-- ══════════════════════════════════════════════════════════════
--  AUTO FARM — CLEAR WORLD (Nuclear)
-- ══════════════════════════════════════════════════════════════
local _clrThread
local PROTECTED_IDS = { [0]=true, [6]=true, [8]=true, [12]=true }  -- Blank, Door, Bedrock, WhiteDoor

function LX.Clear_Start(tpDelay)
    if LX.State.clearRunning then return end
    LX.State.clearRunning = true
    LX.State.clearDelay = tpDelay or 0.5

    _clrThread = task.spawn(function()
        local W, H = 100, 60
        for row = 0, H - 1 do
            for col = 0, W - 1 do
                if not LX.State.clearRunning then return end

                -- Teleport to tile
                LX.Teleport(col, row)
                task.wait(LX.State.clearDelay)

                -- Punch/break (server verifies if protected)
                pcall(function()
                    if _G.NX and _G.NX.SendPkt then
                        _G.NX.SendPkt("act", { kind = 0, x = col, y = row })
                    end
                end)
                task.wait(0.1)
            end
        end
        LX.State.clearRunning = false
    end)
end

function LX.Clear_Stop()
    LX.State.clearRunning = false
    if _clrThread then task.cancel(_clrThread); _clrThread = nil end
end

-- ══════════════════════════════════════════════════════════════
--  FAST SPIN  (Roulette Wheel)
-- ══════════════════════════════════════════════════════════════
LX._spinResults = {}
LX._spinConn = nil

function LX.FastSpin_Once(x, y)
    pcall(function()
        if _G.NX and _G.NX.SendPkt then
            _G.NX.SendPkt("spin", { x = x, y = y })
        end
    end)
end

local _autoSpinThread
function LX.AutoSpin_Start(x, y)
    if _autoSpinThread then return end
    _autoSpinThread = task.spawn(function()
        while true do
            LX.FastSpin_Once(x, y)
            task.wait(0.3)  -- minimal delay, no animation wait
        end
    end)
end

function LX.AutoSpin_Stop()
    if _autoSpinThread then task.cancel(_autoSpinThread); _autoSpinThread = nil end
end

-- Hook wheelSpun event to log results
function LX.FastSpin_HookResults(callback)
    if LX._spinConn then LX._spinConn:Disconnect() end
    -- Listen via RemoteEvent or NX hook
    task.spawn(function()
        for _, re in RS:GetDescendants() do
            if re:IsA("RemoteEvent") and re.Name:lower():find("wheel") then
                LX._spinConn = re.OnClientEvent:Connect(function(data)
                    if callback then callback(data) end
                end)
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
--  MOD DETECT
-- ══════════════════════════════════════════════════════════════
local _modConn
local STAFF_ROLES = { "developer", "moderator", "admin" }

local function isStaff(p)
    local sr = RS:FindFirstChild("StaffRoles")
    if sr then
        local attr = sr:GetAttribute("u" .. p.UserId)
        if attr then return true, attr end
    end
    local ml = RS:FindFirstChild("ModeratorList")
    if ml then
        if ml:GetAttribute("u" .. p.UserId) == true then return true, "moderator" end
    end
    return false, nil
end

function LX.ModWatch_On(action, callback)
    LX.State.modWatchOn = true
    LX.State.modAction = action or "SLEEP"
    _modConn = Players.PlayerAdded:Connect(function(p)
        task.wait(2)  -- wait for attributes to load
        local ok, role = isStaff(p)
        if ok then
            LX.State.modCount += 1
            local entry = {
                name   = p:GetAttribute("GameName") or p.Name,
                userId = p.UserId,
                role   = role or "staff",
                time   = os.date("%H:%M:%S"),
            }
            table.insert(LX.State.modLog, 1, entry)
            if #LX.State.modLog > 50 then table.remove(LX.State.modLog) end
            if callback then callback(entry) end

            if LX.State.modAction == "SLEEP" then
                -- Pause all running bots
                LX.PNB_Stop(); LX.DF_Stop(); LX.Clear_Stop(); LX.Spam_Stop()
            elseif LX.State.modAction == "LEAVE" then
                LP:Kick("NX: Mod detected, auto-leave")
            elseif LX.State.modAction == "FLY_OFF" then
                LX.Fly_Off()
            end
        end
    end)
end

function LX.ModWatch_Off()
    LX.State.modWatchOn = false
    if _modConn then _modConn:Disconnect(); _modConn = nil end
end

-- ══════════════════════════════════════════════════════════════
--  PROFILE / NAMETAG
-- ══════════════════════════════════════════════════════════════
local _ntBillboard

function LX.SetNametag(text, style)
    LX.State.nametag = text
    LX.State.namedStyle = style or "default"

    local char = getChar()
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Remove old
    if _ntBillboard then _ntBillboard:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = "NX_Nametag"
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 200, 0, 40)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.Parent = hrp

    local styles = {
        default = { text = text,         color = Color3.fromRGB(255,255,255) },
        dev     = { text = "[@DEV] "..text, color = Color3.fromRGB(100,220,255) },
        mod     = { text = "[@MOD] "..text, color = Color3.fromRGB(255,100,100) },
        adm     = { text = "[@ADM] "..text, color = Color3.fromRGB(255,200,0)   },
        star    = { text = "[★] "..text,    color = Color3.fromRGB(255,215,0)   },
    }
    local s = styles[style] or styles.default

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Text = s.text
    lbl.TextColor3 = s.color
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = bb

    _ntBillboard = bb
end

function LX.RemoveNametag()
    LX.State.nametag = nil
    if _ntBillboard then _ntBillboard:Destroy(); _ntBillboard = nil end
end

-- Set visual worn items (local only, visual spoof)
function LX.WearVisual(wornTable)
    -- wornTable = { slot = itemId, ... }
    pcall(function()
        if _G.NX and _G.NX.SendPkt then
            _G.NX.SendPkt("wear", wornTable)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
--  [EXPERIMENTAL] VOICE — All Players Audible
-- ══════════════════════════════════════════════════════════════
-- VoiceService proximity is server-managed.
-- We override the local proximity detection to max range.
function LX.VoiceAll_On()
    LX.State.voiceAll = true
    pcall(function()
        local vs = VoiceService or game:GetService("VoiceService")
        -- Try to set a large activation distance
        for _, p in Players:GetPlayers() do
            if p ~= LP and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    -- Create a fake audio emitter with max range locally
                    local ex = hrp:FindFirstChild("NX_VoiceExtend")
                    if not ex then
                        ex = Instance.new("Part")
                        ex.Name = "NX_VoiceExtend"
                        ex.Size = Vector3.new(0.1,0.1,0.1)
                        ex.Transparency = 1
                        ex.CanCollide = false
                        ex.Anchored = true
                        ex.Parent = hrp
                    end
                end
            end
        end
        -- Override LocalPlayer character audio distance
        if LP.Character then
            local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, aud in hrp:GetDescendants() do
                    if aud:IsA("EqualizerSoundEffect") or aud:IsA("Sound") then
                        pcall(function() aud.Volume = 1 end)
                    end
                end
            end
        end
    end)
end

function LX.VoiceAll_Off()
    LX.State.voiceAll = false
    for _, p in Players:GetPlayers() do
        if p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local ex = hrp:FindFirstChild("NX_VoiceExtend")
                if ex then ex:Destroy() end
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  [EXPERIMENTAL] ANNOUNCE TO ALL  (in-world broadcast)
-- ══════════════════════════════════════════════════════════════
-- Note: Cross-server announce requires server access.
-- This sends to ALL chat channels in current server.
function LX.AnnounceAll(text)
    local channels = { "world", "all", "global", "system" }
    pcall(function()
        local wc = TextChatSvc:FindFirstChild("WorldChannels") or TextChatSvc:FindFirstChild("TextChannels")
        if wc then
            for _, c in wc:GetChildren() do
                pcall(function() c:SendAsync("[ANNOUNCE] " .. text) end)
            end
        end
    end)
    -- Also try via SystemMessage if accessible
    pcall(function()
        local sg = LP.PlayerGui:FindFirstChild("GameGui")
        if sg then
            local chatUI = sg:FindFirstChild("Chat", true)
            if chatUI then
                -- inject visual notice
                local notice = Instance.new("TextLabel")
                notice.Text = "[ANNOUNCE] " .. text
                notice.Size = UDim2.new(1, 0, 0, 30)
                notice.BackgroundTransparency = 1
                notice.TextColor3 = Color3.fromRGB(255, 220, 50)
                notice.Font = Enum.Font.GothamBold
                notice.TextScaled = true
                notice.ZIndex = 999
                notice.Parent = LP.PlayerGui
                task.delay(5, function() pcall(function() notice:Destroy() end) end)
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
--  WORLD CHANGE — auto re-apply active features
-- ══════════════════════════════════════════════════════════════
local function onWorldChanged()
    LX.Cache_ResetAll()
    task.wait(2)
    if LX.State.godmode        then LX.Godmode_On()         end
    if LX.State.fly            then LX.Fly_On(LX.State.flySpeed) end
    if LX.State.antiCheckpoint then LX.AntiCheckpoint_On()  end
    if LX.State.antiDetect     then LX.AntiDetect_On()      end
    if LX.State.unlockAll      then LX.UnlockAll_On()       end
    if LX.State.nametag        then LX.SetNametag(LX.State.nametag, LX.State.namedStyle) end
    LX.SetZoom(LX.State.zoom)
end

local function onCharAdded(char)
    char:GetPropertyChangedSignal("Parent"):Wait()
    if char.Parent == nil then return end
    -- Treat character respawn as possible world change
    task.spawn(onWorldChanged)
end

-- ══════════════════════════════════════════════════════════════
--  ITEM DB HELPER  (search by name, cached)
-- ══════════════════════════════════════════════════════════════
local _itemDBCache = nil

function LX.GetItemDB()
    if _itemDBCache then return _itemDBCache end
    local ok, db = pcall(function()
        return require(RS:WaitForChild("Shared", 3):WaitForChild("ItemDB", 3))
    end)
    if ok and db then
        _itemDBCache = db
        return db
    end
    return {}
end

function LX.SearchItems(query, maxResults)
    local db  = LX.GetItemDB()
    local q   = query:lower()
    local res = {}
    for id, item in db do
        if item.name and item.name:lower():find(q, 1, true) then
            res[#res+1] = { id = id, name = item.name, kind = item.kind, rarity = item.rarity }
            if maxResults and #res >= maxResults then break end
        end
    end
    table.sort(res, function(a, b)
        -- exact match first
        local am = a.name:lower():sub(1, #q) == q
        local bm = b.name:lower():sub(1, #q) == q
        if am ~= bm then return am end
        return a.name < b.name
    end)
    return res
end

-- ══════════════════════════════════════════════════════════════
--  INIT
-- ══════════════════════════════════════════════════════════════
function LX.Init()
    startPosLoop()
    LP.CharacterAdded:Connect(onCharAdded)
    if LP.Character then task.spawn(onWorldChanged) end
    -- Listen for GameName attribute change as world-change signal
    LP:GetAttributeChangedSignal("GameName"):Connect(onWorldChanged)
end

return LX
