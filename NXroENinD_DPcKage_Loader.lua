-- NXroENinD_DPcKage Loader
-- Single-file bootstrap. Paste this into your executor.
-- Modules load from GitHub on first access — zero FPS cost until used.
--
-- Setup:
--   1. Upload NXroENinD_DPcKage/*.lua to your GitHub repo
--   2. Fill in RAW_BASE below with your raw.githubusercontent.com path
--   3. Run this script once — NX is ready globally.

local RAW_BASE = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/NXroENinD_DPcKage"

-- ── URL table ─────────────────────────────────────────────────────────────
local URLS = {
    Events      = RAW_BASE .. "/Events.lua",
    Config      = RAW_BASE .. "/Config.lua",
    Utils       = RAW_BASE .. "/Utils.lua",
    SmoothBuf   = RAW_BASE .. "/SmoothBuf.lua",
    Console     = RAW_BASE .. "/Console.lua",
    Network     = RAW_BASE .. "/Network.lua",
    PlayerAPI   = RAW_BASE .. "/PlayerAPI.lua",
    Inventory   = RAW_BASE .. "/Inventory.lua",
    World       = RAW_BASE .. "/World.lua",
    Scheduler   = RAW_BASE .. "/Scheduler.lua",
    Teleport    = RAW_BASE .. "/Teleport.lua",
    MultiPacket = RAW_BASE .. "/MultiPacket.lua",
}

-- ── Lazy module cache ─────────────────────────────────────────────────────
-- Modules are downloaded and executed only when first accessed.
-- Subsequent accesses return the cached result instantly.
local _cache  = {}
local _loading = {}

local function fetch(name)
    if _cache[name] then return _cache[name] end
    if _loading[name] then
        -- Spinwait for concurrent access (rare edge case)
        while _loading[name] do task.wait() end
        return _cache[name]
    end

    local url = URLS[name]
    assert(url, "NXroENinD_DPcKage Loader: unknown module '" .. name .. "'")

    _loading[name] = true
    local ok, src = pcall(function()
        return game:HttpGet(url, true)
    end)
    assert(ok, "NXroENinD_DPcKage Loader: failed to fetch " .. name .. "\n" .. tostring(src))

    -- Inject a minimal require shim so modules can call require(script.Parent.X)
    -- by routing through this loader instead
    local env = setmetatable({}, { __index = getfenv(0) })
    env.require = function(ref)
        -- ref may be an Instance path like script.Parent.Events
        -- Extract the name from the last component
        local n = tostring(ref):match("%.(%w+)$") or tostring(ref)
        return fetch(n)
    end

    local chunk, err = loadstring(src, "NXroENinD_DPcKage." .. name)
    assert(chunk, "NXroENinD_DPcKage Loader: compile error in " .. name .. "\n" .. tostring(err))
    setfenv(chunk, env)

    local result = chunk()
    _loading[name] = false
    _cache[name] = result
    return result
end

-- ── Load order: dependencies first, then consumers ───────────────────────
-- Events and Config have no deps — load eagerly (tiny, needed by all)
local function bootstrap()
    -- Phase 1: zero-dep foundations
    fetch("Events")
    fetch("Config")
    fetch("Utils")

    -- Phase 2: core systems (lazy proxied via NX table below)
    -- These are NOT downloaded here — only when NX.X is first accessed.
end

-- ── Proxy NX table ────────────────────────────────────────────────────────
-- Accessing NX.SendPkt triggers fetch("Network") on first touch, then
-- delegates. All subsequent calls go directly to the cached module.
local NX = {}
local _mt = {}

-- Direct property map (for things that live on a sub-module)
local _map = {
    -- Network
    SendPkt     = function() return fetch("Network").SendPkt     end,
    SendRaw     = function() return fetch("Network").SendRaw     end,
    HookPkt     = function() return fetch("Network").HookPkt     end,
    UnhookPkt   = function() return fetch("Network").UnhookPkt   end,
    -- Player
    Player      = function() return fetch("PlayerAPI").Player    end,
    -- Console
    ConsoleMsg  = function() return fetch("Console").ConsoleMsg  end,
    ConsoleLog  = function() return fetch("Console").Log         end,
    ConsoleClear= function() return fetch("Console").Clear       end,
    -- Inventory
    GetInvent   = function() return fetch("Inventory").GetInvent end,
    FindItem    = function() return fetch("Inventory").FindItem  end,
    FindAllItems= function() return fetch("Inventory").FindAllItems end,
    CountItem   = function() return fetch("Inventory").CountItem end,
    HasItem     = function() return fetch("Inventory").HasItem   end,
    GetEquipped = function() return fetch("Inventory").GetEquipped end,
    GetByType   = function() return fetch("Inventory").GetByType end,
    -- World
    GetWorld    = function() return fetch("World").GetWorld      end,
    GetTile     = function() return fetch("World").GetTile       end,
    FindTiles   = function() return fetch("World").FindTiles     end,
    TileAt      = function() return fetch("World").TileAt        end,
    -- Scheduler
    After       = function() return fetch("Scheduler").After     end,
    Every       = function() return fetch("Scheduler").Every     end,
    Cancel      = function() return fetch("Scheduler").Cancel    end,
    NextFrame   = function() return fetch("Scheduler").NextFrame end,
    -- Teleport
    FindPath    = function() return fetch("Teleport").FindPath   end,
    CancelWalk  = function() return fetch("Teleport").CancelWalk end,
    -- MultiPacket
    SendMulti   = function() return fetch("MultiPacket").SendMulti    end,
    SendChain   = function() return fetch("MultiPacket").SendChain    end,
    SendIf      = function() return fetch("MultiPacket").SendIf       end,
    DefineMacro = function() return fetch("MultiPacket").DefineMacro  end,
    RunMacro    = function() return fetch("MultiPacket").RunMacro     end,
    -- Sub-module access (for advanced use)
    SmoothBuf   = function() return fetch("SmoothBuf")   end,
    Events      = function() return fetch("Events")       end,
    Config      = function() return fetch("Config")       end,
    Utils       = function() return fetch("Utils")        end,
    Teleport    = function() return fetch("Teleport")     end,
    MultiPacket = function() return fetch("MultiPacket")  end,
}

-- __index: resolve lazy getter or sub-module on first access,
-- then pin the value directly onto NX so future accesses skip the metatable.
_mt.__index = function(t, key)
    local getter = _map[key]
    if getter then
        local val = getter()
        rawset(t, key, val)   -- pin: next access is direct, no __index
        return val
    end
end

_mt.__newindex = function(t, k, v)
    rawset(t, k, v)
end

setmetatable(NX, _mt)

-- ── NX.Init ───────────────────────────────────────────────────────────────
function NX.Init(cfg)
    cfg = cfg or {}

    -- Apply config
    local Config = fetch("Config")
    Config.Apply(cfg)

    -- Start all systems in dependency order
    local SmoothBuf = fetch("SmoothBuf") ; SmoothBuf.Start()
    local Network   = fetch("Network")   ; Network.Start()
    local Console   = fetch("Console")   ; Console.Start()
    local Inventory = fetch("Inventory") ; Inventory.Start()
    local PlayerAPI = fetch("PlayerAPI") ; PlayerAPI.Start()
    local World     = fetch("World")     ; World.Start()

    -- Optional systems (no Start() needed)
    fetch("Scheduler")
    fetch("Teleport")
    fetch("MultiPacket")

    -- Pin all resolved values so NX table is flat after Init
    for key, getter in pairs(_map) do
        if not rawget(NX, key) then
            local ok, val = pcall(getter)
            if ok and val ~= nil then rawset(NX, key, val) end
        end
    end

    if cfg.SmoothBuf ~= nil then
        fetch("SmoothBuf").SetSmoothBuf(cfg.SmoothBuf)
    end
end

-- ── NX.SetSmoothBuf ───────────────────────────────────────────────────────
function NX.SetSmoothBuf(enabled)
    fetch("SmoothBuf").SetSmoothBuf(enabled)
end

NX.VERSION  = "3.0.0"

-- ── Bootstrap ─────────────────────────────────────────────────────────────
bootstrap()

-- Expose globally
getgenv().NX = NX

-- Auto-init with defaults if caller doesn't call Init()
-- (silent — no console spam)
task.defer(function()
    if not rawget(NX, "SendPkt") then
        NX.Init({})
    end
end)
