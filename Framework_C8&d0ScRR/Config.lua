--[[
╔══════════════════════════════════════════════════════════════════════════╗
║  NXroENinD_DPcKage.Config — Runtime Configuration Store                         ║
╚══════════════════════════════════════════════════════════════════════════╝
  Stores all framework settings. Apply user config via Init().
--]]

local Config = {}

-- ──────────────────────────────────────────────
--  Defaults
-- ──────────────────────────────────────────────
local _defaults = {
    SmoothBuf       = true,       -- Packet batching enabled
    FlushRate       = 1,          -- Flush every N frames
    LogLevel        = 1,          -- 0=off 1=info 2=debug 3=verbose
    AutoCollect     = false,      -- Auto-collect dropped items
    PacketLogger    = false,      -- Log all packets to console
    SpeedMultiplier = 1.0,        -- Movement speed (1.0 = default)
    AntiKick        = false,      -- Anti-kick protection
    AutoFarm        = false,      -- Auto-farming mode
    GhostMode       = false,      -- Ghost / noclip
    ConsolePrefix   = "[NXroENinD_DPcKage]",
}

local _store = {}

-- ──────────────────────────────────────────────
--  API
-- ──────────────────────────────────────────────

function Config.Apply(userConfig)
    -- Start from defaults
    for k, v in pairs(_defaults) do
        _store[k] = v
    end
    -- Overlay user values
    if type(userConfig) == "table" then
        for k, v in pairs(userConfig) do
            _store[k] = v
        end
    end
end

function Config.Get(key)
    return _store[key]
end

function Config.Set(key, value)
    _store[key] = value
end

function Config.GetAll()
    return table.clone(_store)
end

function Config.Reset()
    Config.Apply({})
end

-- Bootstrap defaults immediately
Config.Apply({})

return Config
