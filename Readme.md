# NXroENinD_DPcKage — API & Panduan Penggunaan

**Versi:** 3.1.0  
**Repo:** https://github.com/Mytzcodes/Gbxzcf0x2993HsFDj1  
**Folder modul di repo:** `Framework_C8&d0ScRR/`

---

## Cara Install — 1 Baris di Executor

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Mytzcodes/Gbxzcf0x2993HsFDj1/refs/heads/main/NXroENinD_DPcKage_Loader.lua"))()
```

Setelah loadstring selesai, `NX` tersedia sebagai global. Langsung panggil:

```lua
NX.Init({ SmoothBuf = true })
NX.ConsoleMsg("Ready!", "green")
```

---

## Kenapa Error "attempt to call a nil value"?

Error ini muncul jika `NX` bernilai `nil` setelah loadstring. Penyebabnya:

| Penyebab | Tanda | Solusi |
|:---|:---|:---|
| `RAW_BASE` masih placeholder `YOUR_USER/...` | Loader lama belum di-update | Gunakan loader v3.1 di atas — URL sudah terisi otomatis |
| `script` adalah `nil` di executor context | Modul error saat `require(script.Parent.X)` | Sudah diperbaiki di loader v3.1 via fake `script.Parent` |
| `setfenv` tidak ada di Luau | Modul tidak menerima env injection | Loader v3.1 memakai fallback `_G` jika `setfenv` tidak ada |
| URL modul tidak bisa diakses | HttpGet error | Pastikan repo GitHub bersifat **Public** |

---

## Struktur File di Repo GitHub

```
Gbxzcf0x2993HsFDj1/
├── NXroENinD_DPcKage_Loader.lua    ← Script yang kamu paste ke executor
└── Framework_C8&d0ScRR/
    ├── Events.lua
    ├── Config.lua
    ├── Utils.lua
    ├── SmoothBuf.lua
    ├── Console.lua
    ├── Network.lua
    ├── PlayerAPI.lua
    ├── Inventory.lua
    ├── World.lua
    ├── Scheduler.lua
    ├── Teleport.lua
    └── MultiPacket.lua
```

---

## NX.Init(config)

Wajib dipanggil sekali setelah loadstring. Menginisialisasi semua sistem dan mendownload modul yang belum ada.

```lua
NX.Init({
    SmoothBuf     = true,            -- Packet batching per frame (sangat dianjurkan)
    LogLevel      = 1,               -- 0=mati, 1=info, 2=debug, 3=verbose
    ConsolePrefix = "[NX]",          -- Prefix label pada output konsol
    FlushRate     = 1,               -- Flush buffer tiap N frame (default: 1)
})
```

---

## Network — SendPkt, SendRaw, HookPkt

### NX.SendPkt(packetRef, data)

Mengirim typed packet ke server.

**Parameter:**
- `packetRef` — Nama packet (string) **atau** hex ID (number)
- `data` — Table payload sesuai struct packet

```lua
-- Chat
NX.SendPkt("ChatPacket", { message = "Hello!", channel = 0 })

-- Break tile
NX.SendPkt("BreakBlockPacket", { x = 10, y = 20 })

-- Place tile
NX.SendPkt("PlaceBlockPacket", { x = 10, y = 20, itemId = 2 })

-- Equip item
NX.SendPkt("WearItemPacket", { itemId = 300 })

-- Lepas item
NX.SendPkt("RemoveItemPacket", { itemId = 300 })

-- Gunakan item di tile
NX.SendPkt("UseItemPacket", { itemId = 18, x = 10, y = 20 })

-- Beli dari shop
NX.SendPkt("BuyPacket", { shopId = 1, itemId = 50, count = 10 })

-- Jual ke shop
NX.SendPkt("SellPacket", { shopId = 1, itemId = 50, count = 10 })

-- Jatuhkan item
NX.SendPkt("DropItemPacket", { itemId = 50, count = 5 })

-- Ambil dropped item
NX.SendPkt("CollectItemPacket", { objectId = 99 })

-- Buang item (trash)
NX.SendPkt("TrashItemPacket", { itemId = 50, count = 1 })

-- Craft
NX.SendPkt("CraftPacket", { recipeId = 7 })

-- Respawn
NX.SendPkt("RespawnPacket", {})

-- Emote
NX.SendPkt("EmotePacket", { emoteId = 3 })

-- Masuk pintu
NX.SendPkt("EnterDoorPacket", { x = 5, y = 10 })

-- Pindah world
NX.SendPkt("WorldRequestPacket", { worldName = "STARTHERE" })

-- Lock tile
NX.SendPkt("LockPacket", { x = 5, y = 5, action = 0 })
-- action: 0=pasang lock, 1=hapus lock, 2=add akses, 3=hapus akses, 4=toggle public

-- Edit papan tanda
NX.SendPkt("SignEditPacket", { x = 5, y = 5, text = "Isi tanda" })

-- Friend request
NX.SendPkt("FriendPacket", { targetUserId = 123456, action = 0 })
-- action: 0=request, 1=accept, 2=decline, 3=remove, 4=block

-- Interaksi NPC
NX.SendPkt("NpcInteractPacket", { npcId = 1, option = 0 })

-- Gerak/Teleport manual via packet
NX.SendPkt("MovementPacket", {
    position = Vector3.new(10, 5, 0),
    velocity = Vector3.new(0, 0, 0),
    rotation = 0
})

-- Pakai hex ID langsung
NX.SendPkt(0x0004, { x = 10, y = 20, itemId = 2 })
```

---

### NX.SendRaw(buf)

Kirim binary buffer mentah (bypass typed system).

**Parameter:**
- `buf` — Roblox `buffer` object

```lua
-- Contoh: buat raw ChatPacket dari byte
local msg    = "Hello raw"
local msgLen = #msg
local buf    = buffer.create(2 + 2 + msgLen + 1)
local c      = 0

buffer.writeu16(buf, c, 0x0003)        ; c += 2
buffer.writeu16(buf, c, msgLen)        ; c += 2
buffer.writestring(buf, c, msg)        ; c += msgLen
buffer.writeu8(buf, c, 0)

NX.SendRaw(buf)
```

---

### NX.HookPkt(packetRef, callback) → handle

Pasang listener yang terpanggil setiap kali packet tertentu masuk dari server.

**Parameter:**
- `packetRef` — Nama atau hex ID packet
- `callback(data, packetId)` — Fungsi listener

**Return:** `handle` untuk melepas hook dengan `NX.UnhookPkt(handle)`

```lua
-- Sadap setiap perubahan tile di map
local h = NX.HookPkt("TileUpdatePacket", function(data)
    print(string.format("Tile (%d,%d) berubah → fg:%d bg:%d flags:0x%X",
        data.x, data.y, data.fg, data.bg, data.flags))
end)

-- Sadap player baru masuk
local h2 = NX.HookPkt("PlayerJoinPacket", function(data)
    print("Join:", data.name, data.userId, data.position)
end)

-- Sadap pesan konsol dari server
local h3 = NX.HookPkt("ConsoleMessagePacket", function(data)
    print("[SERVER MSG]", data.text)
end)

-- Lepas hook
NX.UnhookPkt(h)
NX.UnhookPkt(h2)

-- Sadap via ID angka
local h4 = NX.HookPkt(0x0010, function(data)
    -- InventoryUpdatePacket
    print("Inventory sync:", #data.items, "items")
end)
```

---

## Player — NX.Player()

Data avatar bersumber dari **game packet**, bukan `Players.LocalPlayer`.

```lua
local p = NX.Player()

-- Properti local player
print(p.name)              -- Nama in-game dari PlayerJoinPacket
print(p.userId)            -- ID entitas game
print(p.CurrentPosition)   -- Vector3 dari PlayerUpdatePacket
print(p.CurrentVelocity)   -- Vector3 dari MovementPacket
print(p.CurrentRotation)   -- float (radians)
print(p.count)             -- Jumlah player di world
print(#p.list)             -- Array semua PlayerObject
```

### p.find(query) → PlayerObject?

```lua
-- Cari by nama (partial, case-insensitive)
local target = NX.Player().find("Defin")
if target then
    print(target.name, target.CurrentPosition, target.CurrentAnim)
end

-- Cari by userId
local p2 = NX.Player().find(123456789)
```

### p.nearest(maxDist?) → PlayerObject?, number

```lua
-- Player lain paling dekat dalam radius 50 studs
local near, dist = NX.Player().nearest(50)
if near then
    print("Paling dekat:", near.name, "jarak:", math.floor(dist), "studs")
end
```

### p.forEach(fn)

```lua
-- Iterasi semua player, return false untuk break
NX.Player().forEach(function(obj)
    print(obj.name, obj.CurrentPosition)
    if obj.name == "Target" then
        return false  -- hentikan loop
    end
end)
```

### PlayerObject:DistanceTo(target)

```lua
local me     = NX.Player().self
local target = NX.Player().find("SomePlayer")
if target then
    print("Jarak:", me:DistanceTo(target))
end
```

---

## Inventory — GetInvent, FindItem, CountItem

### NX.GetInvent() → table[]

Mengembalikan array semua item di tas. Update otomatis saat `InventoryUpdatePacket` masuk.

```lua
local inv = NX.GetInvent()
print("Slot terisi:", #inv)

for i, item in ipairs(inv) do
    -- item.id         (number) ID item
    -- item.count      (number) jumlah stack
    -- item.name       (string) nama dari ItemDatabase
    -- item.type       (string) "block","seed","tool","clothing","consumable"
    -- item.rarity     (number) 0-7
    -- item.equipped   (bool)   sedang dipakai
    -- item.stackable  (bool)
    -- item.maxStack   (number)
    print(i, item.name, item.count, item.type, item.equipped)
end
```

### NX.FindItem(query) → InvItem?

```lua
local dirt = NX.FindItem("Dirt")          -- cari by nama (partial match)
local item = NX.FindItem(1234)             -- cari by ID

if dirt then
    -- Langsung gunakan
    NX.SendPkt("UseItemPacket", { itemId = dirt.id, x = 10, y = 20 })
end
```

### NX.CountItem(query) → number

```lua
local total = NX.CountItem("Wood")
print("Total Wood:", total)
```

### NX.HasItem(query, minCount?) → bool

```lua
if NX.HasItem("Magic Seed", 5) then
    print("Punya 5+ magic seed")
end
```

### NX.FindAllItems(query) → table[]

```lua
-- Semua slot yang mengandung item dengan nama "Seed"
local seeds = NX.FindAllItems("Seed")
for _, s in ipairs(seeds) do
    print(s.name, s.count)
end
```

### NX.GetEquipped() → table[]

```lua
local worn = NX.GetEquipped()
for _, w in ipairs(worn) do
    print("Pakai:", w.name)
end
```

### NX.GetByType(typeName) → table[]

```lua
local blocks  = NX.GetByType("block")
local seeds   = NX.GetByType("seed")
local clothes = NX.GetByType("clothing")
local tools   = NX.GetByType("tool")
```

---

## World & Tile — GetTile, FindTiles, TileAt

### NX.GetWorld() → WorldData?

```lua
local w = NX.GetWorld()
if w then
    print("World  :", w.name)
    print("Ukuran :", w.width, "x", w.height)
    print("Pemilik:", w.ownerId)
    print("Cuaca  :", w.weatherType)
end
```

### NX.GetTile(x, y) → TileObject?

```lua
local tile = NX.GetTile(10, 20)
if tile then
    print("FG ID       :", tile.foreground)
    print("BG ID       :", tile.background)
    print("Growth stage:", tile.growth)      -- 0-7 untuk pohon
    print("Lock owner  :", tile.lockOwner)   -- 0 = tidak terkunci
    print("Flags (hex) :", string.format("0x%X", tile.flags))

    -- Helper boolean (tidak perlu hitung bitmask manual)
    print("Solid wall? :", tile:isSolid())
    print("Locked?     :", tile:isLocked())
    print("Has tree?   :", tile:isTree())
    print("Is door?    :", tile:isDoor())
    print("Has sign?   :", tile:hasSign())
    print("Is public?  :", tile:isPublic())
    print("Is empty?   :", tile:isEmpty())   -- tidak ada fg & bg
end
```

### NX.FindTiles(predicate) → TileObject[]

Predicate: `function(tile) return bool end`

```lua
-- Pohon matang (stage 7)
local ripe = NX.FindTiles(function(t) return t:isTree() and t.growth >= 7 end)
print("Pohon siap panen:", #ripe)

-- Semua tile kosong dan tidak dikunci (untuk menanam)
local empty = NX.FindTiles(function(t) return t:isEmpty() and not t:isLocked() end)

-- Tile dengan ID foreground tertentu
local dirt = NX.FindTiles(function(t) return t.foreground == 2 end)

-- Tile yang bisa ditanami bibit
local plantable = NX.FindTiles(function(t)
    return bit32.band(t.flags, 0x00000002) ~= 0  -- TILE_SEEDABLE flag
end)
```

### NX.TileAt(worldPos: Vector3) → TileObject?

```lua
-- Tile di bawah avatar saat ini
local tile = NX.TileAt(NX.Player().CurrentPosition)
if tile then
    print("Berdiri di atas tile FG:", tile.foreground)
end
```

---

## Teleport — NX.FindPath(x, y, method, callback?)

Navigasi ke tile tujuan. Dua metode dengan cara kerja berbeda.

**Parameter:**
- `x`, `y` — Koordinat tile target
- `method` — `1` atau `2` (lihat tabel di bawah)
- `callback(success, pos)` — Dipanggil saat tiba atau gagal (opsional)

**Return:** `{ Cancel = function() }` — token pembatal

| method | Cara Kerja | Cocok Untuk |
|:---:|:---|:---|
| `1` | 1 `MovementPacket` instan ke tujuan | Private world, teleport cepat |
| `2` | Kalkulasi A* menghindari solid tile, kirim packet bertahap tiap `0.08s` | Publik, terlihat natural |

```lua
-- Method 1: Teleport instan
NX.FindPath(50, 30, 1, function(ok, pos)
    if ok then print("Tiba instan di", pos) end
end)

-- Method 2: Jalan natural menghindari tembok
local handle = NX.FindPath(50, 30, 2, function(ok, pos)
    if ok then
        print("Sampai dengan aman!")
        -- Lakukan aksi setelah tiba:
        NX.SendPkt("BreakBlockPacket", { x = 50, y = 30 })
    else
        print("Tidak ada jalur yang bisa dilalui")
    end
end)

-- Batalkan jalan di tengah:
handle.Cancel()

-- Batalkan semua jalan aktif:
NX.CancelWalk()

-- Tuning kecepatan method 2:
NX.Teleport.SetStepDelay(0.06)   -- makin kecil makin cepat (default 0.08)
NX.Teleport.SetTileSize(2)       -- ukuran tile dalam studs (default 2)
```

---

## MultiPacket — SendMulti, SendChain, SendIf

### NX.SendMulti(...) — Kirim banyak tipe packet sekaligus (1 frame)

```lua
-- Beli item + langsung equip dalam satu frame
NX.SendMulti(
    { "BuyPacket",      { shopId = 1, itemId = 300, count = 1 } },
    { "WearItemPacket", { itemId = 300 } }
)

-- Break 3 tile sekaligus
NX.SendMulti(
    { "BreakBlockPacket", { x = 5, y = 5 } },
    { "BreakBlockPacket", { x = 6, y = 5 } },
    { "BreakBlockPacket", { x = 7, y = 5 } }
)
```

### NX.SendChain(steps) → { Cancel() } — Berurutan dengan delay

Format per step: `{ "PacketName", payloadTable, delaySetelahStepIni? }`

```lua
-- Beli → tunggu 0.2s → tanam → tunggu 0.1s → chat
local chain = NX.SendChain({
    { "BuyPacket",     { shopId = 1, itemId = 18, count = 1 }, 0.2 },
    { "UseItemPacket", { itemId = 18, x = 10, y = 20 },        0.1 },
    { "ChatPacket",    { message = "Done!", channel = 0 } }
})

-- Batalkan chain:
chain.Cancel()
```

### NX.SendIf(condition, thenPkts, elsePkts?) — Kondisional

```lua
NX.SendIf(
    NX.HasItem("Magic Seed", 1),
    -- Jika punya seed:
    { { "UseItemPacket", { itemId = 18, x = 10, y = 20 } } },
    -- Jika tidak punya:
    { { "ChatPacket",    { message = "No seeds!", channel = 0 } } }
)
```

### NX.DefineMacro / NX.RunMacro — Template Reusable

```lua
-- Definisi sekali
NX.DefineMacro("HarvestAndPlant", {
    { "BreakBlockPacket", { x = 0, y = 0 },              0.1 },
    { "UseItemPacket",    { itemId = 18, x = 0, y = 0 } }
})

-- Jalankan berkali-kali dengan koordinat berbeda
NX.RunMacro("HarvestAndPlant", {
    { x = 10, y = 15 },
    { itemId = 18, x = 10, y = 15 }
})
```

---

## Preset MultiPacket Siap Pakai

```lua
-- Beli dari shop lalu langsung place di tile
NX.MultiPacket.BuyAndPlace(shopId, itemId, count, x, y)

-- Pasang barisan block horizontal
-- direction: 1=kanan, -1=kiri (default 1)
NX.MultiPacket.PlaceRow(itemId, startX, y, length, direction)

-- Hancurkan area persegi (x1,y1) sampai (x2,y2)
NX.MultiPacket.BreakRect(x1, y1, x2, y2)

-- Equip item lalu gunakan di tile
NX.MultiPacket.EquipAndUse(itemId, x, y)

-- Craft lalu langsung equip hasilnya
NX.MultiPacket.CraftAndWear(recipeId, itemId)

-- Beli dari satu shop, jual ke shop lain
NX.MultiPacket.BuySellArbitrage(buyShopId, sellShopId, itemId, count)

-- Ajak trade, isi offer, lalu confirm
NX.MultiPacket.TradeAndConfirm(targetUserId, {
    { id = 50, count = 10 },
    { id = 300, count = 1 }
})

-- Add friend + kirim chat
NX.MultiPacket.FriendAndChat(targetUserId, "Hey!")
```

---

## SmoothBuf — Frame Batching

```lua
-- Toggle
NX.SetSmoothBuf(true)
NX.SetSmoothBuf(false)

-- Flush paksa sekarang
NX.SmoothBuf.Flush()

-- Atur frekuensi flush (default: 1 = tiap frame)
NX.SmoothBuf.SetFlushRate(1)
NX.SmoothBuf.SetFlushRate(2)

-- Cek jumlah packet di antrean
print(NX.SmoothBuf.GetQueueSize())
```

---

## Scheduler — After, Every, Cancel

```lua
-- Sekali setelah N detik
NX.After(3, function()
    print("3 detik kemudian")
end)

-- Berulang tiap N detik, return false untuk stop
local t = NX.Every(1, function()
    print("Setiap detik")
end)
NX.Cancel(t)

-- Frame berikutnya
NX.NextFrame(function()
    print("Next frame!")
end)
```

---

## Events

```lua
-- Subscribe
local h = NX.Events.On("player:join", function(p)
    print("Join:", p.name)
end)

-- Unsubscribe
NX.Events.Off(h)

-- Sekali saja
NX.Events.Once("world:loaded", function(w)
    print("World loaded:", w.name)
end)

-- Custom event
NX.Events.Emit("myScript:done", { result = 42 })
NX.Events.On("myScript:done", function(d) print(d.result) end)
```

**Event bawaan:**

| Event | Data | Kapan |
|:---|:---|:---|
| `player:join` | `PlayerObject` | Player masuk world |
| `player:leave` | `PlayerObject` | Player keluar world |
| `inventory:update` | `InvItem[]` | Inventory di-sync server |
| `world:loaded` | `WorldData` | Data world diterima |
| `tile:update` | `TileObject` | Tile berubah |
| `tile:growth` | `TileObject` | Pohon naik stage |
| `teleport:arrive` | `{x,y,method}` | Navigasi tiba |
| `teleport:npath` | `{x,y}` | Tidak ada jalur A* |
| `smoothbuf:flush` | `count` | Batch packet dikirim |
| `packet:16` | `data` | Contoh: InventoryUpdatePacket |

---

## Console

```lua
NX.ConsoleMsg("Teks biasa")
NX.ConsoleMsg("Sukses!",   "green")
NX.ConsoleMsg("Warning!",  "yellow")
NX.ConsoleMsg("Error!",    "red")
NX.ConsoleMsg("Info",      "cyan")
NX.ConsoleMsg("Detail",    "gray")
NX.ConsoleMsg("Penting",   "orange")
NX.ConsoleMsg("Spesial",   "purple")
NX.ConsoleMsg("Custom",    Color3.fromRGB(100, 200, 255))
NX.ConsoleLog("Debug detail", 2)   -- hanya muncul jika LogLevel >= 2
NX.ConsoleClear()
```

---

## Utils

```lua
local U = NX.Utils

U.trim("  teks  ")            -- "teks"
U.split("a,b,c", ",")         -- {"a","b","c"}
U.startsWith("ChatPacket","Chat")  -- true

U.lerp(0, 100, 0.5)           -- 50
U.clamp(120, 0, 100)          -- 100
U.round(3.14159, 2)           -- 3.14
U.dist2D(0,0, 3,4)            -- 5
U.dist3D(vecA, vecB)          -- magnitude

U.formatTime(3665)            -- "01:01:05"
U.pktIdToName(0x0004)         -- "PlaceBlockPacket"
U.pktIdToHex(4)               -- "0x0004"
U.color32ToColor3(0xFF8800)   -- Color3
```

---

## Contoh Proyek: Auto-Farm Bot Lengkap

```lua
-- Paste loadstring, lalu ini di script terpisah:
NX.Init({ SmoothBuf = true })

local function farmCycle()
    -- 1. Cari pohon matang
    local trees = NX.FindTiles(function(t) return t:isTree() and t.growth >= 7 end)
    if #trees == 0 then return end

    local t = trees[1]

    -- 2. Navigasi natural ke pohon (hindari tembok)
    NX.FindPath(t.x, t.y, 2, function(ok)
        if not ok then return end

        -- 3. Panen + tanam ulang dalam 1 chain
        NX.SendChain({
            { "BreakBlockPacket", { x = t.x, y = t.y }, 0.2 },
            { "UseItemPacket",    { itemId = NX.FindItem("Seed") and NX.FindItem("Seed").id or 18,
                                    x = t.x, y = t.y } }
        })
    end)
end

-- Jalankan setiap 5 detik
local loop = NX.Every(5, farmCycle)

-- Hentikan setelah 30 menit
NX.After(1800, function()
    NX.Cancel(loop)
    NX.ConsoleMsg("Farm bot dihentikan.", "yellow")
end)
```

---

## Referensi Packet ID

| ID | Nama | Arah | Payload |
|:---:|:---|:---:|:---|
| `0x0001` | InputPacket | C→S | `{action:u8, state:bool, position:vec3}` |
| `0x0002` | MovementPacket | C→S | `{position:vec3, velocity:vec3, rotation:f32}` |
| `0x0003` | ChatPacket | Bi | `{message:string, channel:u8}` |
| `0x0004` | PlaceBlockPacket | C→S | `{x:i32, y:i32, itemId:u16}` |
| `0x0005` | BreakBlockPacket | C→S | `{x:i32, y:i32}` |
| `0x0006` | DropItemPacket | C→S | `{itemId:u16, count:u16}` |
| `0x0007` | CollectItemPacket | C→S | `{objectId:u32}` |
| `0x0008` | WearItemPacket | C→S | `{itemId:u16}` |
| `0x0009` | RemoveItemPacket | C→S | `{itemId:u16}` |
| `0x000A` | TrashItemPacket | C→S | `{itemId:u16, count:u16}` |
| `0x000B` | UseItemPacket | C→S | `{itemId:u16, x:i32, y:i32}` |
| `0x000C` | EnterDoorPacket | C→S | `{x:i32, y:i32}` |
| `0x000D` | WorldRequestPacket | C→S | `{worldName:string}` |
| `0x000E` | WorldDataPacket | S→C | `{worldData:buff}` |
| `0x000F` | TileUpdatePacket | S→C | `{x:i32, y:i32, fg:u16, bg:u16, flags:u32}` |
| `0x0010` | InventoryUpdatePacket | S→C | `{items:array<{id,count}>}` |
| `0x0011` | PlayerJoinPacket | S→C | `{userId:u32, name:string, position:vec3}` |
| `0x0012` | PlayerLeavePacket | S→C | `{userId:u32}` |
| `0x0013` | PlayerUpdatePacket | S→C | `{userId:u32, position:vec3, rotation:f32, anim:u8}` |
| `0x0014` | ConsoleMessagePacket | S→C | `{text:string, color:u32}` |
| `0x0015` | DialogPacket | S→C | `{dialogType:u8, title:string, body:string}` |
| `0x0016` | TradeRequestPacket | Bi | `{targetUserId:u32}` |
| `0x0017` | TradeUpdatePacket | Bi | `{items:array<{id,count}>, confirmed:bool}` |
| `0x0018` | PingPacket | Bi | `{timestamp:f64}` |
| `0x0019` | SyncClockPacket | S→C | `{serverTime:f64}` |
| `0x001A` | AdminCommandPacket | C→S | `{command:string, args:string}` |
| `0x001B` | NpcInteractPacket | C→S | `{npcId:u32, option:u8}` |
| `0x001C` | CraftPacket | C→S | `{recipeId:u16}` |
| `0x001D` | BuyPacket | C→S | `{shopId:u16, itemId:u16, count:u16}` |
| `0x001E` | SellPacket | C→S | `{shopId:u16, itemId:u16, count:u16}` |
| `0x001F` | SignEditPacket | C→S | `{x:i32, y:i32, text:string}` |
| `0x0020` | LockPacket | C→S | `{x:i32, y:i32, action:u8}` |
| `0x0021` | FriendPacket | C→S | `{targetUserId:u32, action:u8}` |
| `0x0022` | EmotePacket | C→S | `{emoteId:u8}` |
| `0x0023` | RespawnPacket | C→S | `{}` |
| `0x0024` | GrowthUpdatePacket | S→C | `{x:i32, y:i32, stage:u8}` |
| `0x0025` | WeatherPacket | S→C | `{weatherType:u8, intensity:f32}` |
| `0x0026` | EffectPacket | S→C | `{effectType:u8, position:vec3, data:u32}` |
| `0x0027` | SoundPacket | S→C | `{soundId:u16, position:vec3, volume:f32}` |

*Channel Unreliable: 0x0002, 0x0013, 0x0018 — Semua lain Reliable.*

---

*NXroENinD_DPcKage v3.1.0 — https://github.com/Mytzcodes/Gbxzcf0x2993HsFDj1*
