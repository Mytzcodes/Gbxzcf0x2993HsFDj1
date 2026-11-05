# 🚀 NXroENinD_DPcKage — Panduan Penggunaan Lengkap & API Reference
**Version:** 3.0.0-PRO  
**Kompatibilitas:** Luau / ByteNet Engine (GrowBlox)  
**Standard Model:** GrowLauncher & GentaHax C++ Struct / Fast Memory Layout

---

## 📋 Daftar Isi Cepat
1. [Cara Pasang & Loadstring 1 Baris](#1-cara-pasang--loadstring-1-baris)
2. [NX.Init(config) — Konfigurasi Framework](#2-nxinitconfig--konfigurasi-framework)
3. [Network Layer — SendPkt, SendRaw, HookPkt](#3-network-layer--sendpkt-sendraw-hookpkt)
4. [In-Game Avatar — NX.Player()](#4-in-game-avatar--nxplayer)
5. [Inventory System — GetInvent, FindItem, CountItem](#5-inventory-system--getinvent-finditem-countitem)
6. [World & Tile Grid — GetTile, FindTiles, TileAt](#6-world--tile-grid--gettile-findtiles-tileat)
7. [Teleport & Pathfinding — NX.FindPath (Method 1 & 2)](#7-teleport--pathfinding--nxfindpath-method-1--2)
8. [MultiPacket Engine — SendMulti, SendChain, SendIf, Macro](#8-multipacket-engine--sendmulti-sendchain-sendif-macro)
9. [Action Presets Majemuk (BuyAndPlace, PlaceRow, BreakRect, dll)](#9-action-presets-majemuk)
10. [SmoothBuf — Frame Batching & Anti-Lag](#10-smoothbuf--frame-batching--anti-lag)
11. [Scheduler — After, Every, Cancel, NextFrame](#11-scheduler--after-every-cancel-nextframe)
12. [Event Bus — On, Off, Emit, Once](#12-event-bus--on-off-emit-once)
13. [Console & Output — ConsoleMsg, Log, Clear](#13-console--output--consolemsg-log-clear)
14. [Utils Library — String, Table, Math, Color](#14-utils-library)
15. [Studi Kasus Proyek Nyata](#15-studi-kasus-proyek-nyata)

---

## 1. Cara Pasang & Loadstring 1 Baris

Framework ini menggunakan **Lazy Loader**. Modul tidak akan didownload atau memakan memori/FPS sebelum fungsi dipanggil pertama kali.

### Cara Pakai di Executor / Script:
```lua
-- 1. Jalankan Loader dari GitHub Anda:
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/NXroENinD_DPcKage_Loader.lua", true))()

-- 2. NX sekarang tersedia secara GLOBAL di seluruh script:
NX.Init({ SmoothBuf = true })
NX.ConsoleMsg("NXroENinD_DPcKage Siap Digunakan!", "green")
```

---

## 2. NX.Init(config) — Konfigurasi Framework

Menginisialisasi framework, memulai listener packet internal, dan mengatur opsi performa.

### Signature:
```lua
NX.Init(config: table?)
```

### Rincian Parameter `config`:
| Field | Tipe | Default | Penjelasan |
|:---|:---:|:---:|:---|
| `SmoothBuf` | `boolean` | `true` | **Wajib diaktifkan untuk spam/rapid packet.** Menggabungkan packet dalam 1 frame Heartbeat agar tidak drop FPS & tidak terkena kick rate-limit server. |
| `LogLevel` | `number` | `1` | Level log konsol: `0` (mati), `1` (info penting), `2` (debug), `3` (verbose). |
| `FlushRate` | `number` | `1` | Frekuensi flush buffer setiap N frame render (1 = setiap frame, latency terendah). |
| `ConsolePrefix`| `string` | `"[NX-PRO]"` | Prefix teks pada konsol sistem. |

### Contoh Penggunaan:
```lua
NX.Init({
    SmoothBuf     = true,
    LogLevel      = 2,
    ConsolePrefix = "[BOT-FARM]"
})
```

---

## 3. Network Layer — SendPkt, SendRaw, HookPkt

### 3.1. `NX.SendPkt(packetRef, payload)`
Mengirim packet berstruktur (typed packet) ke server. Jika `SmoothBuf = true`, packet akan otomatis masuk ke antrean frame saat ini dan dikirim bersamaan.

#### Parameter:
* `packetRef` (`string | number`): Nama packet (misal `"ChatPacket"`) atau nomor Hex ID (misal `0x0003`).
* `payload` (`table`): Data tabel yang cocok dengan struct payload packet tersebut.

#### Contoh Penggunaan Lengkap Berdasarkan Jenis Packet:

```lua
-- A. Chat Packet (0x0003)
-- Param: message (string), channel (number: 0=World, 1=Global, 2=Whisper)
NX.SendPkt("ChatPacket", {
    message = "Halo dunia!",
    channel = 0
})

-- B. Break Block / Punch (0x0005)
-- Param: x (i32), y (i32) -> koordinat tile grid map
NX.SendPkt("BreakBlockPacket", {
    x = 10,
    y = 25
})

-- C. Place Block (0x0004)
-- Param: x (i32), y (i32), itemId (u16)
NX.SendPkt("PlaceBlockPacket", {
    x = 10,
    y = 25,
    itemId = 2 -- Dirt Block ID
})

-- D. Wear / Equip Item (0x0008)
-- Param: itemId (u16)
NX.SendPkt("WearItemPacket", {
    itemId = 300 -- Item ID baju/sayap
})

-- E. Use / Activate Item (0x000B)
-- Param: itemId (u16), x (i32), y (i32)
NX.SendPkt("UseItemPacket", {
    itemId = 18, -- Seed ID
    x = 10,
    y = 24
})

-- F. Buy From Shop (0x001D)
-- Param: shopId (u16), itemId (u16), count (u16)
NX.SendPkt("BuyPacket", {
    shopId = 1,
    itemId = 50,
    count  = 10
})

-- G. Movement Packet (0x0002) - Unreliable Channel
-- Param: position (Vector3), velocity (Vector3), rotation (float)
NX.SendPkt("MovementPacket", {
    position = Vector3.new(20, 15, 0),
    velocity = Vector3.new(0, 0, 0),
    rotation = 0
})
```

---

### 3.2. `NX.SendRaw(buf)`
Mengirim binary buffer mentah secara langsung melalui socket RemoteEvent ByteNet tanpa validasi typed struct. Digunakan jika ingin custom payload atau optimasi tingkat byte paling rendah.

#### Parameter:
* `buf` (`buffer`): Objek buffer native Roblox (`typeof(buf) == "buffer"`).

#### Contoh Penggunaan:
```lua
-- Membuat binary buffer manual untuk ChatPacket (ID: 0x0003)
local msg = "Raw packet payload"
local msgLen = #msg
local totalSize = 2 + 2 + msgLen + 1 -- [ID:2b] + [StrLen:2b] + [Str:Nb] + [Channel:1b]

local rawBuf = buffer.create(totalSize)
local cursor = 0

buffer.writeu16(rawBuf, cursor, 0x0003)      cursor += 2      -- Packet ID
buffer.writeu16(rawBuf, cursor, msgLen)      cursor += 2      -- String length prefix
buffer.writestring(rawBuf, cursor, msg)      cursor += msgLen -- Teks string
buffer.writeu8(rawBuf, cursor, 0)                             -- Channel 0

-- Kirim langsung:
NX.SendRaw(rawBuf)
```

---

### 3.3. `NX.HookPkt(packetRef, callback)` & `NX.UnhookPkt(handle)`
Memasang listener penyadap (tap interceptor) untuk membaca packet masuk dari server sebelum diproses game.

#### Parameter:
* `packetRef` (`string | number`): Nama atau ID packet yang disadap.
* `callback` (`function(data, packetId)`): Fungsi yang dipanggil saat packet tiba.
* *Return:* `handle` (`table`) — token untuk menghapus hook.

#### Contoh Penggunaan:
```lua
-- Sadap TileUpdatePacket (0x000F): Tahu seketika jika ada player merusak/menaruh balok
local tileHook = NX.HookPkt("TileUpdatePacket", function(data, id)
    print(string.format("Tile berubah di (%d, %d) | FG: %d | BG: %d | Flags: 0x%X",
        data.x, data.y, data.fg, data.bg, data.flags))
end)

-- Sadap saat ada player lain yang bergabung ke world
local joinHook = NX.HookPkt("PlayerJoinPacket", function(data)
    NX.ConsoleMsg("Player Baru: " .. data.name .. " (ID: " .. data.userId .. ")", "cyan")
end)

-- Melepas hook setelah 30 detik:
NX.After(30, function()
    NX.UnhookPkt(tileHook)
    NX.ConsoleMsg("Hook tile dinonaktifkan.", "yellow")
end)
```

---

## 4. In-Game Avatar — NX.Player()

Berbeda dari script umum yang memakai `game.Players.LocalPlayer.Character`, `NX.Player()` mengambil data **murni dari stream packet server**:
* Nama in-game bukan nama akun Roblox.
* `CurrentPosition` tetap update meskipun karakter Roblox sedang desync atau respawn.

### Properti Objek `NX.Player()`:
```lua
local me = NX.Player()

print(me.name)            -- string  -> Nama tampilan in-game
print(me.userId)          -- number  -> ID entitas unik in-game
print(me.CurrentPosition) -- Vector3 -> Posisi real-time dari packet
print(me.CurrentVelocity) -- Vector3 -> Kecepatan gerak physics
print(me.CurrentRotation) -- number  -> Sudut hadap avatar (radians)
print(me.count)           -- number  -> Jumlah player di dalam world saat ini
print(#me.list)           -- number  -> Array seluruh PlayerObject di world
```

### Method Helper `NX.Player()`:
```lua
-- 1. me.find(query) -> PlayerObject?
-- Mencari player lain berdasarkan nama (partial case-insensitive) atau userId
local target = NX.Player().find("Defin")
if target then
    print("Ditemukan:", target.name, "pada posisi:", target.CurrentPosition)
end

-- 2. me.nearest(maxRadius?) -> PlayerObject?, distance
-- Mencari avatar lain paling dekat dalam radius tertentu (studs)
local nearestTarget, distance = NX.Player().nearest(40)
if nearestTarget then
    NX.ConsoleMsg(string.format("Paling dekat: %s (Jarak: %.1f studs)", 
        nearestTarget.name, distance), "yellow")
end

-- 3. me.forEach(callback)
-- Melakukan perulangan ke seluruh player. Return false untuk break loop.
NX.Player().forEach(function(playerObj)
    print(playerObj.name, playerObj.CurrentPosition)
    if playerObj.name == "Admin" then
        return false -- Hentikan loop
    end
end)

-- 4. playerObj:DistanceTo(target) -> number
-- Mengukur jarak antara avatar ke objek lain (bisa PlayerObject atau Vector3)
if target then
    local dist = NX.Player().self:DistanceTo(target)
    print("Jarak ke target:", dist)
end
```

---

## 5. Inventory System — GetInvent, FindItem, CountItem

Inventory di-sync secara otomatis saat server mengirim `InventoryUpdatePacket (0x0010)`.

### 5.1. `NX.GetInvent()`
Mengembalikan tabel array murni (`#table`) berisi seluruh slot item tas:

```lua
local inv = NX.GetInvent()
NX.ConsoleMsg("Jumlah slot item di tas: " .. #inv, "cyan")

for index, item in ipairs(inv) do
    print(string.format("[%d] %s (ID: %d) x%d | Tipe: %s | Equipped: %s",
        index, item.name, item.id, item.count, item.type, tostring(item.equipped)))
end
```

#### Struktur Data `InvItem`:
```lua
{
    id        = 2,              -- (number) Item database ID
    count     = 150,            -- (number) Jumlah item tumpukan
    name      = "Dirt",         -- (string) Nama resmi dari ItemDatabase
    type      = "block",        -- (string) "block", "seed", "tool", "clothing", "consumable"
    rarity    = 1,              -- (number) Tingkat kelangkaan (0-7)
    stackable = true,           -- (boolean)
    maxStack  = 200,            -- (number) Kapasitas max tumpukan
    equipped  = false,          -- (boolean) Sedang dipakai di badan avatar
    flags     = 0               -- (number) Bitmask state item
}
```

### 5.2. Query Helpers:
```lua
-- A. Mencari 1 item pertama (by nama atau by ID)
local pickaxe = NX.FindItem("Pickaxe")
local seedItem = NX.FindItem(18) -- ID 18
if pickaxe then
    print("Punya pickaxe:", pickaxe.name, "Equipped:", pickaxe.equipped)
end

-- B. Menghitung total item di seluruh slot (akumulasi jika split slot)
local totalDirt = NX.CountItem("Dirt")
print("Total Dirt di tas:", totalDirt)

-- C. Pengecekan boolean cepat (HasItem)
if NX.HasItem("World Lock", 1) then
    NX.ConsoleMsg("Punya minimal 1 World Lock!", "green")
end

-- D. Mengambil seluruh item yang sedang dipakai (Equipped)
local wornItems = NX.GetEquipped()
for _, item in ipairs(wornItems) do
    print("Sedang memakai:", item.name)
end

-- E. Filter berdasarkan kategori tipe
local allSeeds = NX.GetByType("seed")
print("Total variasi seed:", #allSeeds)
```

---

## 6. World & Tile Grid — GetTile, FindTiles, TileAt

Map GrowBlox terdiri dari grid ukuran `100 x 60` tile.

### 6.1. `NX.GetTile(x, y)` → TileObject?
Mengambil data detail pada koordinat grid tertentu (0-indexed).

```lua
local tile = NX.GetTile(10, 20)
if tile then
    print("Tile (10, 20):")
    print("  Foreground ID :", tile.foreground)
    print("  Background ID :", tile.background)
    print("  Growth Stage  :", tile.growth) -- 0 sampai 7 untuk pohon
    print("  Lock Owner ID :", tile.lockOwner)

    -- Method Helper Boolean:
    print("  Solid Wall?   :", tile:isSolid())   -- Menahan player
    print("  Is Locked?    :", tile:isLocked())  -- Terkunci
    print("  Is Tree?      :", tile:isTree())    -- Ada tanaman
    print("  Is Door?      :", tile:isDoor())    -- Portal/Pintu
    print("  Is Empty?     :", tile:isEmpty())   -- Udara kosong (tanpa balok)
end
```

### 6.2. `NX.FindTiles(predicate)` → TileObject[]
Menyaring seluruh map dengan kriteria kustom. Sangat cepat karena diiterasi dari memory cache lokal.

```lua
-- A. Mencari seluruh pohon yang sudah matang (growth == 7) siap dipanen
local readyTrees = NX.FindTiles(function(t)
    return t:isTree() and t.growth >= 7
end)
NX.ConsoleMsg("Pohon siap panen: " .. #readyTrees, "green")

-- B. Mencari semua tile kosong yang aman untuk ditanami bibit
local plantableTiles = NX.FindTiles(function(t)
    return t:isEmpty() and not t:isLocked()
end)

-- C. Mencari posisi World Lock di map
local locks = NX.FindTiles(function(t)
    return t.foreground == 242 -- ID World Lock
end)
```

### 6.3. `NX.TileAt(worldPosition: Vector3)` → TileObject?
Mengonversi koordinat dunia Vector3 (posisi avatar) ke grid Tile secara otomatis:
```lua
local myPos = NX.Player().CurrentPosition
local currentTile = NX.TileAt(myPos)
if currentTile then
    print("Avatar sedang berdiri di atas tile ID:", currentTile.foreground)
end
```

---

## 7. Teleport & Pathfinding — NX.FindPath (Method 1 & 2)

Fitur navigasi cerdas dengan dua metode berbeda sesuai kebutuhan kasus:

### Signature:
```lua
local handle = NX.FindPath(x: number, y: number, method: number?, callback: function?)
```

### Parameter:
* `x`, `y` (`number`): Koordinat target grid tile tujuan.
* `method` (`number`):
  * `1` (**Direct Teleport**): Mengirim 1 `MovementPacket` instan ke titik target. Tanpa jeda, langsung tiba.
  * `2` (**A\* Grid Walk**): Menghitung rute A* yang bebas dari tembok solid (`TILE_SOLID`), lalu melangkahkan avatar step-by-step dengan micro-delay (`0.08s`) dan interpolasi velocity. Terlihat natural bagi server dan anti-kick.
* `callback` (`function(success: boolean, finalPos: Vector3)`): Dipanggil saat tiba di tujuan atau jika jalur gagal ditemukan.
* *Return:* `handle` `{ Cancel: function }` untuk membatalkan proses jalan di tengah jalan.

### Contoh Penggunaan:

```lua
-- ==============================================================
-- METODE 1: TELEPORT INSTAN (Method 1)
-- ==============================================================
NX.FindPath(25, 40, 1, function(ok, pos)
    if ok then
        NX.ConsoleMsg("Teleport instan berhasil ke " .. tostring(pos), "green")
    end
end)

-- ==============================================================
-- METODE 2: A* COLLISION-AWARE WALK (Method 2)
-- Menghindari balok solid dan berjalan natural
-- ==============================================================
local walkTask = NX.FindPath(80, 20, 2, function(success, pos)
    if success then
        NX.ConsoleMsg("Tiba di tujuan dengan selamat!", "green")
        -- Mulai aksi panen atau memukul balok di sini:
        NX.SendPkt("BreakBlockPacket", { x = 80, y = 20 })
    else
        NX.ConsoleMsg("Gagal: Rute terhalang oleh tembok/tanah tertutup!", "red")
    end
end)

-- Jika perlu membatalkan navigasi sewaktu-waktu:
NX.After(3, function()
    -- walkTask.Cancel() -- Batalkan jika player ingin berhenti
end)
```

---

## 8. MultiPacket Engine — SendMulti, SendChain, SendIf, Macro

Menyelesaikan masalah kompleks di mana **beberapa tipe packet harus dikirim dalam satu alur teratur**.

### 8.1. `NX.SendMulti(...)` — Atomic Frame Batch
Mengirim banyak packet berbeda tipe sekaligus dalam 1 frame flush yang sama.

```lua
-- Membeli item lalu seketika memasangnya di badan (Buy + Wear di frame yang sama)
NX.SendMulti(
    { "BuyPacket",      { shopId = 1, itemId = 300, count = 1 } },
    { "WearItemPacket", { itemId = 300 } },
    { "EmotePacket",    { emoteId = 2 } }
)
```

### 8.2. `NX.SendChain(steps)` — Sequenced Execution with Delays
Mengirim packet berurutan dengan jeda waktu teratur per langkah. Menghindari packet bertubrukan sebelum server sempat merespons langkah sebelumnya.

*Format step:* `{ "PacketName", payloadTable, delayAfterStepInSeconds? }`

```lua
local chain = NX.SendChain({
    -- Langkah 1: Beli item dari shop, tunggu 0.2 detik agar masuk inventory
    { "BuyPacket", { shopId = 1, itemId = 18, count = 5 }, 0.2 },

    -- Langkah 2: Tanam bibit di koordinat (10, 20), tunggu 0.1 detik
    { "UseItemPacket", { itemId = 18, x = 10, y = 20 }, 0.1 },

    -- Langkah 3: Beri notifikasi chat
    { "ChatPacket", { message = "Bibit berhasil ditanam!", channel = 0 } }
})

-- Bisa di-cancel jika kondisi berubah:
-- chain.Cancel()
```

### 8.3. `NX.SendIf(condition, thenPackets, elsePackets?)`
Kondisional packet pipeline. Mengirim kumpulan packet A jika kondisi terpenuhi, atau packet B jika tidak.

```lua
-- Cek apakah player memiliki bibit sebelum menaruh
NX.SendIf(
    NX.HasItem("Magic Seed", 1),
    {
        { "UseItemPacket", { itemId = 18, x = 15, y = 20 } }
    },
    {
        { "ChatPacket", { message = "Stok bibit habis!", channel = 0 } }
    }
)
```

### 8.4. Macro Reusable Engine (`NX.DefineMacro` & `NX.RunMacro`)
Membuat template kombinasi packet sekali, lalu menjalankannya berulang kali dengan parameter koordinat dinamis.

```lua
-- 1. Definisikan Macro:
NX.DefineMacro("PlantSequence", {
    { "BreakBlockPacket", { x = 0, y = 0 }, 0.08 }, -- Pukul dulu
    { "UseItemPacket",    { itemId = 18, x = 0, y = 0 } } -- Tanam seed
})

-- 2. Jalankan Macro dengan koordinat berbeda-beda:
NX.RunMacro("PlantSequence", {
    { x = 10, y = 15 },             -- Override step 1
    { itemId = 18, x = 10, y = 15 } -- Override step 2
})

NX.RunMacro("PlantSequence", {
    { x = 11, y = 15 },
    { itemId = 18, x = 11, y = 15 }
})
```

---

## 9. Action Presets Majemuk

Fungsi tingkat tinggi yang sudah dirakit siap pakai:

```lua
-- 1. Beli dari toko dan langsung letakkan di tile (x, y)
NX.MultiPacket.BuyAndPlace(shopId, itemId, count, x, y)

-- 2. Menempatkan barisan balok lurus (Horizontal Line Placer)
-- Param: itemId, startX, y, length, direction (1 = kanan, -1 = kiri)
NX.MultiPacket.PlaceRow(2, 10, 25, 15, 1)

-- 3. Menghancurkan area kotak persegi (Area Destroyer)
-- Param: x1, y1, x2, y2
NX.MultiPacket.BreakRect(10, 20, 15, 25)

-- 4. Pakai item lalu gunakan pada tile
NX.MultiPacket.EquipAndUse(itemId, tileX, tileY)

-- 5. Crafting lalu otomatis memakai hasilnya
NX.MultiPacket.CraftAndWear(recipeId, resultItemId)

-- 6. Jual-Beli Arbitrage Otomatis Antar Toko
NX.MultiPacket.BuySellArbitrage(buyShopId, sellShopId, itemId, count)

-- 7. Ajukan Trade dan Otomatis Isi Penawaran Item
NX.MultiPacket.TradeAndConfirm(targetUserId, {
    { id = 50,  count = 10 },
    { id = 300, count = 1 }
})
```

---

## 10. SmoothBuf — Frame Batching & Anti-Lag

Jika script executor mengirim puluhan `SendPkt` per detik secara mentah, Roblox akan mengalami spike network CPU dan server akan melakukan auto-kick.

`SmoothBuf` memecahkan masalah ini dengan cara:
1. Menyimpan packet dalam memori queue per-frame.
2. Menggabungkannya saat event `RunService.Heartbeat` terjadi (1 flush per frame).
3. Mengurangi overhead syscall socket RemoteEvent hingga 80%.

```lua
-- Aktifkan SmoothBuf
NX.SetSmoothBuf(true)

-- Jika butuh melepaskan antrean saat ini secara paksa (misal sebelum teleport):
NX.SmoothBuf.Flush()

-- Cek jumlah packet yang sedang antre di buffer:
local pending = NX.SmoothBuf.GetQueueSize()
print("Packet antre:", pending)

-- Mengatur frekuensi flush (default = 1 frame)
NX.SmoothBuf.SetFlushRate(1)
```

---

## 11. Scheduler — After, Every, Cancel, NextFrame

Manajemen waktu tugas berulang yang aman dari memory leak.

```lua
-- A. Menjalankan 1 kali setelah jeda waktu (detik)
local t1 = NX.After(2.5, function()
    NX.ConsoleMsg("2.5 detik telah berlalu!", "yellow")
end)

-- B. Menjalankan tugas berulang setiap N detik
local count = 0
local repeatTask = NX.Every(1.0, function()
    count += 1
    NX.ConsoleMsg("Tick: " .. count)

    -- Self-cancel: Return false dari dalam fungsi untuk berhenti otomatis
    if count >= 10 then
        NX.ConsoleMsg("Selesai 10 hitungan. Loop berhenti.", "green")
        return false
    end
end)

-- C. Membatalkan tugas secara manual dari luar:
NX.After(5, function()
    NX.Cancel(repeatTask)
end)

-- D. Menjalankan fungsi tepat pada 1 frame berikutnya:
NX.NextFrame(function()
    print("Frame render berikutnya!")
end)
```

---

## 12. Event Bus — On, Off, Emit, Once

Sistem komunikasi internal reaktif berbasis event:

```lua
-- A. Subscribe ke event built-in framework:
local joinListener = NX.Events.On("player:join", function(playerObj)
    NX.ConsoleMsg("Player Masuk: " .. playerObj.name, "green")
end)

-- B. Unsubscribe event:
NX.Events.Off(joinListener)

-- C. Subscribe 1 kali saja (auto hapus setelah terpanggil):
NX.Events.Once("world:loaded", function(worldData)
    NX.ConsoleMsg("Selamat datang di world: " .. worldData.name, "cyan")
end)

-- D. Emit Custom Event Antar-Script:
NX.Events.Emit("autoFarm:statusChanged", { active = true, speed = 25 })

NX.Events.On("autoFarm:statusChanged", function(state)
    print("Status bot:", state.active, "Kecepatan:", state.speed)
end)
```

### Event Bawaan Framework yang Tersedia:
| Event Name | Parameter Data | Kapan Dipicu |
|:---|:---|:---|
| `"player:join"` | `PlayerObject` | Avatar lain masuk map |
| `"player:leave"` | `PlayerObject` | Avatar lain keluar map |
| `"inventory:update"` | `InvItem[]` | Tas inventory diperbarui dari server |
| `"world:loaded"` | `WorldData` | Data map dunia selesai di-load |
| `"tile:update"` | `TileObject` | Balok di map dipukul, dipasang, atau diubah |
| `"tile:growth"` | `TileObject` | Pohon atau tanaman naik stage |
| `"teleport:arrive"` | `{ x, y, method }` | Method navigasi `FindPath` tiba di tujuan |
| `"teleport:npath"` | `{ x, y }` | Rute A* `FindPath` tidak menemukan jalan |
| `"smoothbuf:flush"` | `count: number` | Batch packet frame dilepaskan |
| `"packet:<id>"` | `data` | Semua packet masuk (misal: `"packet:16"`) |

---

## 13. Console & Output — ConsoleMsg, Log, Clear

Menampilkan informasi berwarna pada GUI game console internal dan standard output Roblox:

```lua
-- Teks dengan pilihan warna instan:
NX.ConsoleMsg("Operasi Berhasil!", "green")
NX.ConsoleMsg("Peringatan Sistem", "yellow")
NX.ConsoleMsg("Terjadi Kesalahan!", "red")
NX.ConsoleMsg("Info Navigasi", "cyan")
NX.ConsoleMsg("Data Ringan", "gray")
NX.ConsoleMsg("Penting", "orange")
NX.ConsoleMsg("Khusus", "purple")

-- Menggunakan Color3 custom:
NX.ConsoleMsg("Custom RGB", Color3.fromRGB(255, 100, 200))

-- Log berjenjang (hanya muncul jika LogLevel mencukupi):
NX.ConsoleLog("Pesan info biasa", 1)
NX.ConsoleLog("Pesan detail debug", 2)

-- Bersihkan riwayat konsol:
NX.ConsoleClear()
```

---

## 14. Utils Library

Fungsi pembantu yang siap digunakan untuk kalkulasi script:

```lua
local U = NX.Utils

-- String Helpers
U.trim("   teks rapi   ")         -- "teks rapi"
U.split("apel,jeruk,mangga", ",") -- {"apel", "jeruk", "mangga"}
U.startsWith("ChatPacket", "Chat")-- true

-- Math & Jarak
local dist = U.dist2D(0, 0, 10, 10)
local rounded = U.round(3.14159, 2) -- 3.14
local clamped = U.clamp(120, 0, 100)-- 100

-- Format Waktu
print(U.formatTime(3665)) -- "01:01:05"

-- Konversi Packet ID ke Nama
print(U.pktIdToName(0x0004)) -- "PlaceBlockPacket"
print(U.pktIdToHex(4))       -- "0x0004"
```

---

## 15. Studi Kasus Proyek Nyata

### Kasus 1: Auto-Harvest & Replant Bot Cerdas
Bot otomatis mencari pohon matang terdekat, berjalan menghindari tembok via A* (Method 2), memanen pohon, dan menanam ulang bibit.

```lua
local NX = require(game.ReplicatedStorage.NXroENinD_DPcKage)
NX.Init({ SmoothBuf = true })

local function HarvestCycle()
    -- 1. Cari pohon yang sudah siap panen (growth == 7)
    local readyTrees = NX.FindTiles(function(t)
        return t:isTree() and t.growth >= 7
    end)

    if #readyTrees == 0 then
        NX.ConsoleMsg("Belum ada pohon matang. Menunggu...", "gray")
        return
    end

    local target = readyTrees[1]
    NX.ConsoleMsg(string.format("Menuju pohon di (%d, %d)...", target.x, target.y), "cyan")

    -- 2. Jalan natural menghindari balok solid (Method 2)
    NX.FindPath(target.x, target.y, 2, function(arrived)
        if not arrived then return end

        -- 3. Hancurkan / Panen pohon
        NX.SendPkt("BreakBlockPacket", { x = target.x, y = target.y })

        -- 4. Tanam kembali setelah 0.2 detik jika punya seed di inventory
        NX.After(0.2, function()
            local seed = NX.FindItem("Seed")
            if seed and seed.count > 0 then
                NX.SendPkt("UseItemPacket", { itemId = seed.id, x = target.x, y = target.y })
                NX.ConsoleMsg("Pohon dipanen dan ditanam ulang!", "green")
            end
        end)
    end)
end

-- Jalankan pengecekan setiap 4 detik:
local farmLoop = NX.Every(4.0, HarvestCycle)
```

---

### Kasus 2: High-Speed Controlled Packet Spammer Macro
Contoh lengkap mengirim packet aksi berkecepatan tinggi dengan jeda acak (micro-jitter) dan kontrol batasan rate server:

```lua
local NX = require(game.ReplicatedStorage.NXroENinD_DPcKage)
NX.Init({ SmoothBuf = true })

-- Siapkan antrean spammer
local isSpamming = true
local startX, startY = 10, 20
local currentX = startX

NX.ConsoleMsg("Memulai Controlled Spammer Macro...", "green")

-- Worker Loop dengan jeda 0.04 detik + random jitter
task.spawn(function()
    while isSpamming do
        -- Kirim packet aksi penempatan balok
        NX.SendPkt("PlaceBlockPacket", {
            x = currentX,
            y = startY,
            itemId = 2 -- Dirt Block
        })

        currentX += 1
        if currentX > startX + 20 then
            currentX = startX
        end

        -- Jeda dinamis acak (35ms - 45ms)
        local jitter = (math.random() - 0.5) * 0.010
        task.wait(0.04 + jitter)
    end
end)

-- Hentikan otomatis setelah 8 detik:
NX.After(8.0, function()
    isSpamming = false
    NX.ConsoleMsg("Spammer selesai dihentikan dengan aman.", "yellow")
end)
```

---

*NXroENinD_DPcKage — Dokumentasi Resmi API & Panduan Implementasi Lengkap.*
