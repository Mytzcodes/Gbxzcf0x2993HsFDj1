--[[
    NXroENinD_DPcKage — GitHub Lazy Loader v3.1 (Fixed)
    Repo   : https://github.com/Mytzcodes/Gbxzcf0x2993HsFDj1
    Branch : main
    Folder : Framework_C8&d0ScRR/

    Paste this ONE script into your executor. NX becomes a global.

    Usage after loading:
        NX.Init({ SmoothBuf = true })
        NX.ConsoleMsg("Ready!", "green")
        print(NX.Player().name)
]]

-- ── 1. RAW BASE URL (folder tempat semua .lua module berada) ─────────────
local RAW_BASE = "https://raw.githubusercontent.com/Mytzcodes/Gbxzcf0x2993HsFDj1/refs/heads/main/Framework_C8%26d0ScRR"

-- ── 2. URL per-modul ─────────────────────────────────────────────────────
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

-- ── 3. Module cache & loader ──────────────────────────────────────────────
local _cache   = {}
local _loading = {}

--[[
    FIX UTAMA:
    Modul asli memakai  require(script.Parent.Events)
    Di executor, 'script' = nil  → evaluasi 'script.Parent' langsung crash
    sebelum 'require' dipanggil.

    Solusi: Injeksi fake 'script' ke environment modul.
      • script.Parent.<nama>  →  __index mengembalikan modul yang sudah ada
                                  di cache (atau mem-fetch-nya).
      • require(ref)          →  Jika ref sudah berupa table modul (hasil
                                  __index di atas), langsung return.
                                  Jika string/Instance, extract nama terakhir.
]]
local function makeFakeScript(currentName)
    -- Fake script.Parent: tiap field access mengembalikan modul dari cache
    local fakeParent = setmetatable({}, {
        __index = function(_, key)
            -- dipanggil saat modul tulis: script.Parent.Events  dll.
            if _cache[key] then return _cache[key] end
            -- Kalau belum ada di cache, fetch sekarang (dependency pull)
            -- (akan blocking, tapi ini rare — dependency biasanya sudah ada)
            local ok, result = pcall(function()
                -- forward declare fetch dipakai di sini via upvalue closure
                return _cache[key]      -- cek cache lagi setelah wait
            end)
            return result
        end,
    })

    local fakeScript = {
        Name   = currentName,
        Parent = fakeParent,
    }
    return fakeScript
end

-- Forward-declare fetch agar bisa dipakai di dalam closure di atas
local fetch   -- assigned below

local function makeEnv(moduleName)
    -- Base: semua global Roblox tetap accessible
    local base = getfenv and getfenv(0) or _G
    local env  = setmetatable({}, { __index = base })

    -- Inject fake script
    env.script = makeFakeScript(moduleName)

    -- Inject require shim
    env.require = function(ref)
        -- Kasus 1: ref sudah berupa table (hasil script.Parent.X)
        --          → langsung return, sudah modul siap pakai
        if type(ref) == "table" then
            return ref
        end

        -- Kasus 2: ref adalah string langsung ("Events" dll.)
        if type(ref) == "string" then
            local name = ref:match("%.(%w+)$") or ref
            return fetch(name)
        end

        -- Kasus 3: Roblox Instance (saat dijalankan di dalam game, bukan executor)
        local asStr = tostring(ref)
        local name  = asStr:match("%.(%w+)$") or asStr
        return fetch(name)
    end

    return env
end

-- Implementasi fetch yang sesungguhnya
fetch = function(name)
    -- Sudah ada di cache → langsung return
    if _cache[name] then return _cache[name] end

    -- Sedang di-fetch oleh coroutine lain → tunggu
    if _loading[name] then
        while _loading[name] do task.wait(0.01) end
        return _cache[name]
    end

    local url = URLS[name]
    if not url then
        error("[NXroENinD_DPcKage] Modul tidak dikenal: '" .. tostring(name) .. "'", 2)
    end

    _loading[name] = true

    -- Download source dari GitHub
    local httpOk, src = pcall(function()
        return game:HttpGet(url, true)
    end)
    if not httpOk then
        _loading[name] = false
        error(string.format("[NXroENinD_DPcKage] Gagal download '%s'\nURL: %s\nError: %s",
            name, url, tostring(src)), 2)
    end

    -- Compile
    local chunk, compileErr = loadstring(src, "NXroENinD_DPcKage." .. name)
    if not chunk then
        _loading[name] = false
        error(string.format("[NXroENinD_DPcKage] Compile error di '%s': %s", name, tostring(compileErr)), 2)
    end

    -- Inject environment (fix script.Parent & require)
    local env = makeEnv(name)
    if setfenv then
        -- Tersedia di executor Lua 5.1 / Synapse / KRNL dll.
        setfenv(chunk, env)
    end
    -- Di Luau murni (setfenv tidak ada), modul perlu dijalankan di lingkungan
    -- executor yang sudah memiliki require global — env masih dipakai untuk
    -- script injection via upvalue jika executor mendukung.

    -- Eksekusi
    local ok, result = pcall(chunk)
    _loading[name] = false

    if not ok then
        error(string.format("[NXroENinD_DPcKage] Runtime error di '%s': %s", name, tostring(result)), 2)
    end

    _cache[name] = result
    return result
end

-- ── 4. Bootstrap — load fondasi (zero-dep) secara eager ─────────────────
-- Events, Config, Utils tidak memiliki dependency → load duluan
-- agar modul lain bisa langsung pakai dari cache saat require(script.Parent.Events)
local function bootstrap()
    local function safeLoad(name)
        local ok, err = pcall(fetch, name)
        if not ok then
            warn("[NXroENinD_DPcKage] Bootstrap gagal load '" .. name .. "': " .. tostring(err))
        end
    end
    safeLoad("Events")
    safeLoad("Config")
    safeLoad("Utils")
end

-- ── 5. Tabel NX — Lazy Proxy ─────────────────────────────────────────────
local NX = {}

local _map = {
    -- Network
    SendPkt      = function() return fetch("Network").SendPkt      end,
    SendRaw      = function() return fetch("Network").SendRaw      end,
    HookPkt      = function() return fetch("Network").HookPkt      end,
    UnhookPkt    = function() return fetch("Network").UnhookPkt    end,
    -- Player
    Player       = function() return fetch("PlayerAPI").Player     end,
    -- Console
    ConsoleMsg   = function() return fetch("Console").ConsoleMsg   end,
    ConsoleLog   = function() return fetch("Console").Log          end,
    ConsoleClear = function() return fetch("Console").Clear        end,
    -- Inventory
    GetInvent    = function() return fetch("Inventory").GetInvent  end,
    FindItem     = function() return fetch("Inventory").FindItem   end,
    FindAllItems = function() return fetch("Inventory").FindAllItems end,
    CountItem    = function() return fetch("Inventory").CountItem  end,
    HasItem      = function() return fetch("Inventory").HasItem    end,
    GetEquipped  = function() return fetch("Inventory").GetEquipped end,
    GetByType    = function() return fetch("Inventory").GetByType  end,
    -- World
    GetWorld     = function() return fetch("World").GetWorld       end,
    GetTile      = function() return fetch("World").GetTile        end,
    FindTiles    = function() return fetch("World").FindTiles      end,
    TileAt       = function() return fetch("World").TileAt         end,
    -- Scheduler
    After        = function() return fetch("Scheduler").After      end,
    Every        = function() return fetch("Scheduler").Every      end,
    Cancel       = function() return fetch("Scheduler").Cancel     end,
    NextFrame    = function() return fetch("Scheduler").NextFrame  end,
    -- Teleport
    FindPath     = function() return fetch("Teleport").FindPath    end,
    CancelWalk   = function() return fetch("Teleport").CancelWalk  end,
    -- MultiPacket
    SendMulti    = function() return fetch("MultiPacket").SendMulti    end,
    SendChain    = function() return fetch("MultiPacket").SendChain    end,
    SendIf       = function() return fetch("MultiPacket").SendIf       end,
    DefineMacro  = function() return fetch("MultiPacket").DefineMacro  end,
    RunMacro     = function() return fetch("MultiPacket").RunMacro     end,
    -- Sub-modul langsung
    SmoothBuf    = function() return fetch("SmoothBuf")    end,
    Events       = function() return fetch("Events")        end,
    Config       = function() return fetch("Config")        end,
    Utils        = function() return fetch("Utils")         end,
    Teleport     = function() return fetch("Teleport")      end,
    MultiPacket  = function() return fetch("MultiPacket")   end,
}

setmetatable(NX, {
    __index = function(t, key)
        local getter = _map[key]
        if getter then
            local ok, val = pcall(getter)
            if ok and val ~= nil then
                rawset(t, key, val)   -- pin → akses berikutnya direct
                return val
            end
        end
    end,
    __newindex = function(t, k, v)
        rawset(t, k, v)
    end,
})

-- ── 6. NX.Init ───────────────────────────────────────────────────────────
function NX.Init(cfg)
    cfg = cfg or {}

    -- Apply config
    fetch("Config").Apply(cfg)

    -- Start semua sistem dalam urutan dependency yang benar
    local loadOrder = {
        "SmoothBuf", "Network", "Console",
        "Inventory", "PlayerAPI", "World",
        "Scheduler", "Teleport", "MultiPacket"
    }

    for _, name in ipairs(loadOrder) do
        local ok, mod = pcall(fetch, name)
        if ok and mod then
            if type(mod.Start) == "function" then
                local startOk, startErr = pcall(mod.Start)
                if not startOk then
                    warn("[NXroENinD_DPcKage] Start() error di " .. name .. ": " .. tostring(startErr))
                end
            end
            -- Pin ke NX
            for key, getter in pairs(_map) do
                if not rawget(NX, key) then
                    local gok, val = pcall(getter)
                    if gok and val ~= nil then rawset(NX, key, val) end
                end
            end
        else
            warn("[NXroENinD_DPcKage] Gagal load modul: " .. name .. " — " .. tostring(mod))
        end
    end

    -- SmoothBuf toggle
    if cfg.SmoothBuf ~= nil then
        local sb = _cache["SmoothBuf"]
        if sb then sb.SetSmoothBuf(cfg.SmoothBuf) end
    end

    NX._initialized = true
end

function NX.SetSmoothBuf(enabled)
    local sb = _cache["SmoothBuf"] or fetch("SmoothBuf")
    sb.SetSmoothBuf(enabled)
end

NX.VERSION = "3.1.0"

-- ── 7. Expose global & bootstrap ─────────────────────────────────────────
bootstrap()

-- Daftarkan NX ke global environment executor
local function setGlobal(key, val)
    if getgenv then
        getgenv()[key] = val          -- Synapse, KRNL, Script-Ware, dll.
    elseif syn and syn.set_thread_identity then
        getfenv(0)[key] = val         -- Synapse X fallback
    else
        _G[key] = val                 -- Universal fallback
    end
end

setGlobal("NX", NX)

print("[NXroENinD_DPcKage] v" .. NX.VERSION .. " Loader berhasil. Panggil NX.Init() untuk mulai.")
