--[[
    NXroENinD_DPcKage — GitHub Loader v4.1
    Repo   : https://github.com/Mytzcodes/Gbxzcf0x2993HsFDj1
    Branch : main
    Folder : Framework_C8&d0ScRR/

    ONE script. Run it in your executor. NX becomes a global.

    Usage:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Mytzcodes/Gbxzcf0x2993HsFDj1/refs/heads/main/NXroENinD_DPcKage_Loader.lua"))()
        NX.Init({ SmoothBuf = true })
        NX.ConsoleMsg("Ready!", "green")
        print(NX.Player().name)
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
-- Each module's Start() receives its deps explicitly.
-- This is the ONLY correct way — do NOT call Start() without args.

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

-- Order matters: deps first
safeStart("SmoothBuf",   sb,  ev)
safeStart("Network",     net, sb, ev)
safeStart("Console",     con, ev)
safeStart("PlayerAPI",   pa,  ev)
safeStart("Inventory",   inv, ev)
safeStart("World",       wld, ev)
safeStart("Teleport",    tel, ev, net, wld, pa, con)
safeStart("MultiPacket", mp,  net, sb, ev)

-- ── 4. Build NX ──────────────────────────────────────────────────────────────

local NX = {}
NX.VERSION = "4.1.0"

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
    print("[NXroENinD_DPcKage] v" .. NX.VERSION .. " ready.")
end

-- Network
function NX.SendPkt(ref, data)      return net.SendPkt(ref, data)      end
function NX.SendRaw(buf)            return net.SendRaw(buf)             end
function NX.HookPkt(ref, fn)        return net.HookPkt(ref, fn)        end
function NX.UnhookPkt(handle)       return net.UnhookPkt(handle)       end

-- Console
function NX.ConsoleMsg(text, color) return con.ConsoleMsg(text, color) end
function NX.ConsoleLog(text, level) return con.Log(text, level)        end
function NX.ConsoleClear()          return con.Clear()                  end
function NX.Notify(text, duration)  return con.Notify(text, duration)  end

-- Player
function NX.Player()                return pa.Player()                  end
function NX.RequestName()           return pa.RequestName and pa.RequestName() or "..." end

-- Inventory
function NX.GetInvent()             return inv.GetInvent()              end
function NX.FindItem(q)             return inv.FindItem(q)              end
function NX.FindAllItems(q)         return inv.FindAllItems(q)          end
function NX.CountItem(q)            return inv.CountItem(q)             end
function NX.HasItem(q, n)           return inv.HasItem(q, n)           end
function NX.GetEquipped()           return inv.GetEquipped()            end
function NX.GetByType(t)            return inv.GetByType(t)             end

-- World
function NX.GetWorld()              return wld.GetWorld()               end
function NX.GetTile(x, y)           return wld.GetTile(x, y)           end
function NX.FindTiles(pred)         return wld.FindTiles(pred)          end
function NX.TileAt(pos)             return wld.TileAt(pos)              end

-- Scheduler
function NX.After(s, fn)            return M.Scheduler.After(s, fn)    end
function NX.Every(s, fn)            return M.Scheduler.Every(s, fn)    end
function NX.Cancel(h)               return M.Scheduler.Cancel(h)       end
function NX.NextFrame(fn)           return M.Scheduler.NextFrame(fn)   end
function NX.CancelAll()             return M.Scheduler.CancelAll()      end

-- Teleport
function NX.FindPath(x, y, m, cb)   return tel.FindPath(x, y, m, cb)  end
function NX.CancelWalk()             return tel.CancelWalk()            end

-- MultiPacket
function NX.SendMulti(...)          return mp.SendMulti(...)            end
function NX.SendChain(steps)        return mp.SendChain(steps)          end
function NX.SendIf(c, t, e)         return mp.SendIf(c, t, e)          end
function NX.DefineMacro(n, s)       return mp.DefineMacro(n, s)        end
function NX.RunMacro(n, o)          return mp.RunMacro(n, o)           end
function NX.BuyAndPlace(...)        return mp.BuyAndPlace(...)          end
function NX.BuySellArbitrage(...)   return mp.BuySellArbitrage(...)     end
function NX.EquipAndUse(...)        return mp.EquipAndUse(...)          end
function NX.CraftAndWear(...)       return mp.CraftAndWear(...)         end
function NX.PlaceRow(...)           return mp.PlaceRow(...)             end
function NX.BreakRect(...)          return mp.BreakRect(...)            end
function NX.FriendAndChat(...)      return mp.FriendAndChat(...)        end
function NX.TradeAndConfirm(...)    return mp.TradeAndConfirm(...)      end

-- SmoothBuf
function NX.SetSmoothBuf(enabled)   return sb.SetSmoothBuf(enabled)    end
function NX.FlushBuf()              return sb.Flush()                   end

-- Sub-module direct access
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

-- ── 5. Register global ───────────────────────────────────────────────────────

local function setGlobal(key, val)
    if getgenv then getgenv()[key] = val end
    if getfenv then pcall(function() getfenv(0)[key] = val end) end
    _G[key] = val
end

setGlobal("NX", NX)

print("[NXroENinD_DPcKage] v" .. NX.VERSION .. " loaded. Panggil NX.Init() untuk mulai.")
