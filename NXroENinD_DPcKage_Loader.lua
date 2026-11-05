--[[
    NXroENinD_DPcKage — GitHub Loader v5.0
    Repo   : https://github.com/Mytzcodes/Gbxzcf0x2993HsFDj1
    Branch : main
    Folder : Framework_C8&d0ScRR/

    ONE script. Run it in your executor. NX becomes a global.

    Usage:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Mytzcodes/Gbxzcf0x2993HsFDj1/refs/heads/main/NXroENinD_DPcKage_Loader.lua"))()
        NX.Init()
        NX.ConsoleMsg("Ready!", "green")
        NX.FindPath(44, 37)         -- teleport to tile 44,37
        NX.FindPath(44, 37, 2)      -- walk with A* pathfinding
        NX.SendChat("hello world")  -- send chat message
        print(NX.Player().name)     -- player IGN (GameName)

    v5.0 Fixes:
        - Console: uses BitmapText module for proper chat injection
        - Network: chat via TextChatService.WorldChannels:SendAsync()
        - Teleport: NO coordinate multiplier (raw tile coords)
        - World: TILE_SIZE removed from TileAt()
        - PlayerAPI: GameName polling + net.entered hook
        - Inventory: net.inventorySync hook
        - All modules: fully nil-guarded Start()
]]

-- ── 1. URLs ──────────────────────────────────────────────────────────────────

local RAW_BASE = "https://raw.githubusercontent.com/Mytzcodes/Gbxzcf0x2993HsFDj1/refs/heads/main/Framework_C8%26d0ScRR"

local MODULE_URLS = {
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

local LOAD_ORDER = {
    "Events", "Config", "Utils",
    "SmoothBuf", "Console",
    "Network", "PlayerAPI", "Inventory", "World",
    "Scheduler", "Teleport", "MultiPacket",
}

-- ── 2. Load all modules ───────────────────────────────────────────────────────

local M = {}

for _, name in ipairs(LOAD_ORDER) do
    local url = MODULE_URLS[name]
    local ok, result = pcall(function()
        local src = game:HttpGet(url)
        if not src or src == "" then
            error("Empty response from: " .. url)
        end
        local fn, compErr = loadstring(src)
        if not fn then
            error("Compile error in " .. name .. ": " .. tostring(compErr))
        end
        return fn()
    end)

    if ok and type(result) == "table" then
        M[name] = result
        print("[NX] Loaded: " .. name)
    else
        warn("[NX] FAILED: " .. name .. " — " .. tostring(result))
        M[name] = {}  -- empty stub so other modules don't crash
    end
end

-- ── 3. Wire dependencies ─────────────────────────────────────────────────────
-- Each module's Start() receives its deps explicitly (no require() internally).

local ev  = M.Events
local sb  = M.SmoothBuf
local net = M.Network
local pa  = M.PlayerAPI
local inv = M.Inventory
local wld = M.World
local mp  = M.MultiPacket
local con = M.Console
local tel = M.Teleport

local function safeStart(name, mod, ...)
    if type(mod) ~= "table" then return end
    if type(mod.Start) ~= "function" then return end
    local ok, err = pcall(mod.Start, ...)
    if not ok then
        warn("[NX] Start() error in " .. name .. ": " .. tostring(err))
    end
end

-- Order: deps first
safeStart("SmoothBuf",   sb,  ev)
safeStart("Network",     net, sb, ev)
safeStart("Console",     con, ev)        -- Console after Network so toast UI inits
safeStart("PlayerAPI",   pa,  ev)
safeStart("Inventory",   inv, ev)
safeStart("World",       wld, ev)
safeStart("Teleport",    tel, ev, net, wld, pa, con)
safeStart("MultiPacket", mp,  net, sb, ev)

-- ── 4. Build NX global ───────────────────────────────────────────────────────

local NX = {}
NX.VERSION = "5.0.0"

function NX.Init(cfg)
    cfg = cfg or {}
    if type(M.Config.Apply) == "function" then
        M.Config.Apply(cfg)
    end
    if cfg.SmoothBuf ~= nil and type(sb.SetSmoothBuf) == "function" then
        sb.SetSmoothBuf(cfg.SmoothBuf)
    end
    if cfg.LogLevel ~= nil and type(con.SetLogLevel) == "function" then
        con.SetLogLevel(cfg.LogLevel)
    end
    NX._initialized = true
    -- Welcome message — visual in-game
    if type(con.ConsoleMsg) == "function" then
        con.ConsoleMsg("NXroENinD v" .. NX.VERSION .. " siap!", "green")
    end
end

-- ── Network ────────────────────────────────────────────────────────────────

function NX.SendPkt(ref, data)      return net.SendPkt and net.SendPkt(ref, data)      end
function NX.SendRaw(buf)            return net.SendRaw and net.SendRaw(buf)             end
function NX.SendChat(msg, ch)       return net.SendChat and net.SendChat(msg, ch)       end
function NX.Call(name, ...)         return net.Call and net.Call(name, ...)             end
function NX.HookPkt(ref, fn)        return net.HookPkt and net.HookPkt(ref, fn)        end
function NX.UnhookPkt(h)            return net.UnhookPkt and net.UnhookPkt(h)          end

-- ── Console ────────────────────────────────────────────────────────────────

function NX.ConsoleMsg(text, color) return con.ConsoleMsg and con.ConsoleMsg(text, color) end
function NX.ConsoleLog(text, lv)    return con.Log and con.Log(text, lv)                  end
function NX.ConsoleClear()          return con.Clear and con.Clear()                      end
function NX.Notify(text, dur)       return con.Notify and con.Notify(text, dur)           end

-- ── Player ─────────────────────────────────────────────────────────────────

function NX.Player()                return pa.Player and pa.Player()       end
function NX.RequestName()           return pa.RequestName and pa.RequestName() or "..." end

-- ── Inventory ──────────────────────────────────────────────────────────────

function NX.GetInvent()             return inv.GetInvent and inv.GetInvent()             end
function NX.FindItem(q)             return inv.FindItem and inv.FindItem(q)              end
function NX.FindAllItems(q)         return inv.FindAllItems and inv.FindAllItems(q)      end
function NX.CountItem(q)            return inv.CountItem and inv.CountItem(q)            end
function NX.HasItem(q, n)           return inv.HasItem and inv.HasItem(q, n)             end
function NX.GetEquipped()           return inv.GetEquipped and inv.GetEquipped()         end
function NX.GetByType(t)            return inv.GetByType and inv.GetByType(t)           end

-- ── World ──────────────────────────────────────────────────────────────────

function NX.GetWorld()              return wld.GetWorld and wld.GetWorld()               end
function NX.GetTile(x, y)          return wld.GetTile and wld.GetTile(x, y)             end
function NX.FindTiles(pred)         return wld.FindTiles and wld.FindTiles(pred)         end
function NX.TileAt(pos)             return wld.TileAt and wld.TileAt(pos)                end

-- ── Scheduler ──────────────────────────────────────────────────────────────

function NX.After(s, fn)            return M.Scheduler.After and M.Scheduler.After(s, fn)    end
function NX.Every(s, fn)            return M.Scheduler.Every and M.Scheduler.Every(s, fn)    end
function NX.Cancel(h)               return M.Scheduler.Cancel and M.Scheduler.Cancel(h)      end
function NX.NextFrame(fn)           return M.Scheduler.NextFrame and M.Scheduler.NextFrame(fn) end
function NX.CancelAll()             return M.Scheduler.CancelAll and M.Scheduler.CancelAll()  end

-- ── Teleport ───────────────────────────────────────────────────────────────

function NX.FindPath(x, y, m, cb)   return tel.FindPath and tel.FindPath(x, y, m, cb)   end
function NX.CancelWalk()             return tel.CancelWalk and tel.CancelWalk()           end

-- ── MultiPacket ────────────────────────────────────────────────────────────

function NX.SendMulti(...)          return mp.SendMulti and mp.SendMulti(...)            end
function NX.SendChain(steps)        return mp.SendChain and mp.SendChain(steps)          end
function NX.DefineMacro(n, s)       return mp.DefineMacro and mp.DefineMacro(n, s)       end
function NX.RunMacro(n, o)          return mp.RunMacro and mp.RunMacro(n, o)             end

-- ── SmoothBuf ──────────────────────────────────────────────────────────────

function NX.SetSmoothBuf(e)         return sb.SetSmoothBuf and sb.SetSmoothBuf(e)        end
function NX.FlushBuf()              return sb.Flush and sb.Flush()                        end

-- ── Sub-module direct access ───────────────────────────────────────────────

NX.Events      = ev
NX.Config      = M.Config
NX.Utils       = M.Utils
NX.SmoothBuf   = sb
NX.Network     = net
NX.Console     = con
NX.PlayerAPI   = pa
NX.Inventory   = inv
NX.World       = wld
NX.Scheduler   = M.Scheduler
NX.Teleport    = tel
NX.MultiPacket = mp

-- ── 5. Register global ────────────────────────────────────────────────────────

local function setGlobal(key, val)
    if getgenv then getgenv()[key] = val end
    if getfenv then pcall(function() getfenv(0)[key] = val end) end
    _G[key] = val
end

setGlobal("NX", NX)

print("[NXroENinD_DPcKage] v" .. NX.VERSION .. " loaded. Panggil NX.Init() untuk mulai.")
print("[NX] Tips: NX.FindPath(x, y) | NX.SendChat('msg') | NX.Player().name")
