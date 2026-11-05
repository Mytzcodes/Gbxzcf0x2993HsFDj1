-- NXroENinD_DPcKage.Config
-- Runtime configuration store. No external dependencies.

local Config = {}

local _defaults = {
    SmoothBuf       = true,
    FlushRate       = 1,
    LogLevel        = 1,
    AutoCollect     = false,
    PacketLogger    = false,
    SpeedMultiplier = 1.0,
    AntiKick        = false,
    AutoFarm        = false,
    GhostMode       = false,
    ConsolePrefix   = "[NXroENinD_DPcKage]",
}

local _store = {}

function Config.Apply(userConfig)
    for k, v in pairs(_defaults) do _store[k] = v end
    if type(userConfig) == "table" then
        for k, v in pairs(userConfig) do _store[k] = v end
    end
end

function Config.Get(key)   return _store[key] end
function Config.Set(k, v)  _store[k] = v end
function Config.GetAll()   return table.clone(_store) end
function Config.Reset()    Config.Apply({}) end

Config.Apply({})
return Config
