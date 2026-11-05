--[[
  ╔══════════════════════════════════════════════════════════════════╗
  ║   NXroENinD_DPcKage — GitHub Loader v5.1                       ║
  ║   Repo   : https://github.com/Mytzcodes/Gbxzcf0x2993HsFDj1     ║
  ║   Branch : main  |  Folder : Framework_C8&d0ScRR/              ║
  ╠══════════════════════════════════════════════════════════════════╣
  ║  loadstring(game:HttpGet("... /NXroENinD_DPcKage_Loader.lua"))()║
  ║  NX.Init()                                                      ║
  ╠══════════════════════════════════════════════════════════════════╣
  ║  v5.1 Changes:                                                  ║
  ║   + Godmode   (NX.GodmodeOn/Off/Toggle)                        ║
  ║   + Camera    (NX.SetZoom / ZoomIn / ZoomOut / LockCamera)     ║
  ║   + Fly       (NX.FlyOn/Off/Toggle / SetFlySpeed)              ║
  ║   + Nametag   (NX.SetNametag / RemoveNametag / UpdateNametag)  ║
  ║   + ModDetect (NX.ModWatch / ModWatchOff / IsModPresent)       ║
  ║   + FastSpin  (NX.FastSpin / AutoSpin / StopAutoSpin)          ║
  ║   + Scheduler.PauseAll / ResumeAll for ModDetect               ║
  ║   + Network: no warn spam for move packets (Fly fix)           ║
  ║   + Teleport: multi-attempt + approach for far TP              ║
  ╚══════════════════════════════════════════════════════════════════╝
]]

-- ── 1. URLs ──────────────────────────────────────────────────────────────────

local RAW_BASE = "https://raw.githubusercontent.com/Mytzcodes/Gbxzcf0x2993HsFDj1/refs/heads/main/Framework_C8%26d0ScRR"

local MODULE_URLS = {
    -- Core
    Events      = RAW_BASE .. "/Events.lua",
    Config      = RAW_BASE .. "/Config.lua",
    Utils       = RAW_BASE .. "/Utils.lua",
    SmoothBuf   = RAW_BASE .. "/SmoothBuf.lua",
    Console     = RAW_BASE .. "/Console.lua",
    -- Net & Players
    Network     = RAW_BASE .. "/Network.lua",
    PlayerAPI   = RAW_BASE .. "/PlayerAPI.lua",
    Inventory   = RAW_BASE .. "/Inventory.lua",
    World       = RAW_BASE .. "/World.lua",
    -- Tools
    Scheduler   = RAW_BASE .. "/Scheduler.lua",
    Teleport    = RAW_BASE .. "/Teleport.lua",
    MultiPacket = RAW_BASE .. "/MultiPacket.lua",
    -- New v5.1
    Godmode     = RAW_BASE .. "/Godmode.lua",
    Camera      = RAW_BASE .. "/Camera.lua",
    Fly         = RAW_BASE .. "/Fly.lua",
    Nametag     = RAW_BASE .. "/Nametag.lua",
    ModDetect   = RAW_BASE .. "/ModDetect.lua",
    FastSpin    = RAW_BASE .. "/FastSpin.lua",
}

local LOAD_ORDER = {
    "Events", "Config", "Utils",
    "SmoothBuf", "Console",
    "Network", "PlayerAPI", "Inventory", "World",
    "Scheduler", "Teleport", "MultiPacket",
    "Godmode", "Camera", "Fly", "Nametag", "ModDetect", "FastSpin",
}

-- ── 2. Load all modules ───────────────────────────────────────────────────────

local M = {}

for _, name in ipairs(LOAD_ORDER) do
    local url = MODULE_URLS[name]
    local ok, result = pcall(function()
        local src = game:HttpGet(url)
        if not src or src == "" then
            error("Empty response: " .. url)
        end
        local fn, compErr = loadstring(src)
        if not fn then
            error("Compile error in " .. name .. ": " .. tostring(compErr))
        end
        return fn()
    end)

    if ok and type(result) == "table" then
        M[name] = result
    else
        warn("[NX] FAILED: " .. name .. " — " .. tostring(result))
        M[name] = {}
    end
end

-- ── 3. Wire dependencies ─────────────────────────────────────────────────────

local ev  = M.Events
local sb  = M.SmoothBuf
local net = M.Network
local pa  = M.PlayerAPI
local inv = M.Inventory
local wld = M.World
local mp  = M.MultiPacket
local con = M.Console
local tel = M.Teleport
local sch = M.Scheduler
local gm  = M.Godmode
local cam = M.Camera
local fly = M.Fly
local nt  = M.Nametag
local md  = M.ModDetect
local fs  = M.FastSpin

local function safeStart(name, mod, ...)
    if type(mod) ~= "table" then return end
    if type(mod.Start) ~= "function" then return end
    local ok, err = pcall(mod.Start, ...)
    if not ok then
        warn("[NX] Start() error in " .. name .. ": " .. tostring(err))
    end
end

-- Order: core deps first, then features
safeStart("SmoothBuf",   sb,  ev)
safeStart("Network",     net, sb, ev)
safeStart("Console",     con, ev)
safeStart("PlayerAPI",   pa,  ev)
safeStart("Inventory",   inv, ev)
safeStart("World",       wld, ev)
safeStart("Scheduler",   sch)       -- no deps
safeStart("Teleport",    tel, ev, net, wld, pa, con)
safeStart("MultiPacket", mp,  net, sb, ev)
-- v5.1 modules
safeStart("Godmode",   gm,  ev, con, net)
safeStart("Camera",    cam, ev, con)
safeStart("Fly",       fly, ev, con, net, pa)
safeStart("Nametag",   nt,  ev, con)
safeStart("ModDetect", md,  ev, con, net, sch)
safeStart("FastSpin",  fs,  ev, con)

-- ── 4. Build NX global ───────────────────────────────────────────────────────

local NX = {}
NX.VERSION = "5.1.0"

function NX.Init(cfg)
    cfg = cfg or {}
    if type(M.Config) == "table" and type(M.Config.Apply) == "function" then
        M.Config.Apply(cfg)
    end
    if cfg.SmoothBuf ~= nil and type(sb.SetSmoothBuf) == "function" then
        sb.SetSmoothBuf(cfg.SmoothBuf)
    end
    if cfg.LogLevel ~= nil and type(con.SetLogLevel) == "function" then
        con.SetLogLevel(cfg.LogLevel)
    end
    NX._initialized = true
    if type(con.ConsoleMsg) == "function" then
        con.ConsoleMsg("NXroENinD v" .. NX.VERSION .. " siap! ✨", "green")
        con.ConsoleMsg("TP·Fly·Godmode·Zoom·Nametag·ModWatch·FastSpin", "cyan")
    end
end

-- ── Network ────────────────────────────────────────────────────────────────

function NX.SendPkt(ref, data)      return net.SendPkt  and net.SendPkt(ref, data)      end
function NX.SendRaw(buf)            return net.SendRaw   and net.SendRaw(buf)             end
function NX.SendChat(msg, ch)       return net.SendChat  and net.SendChat(msg, ch)        end
function NX.Call(name, ...)         return net.Call      and net.Call(name, ...)          end
function NX.HookPkt(ref, fn)        return net.HookPkt   and net.HookPkt(ref, fn)         end
function NX.UnhookPkt(h)            return net.UnhookPkt and net.UnhookPkt(h)             end

-- ── Console ────────────────────────────────────────────────────────────────

function NX.ConsoleMsg(text, color) return con.ConsoleMsg and con.ConsoleMsg(text, color) end
function NX.ConsoleLog(text, lv)    return con.Log        and con.Log(text, lv)           end
function NX.ConsoleClear()          return con.Clear      and con.Clear()                 end
function NX.Notify(text, dur)       return con.Notify     and con.Notify(text, dur)       end

-- ── Player ─────────────────────────────────────────────────────────────────

function NX.Player()                return pa.Player      and pa.Player()                 end
function NX.RequestName()           return pa.RequestName and pa.RequestName() or "..."   end

-- ── Inventory ──────────────────────────────────────────────────────────────

function NX.GetInvent()             return inv.GetInvent   and inv.GetInvent()            end
function NX.FindItem(q)             return inv.FindItem    and inv.FindItem(q)             end
function NX.FindAllItems(q)         return inv.FindAllItems and inv.FindAllItems(q)        end
function NX.CountItem(q)            return inv.CountItem   and inv.CountItem(q)            end
function NX.HasItem(q, n)           return inv.HasItem     and inv.HasItem(q, n)           end
function NX.GetEquipped()           return inv.GetEquipped and inv.GetEquipped()           end
function NX.GetByType(t)            return inv.GetByType   and inv.GetByType(t)            end

-- ── World ──────────────────────────────────────────────────────────────────

function NX.GetWorld()              return wld.GetWorld   and wld.GetWorld()              end
function NX.GetTile(x, y)          return wld.GetTile    and wld.GetTile(x, y)           end
function NX.FindTiles(pred)         return wld.FindTiles  and wld.FindTiles(pred)         end
function NX.TileAt(pos)             return wld.TileAt     and wld.TileAt(pos)             end

-- ── Scheduler ──────────────────────────────────────────────────────────────

function NX.After(s, fn)            return sch.After      and sch.After(s, fn)            end
function NX.Every(s, fn)            return sch.Every      and sch.Every(s, fn)            end
function NX.Cancel(h)               return sch.Cancel     and sch.Cancel(h)               end
function NX.NextFrame(fn)           return sch.NextFrame  and sch.NextFrame(fn)           end
function NX.CancelAll()             return sch.CancelAll  and sch.CancelAll()             end
function NX.PauseAll()              return sch.PauseAll   and sch.PauseAll()              end
function NX.ResumeAll()             return sch.ResumeAll  and sch.ResumeAll()             end

-- ── Teleport ───────────────────────────────────────────────────────────────

function NX.FindPath(x, y, m, cb)   return tel.FindPath   and tel.FindPath(x, y, m, cb)  end
function NX.CancelWalk()             return tel.CancelWalk and tel.CancelWalk()            end

-- ── MultiPacket ────────────────────────────────────────────────────────────

function NX.SendMulti(...)          return mp.SendMulti   and mp.SendMulti(...)            end
function NX.SendChain(steps)        return mp.SendChain   and mp.SendChain(steps)          end
function NX.DefineMacro(n, s)       return mp.DefineMacro and mp.DefineMacro(n, s)         end
function NX.RunMacro(n, o)          return mp.RunMacro    and mp.RunMacro(n, o)            end

-- ── SmoothBuf ──────────────────────────────────────────────────────────────

function NX.SetSmoothBuf(e)         return sb.SetSmoothBuf and sb.SetSmoothBuf(e)         end
function NX.FlushBuf()              return sb.Flush        and sb.Flush()                  end

-- ── Godmode ────────────────────────────────────────────────────────────────

function NX.GodmodeOn()             return gm.On       and gm.On()                       end
function NX.GodmodeOff()            return gm.Off      and gm.Off()                      end
function NX.GodmodeToggle()         return gm.Toggle   and gm.Toggle()                   end
function NX.IsGodmode()             return gm.IsActive and gm.IsActive() or false        end

-- ── Camera / Zoom ──────────────────────────────────────────────────────────

function NX.SetZoom(l)              return cam.SetZoom    and cam.SetZoom(l)              end
function NX.ZoomIn(s)               return cam.ZoomIn     and cam.ZoomIn(s)               end
function NX.ZoomOut(s)              return cam.ZoomOut    and cam.ZoomOut(s)              end
function NX.ResetZoom()             return cam.ResetZoom  and cam.ResetZoom()             end
function NX.LockCamera(b, f)        return cam.LockCamera and cam.LockCamera(b, f)        end
function NX.GetZoom()               return cam.GetZoom    and cam.GetZoom() or 0          end

-- ── Fly ────────────────────────────────────────────────────────────────────

function NX.FlyOn()                 return fly.On        and fly.On()                    end
function NX.FlyOff()                return fly.Off       and fly.Off()                   end
function NX.FlyToggle()             return fly.Toggle    and fly.Toggle()                end
function NX.SetFlySpeed(n)          return fly.SetSpeed  and fly.SetSpeed(n)             end
function NX.IsFly()                 return fly.IsActive  and fly.IsActive() or false     end

-- ── Nametag ────────────────────────────────────────────────────────────────

function NX.SetNametag(t, c, p, o)  return nt.Set    and nt.Set(t, c, p, o)              end
function NX.RemoveNametag()          return nt.Remove and nt.Remove()                     end
function NX.UpdateNametag(t)         return nt.Update and nt.Update(t)                    end
function NX.NametagStyle(s)          return nt.ApplyStyle and nt.ApplyStyle(s)            end

-- ── ModDetect ──────────────────────────────────────────────────────────────

function NX.ModWatch(o)              return md.Watch        and md.Watch(o)               end
function NX.ModWatchOff()            return md.Off          and md.Off()                  end
function NX.IsModPresent()           return md.IsModPresent and md.IsModPresent()         end
function NX.ModWhitelist(id)         return md.AddWhitelist and md.AddWhitelist(id)       end

-- ── FastSpin ───────────────────────────────────────────────────────────────

function NX.FastSpin(x, y)           return fs.Spin        and fs.Spin(x, y)             end
function NX.AutoSpin(x, y, n, i)     return fs.AutoSpin    and fs.AutoSpin(x, y, n, i)   end
function NX.StopAutoSpin()           return fs.StopAuto    and fs.StopAuto()              end
function NX.OnSpinResult(cb)         return fs.OnResult    and fs.OnResult(cb)            end
function NX.IsAutoSpinning()         return fs.IsAutoRunning and fs.IsAutoRunning() or false end

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
NX.Scheduler   = sch
NX.Teleport    = tel
NX.MultiPacket = mp
NX.Godmode     = gm
NX.Camera      = cam
NX.Fly         = fly
NX.Nametag     = nt
NX.ModDetect   = md
NX.FastSpin    = fs

-- ── 5. Register global ────────────────────────────────────────────────────────

local function setGlobal(key, val)
    if getgenv then getgenv()[key] = val end
    if getfenv then pcall(function() getfenv(0)[key] = val end) end
    _G[key] = val
end

setGlobal("NX", NX)

-- Startup banner (dev console only — brief)
print("╔══ NXroENinD_DPcKage v" .. NX.VERSION .. " ══╗")
print("║  Panggil NX.Init() untuk mulai   ║")
print("║  NX.FindPath(x,y) | NX.FlyOn()  ║")
print("║  NX.GodmodeOn()   | NX.ModWatch ║")
print("╚══════════════════════════════════╝")
