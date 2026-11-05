-- NXroENinD_DPcKage v3.0.0
-- require this module for local (non-GitHub) usage.

local NXroENinD_DPcKage = {}

local function _load(name)
    return require(script[name])
end

local Network     = _load("Network")
local PlayerAPI   = _load("PlayerAPI")
local Console     = _load("Console")
local Inventory   = _load("Inventory")
local World       = _load("World")
local Events      = _load("Events")
local Config      = _load("Config")
local Scheduler   = _load("Scheduler")
local Buffer      = _load("SmoothBuf")
local Utils       = _load("Utils")
local Teleport    = _load("Teleport")
local MultiPacket = _load("MultiPacket")

-- Network
NXroENinD_DPcKage.SendPkt     = Network.SendPkt
NXroENinD_DPcKage.SendRaw     = Network.SendRaw
NXroENinD_DPcKage.HookPkt     = Network.HookPkt
NXroENinD_DPcKage.UnhookPkt   = Network.UnhookPkt

-- Player
NXroENinD_DPcKage.Player      = PlayerAPI.Player

-- Console
NXroENinD_DPcKage.ConsoleMsg  = Console.ConsoleMsg
NXroENinD_DPcKage.ConsoleLog  = Console.Log
NXroENinD_DPcKage.ConsoleClear= Console.Clear

-- Inventory
NXroENinD_DPcKage.GetInvent   = Inventory.GetInvent
NXroENinD_DPcKage.FindItem    = Inventory.FindItem
NXroENinD_DPcKage.FindAllItems= Inventory.FindAllItems
NXroENinD_DPcKage.CountItem   = Inventory.CountItem
NXroENinD_DPcKage.HasItem     = Inventory.HasItem
NXroENinD_DPcKage.GetEquipped = Inventory.GetEquipped
NXroENinD_DPcKage.GetByType   = Inventory.GetByType

-- World
NXroENinD_DPcKage.GetTile     = World.GetTile
NXroENinD_DPcKage.GetWorld    = World.GetWorld
NXroENinD_DPcKage.FindTiles   = World.FindTiles
NXroENinD_DPcKage.TileAt      = World.TileAt

-- Teleport
NXroENinD_DPcKage.FindPath    = Teleport.FindPath
NXroENinD_DPcKage.CancelWalk  = Teleport.CancelWalk

-- MultiPacket
NXroENinD_DPcKage.SendMulti   = MultiPacket.SendMulti
NXroENinD_DPcKage.SendChain   = MultiPacket.SendChain
NXroENinD_DPcKage.SendIf      = MultiPacket.SendIf
NXroENinD_DPcKage.DefineMacro = MultiPacket.DefineMacro
NXroENinD_DPcKage.RunMacro    = MultiPacket.RunMacro

-- Sub-modules (direct access)
NXroENinD_DPcKage.SmoothBuf   = Buffer
NXroENinD_DPcKage.Events      = Events
NXroENinD_DPcKage.Config      = Config
NXroENinD_DPcKage.Utils       = Utils
NXroENinD_DPcKage.Teleport    = Teleport
NXroENinD_DPcKage.MultiPacket = MultiPacket

-- Scheduler
NXroENinD_DPcKage.After       = Scheduler.After
NXroENinD_DPcKage.Every       = Scheduler.Every
NXroENinD_DPcKage.Cancel      = Scheduler.Cancel
NXroENinD_DPcKage.NextFrame   = Scheduler.NextFrame

NXroENinD_DPcKage.VERSION     = "3.0.0"

function NXroENinD_DPcKage.Init(cfg)
    cfg = cfg or {}
    Config.Apply(cfg)
    Buffer.Start()
    Network.Start()
    Console.Start()
    Inventory.Start()
    PlayerAPI.Start()
    World.Start()
    if cfg.SmoothBuf ~= nil then
        Buffer.SetSmoothBuf(cfg.SmoothBuf)
    end
end

function NXroENinD_DPcKage.SetSmoothBuf(enabled)
    Buffer.SetSmoothBuf(enabled)
end

return table.freeze(NXroENinD_DPcKage)
