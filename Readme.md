# 📚 NXroENinD_DPcKage — Master Technical Specification & Architecture Manual

---

## 📑 Daftar Isi
1. [Arsitektur Memori DLL & Struct Protocol](#1-arsitektur-memori-dll--struct-protocol)
2. [Tabel Lengkap 39 Tipe Packet & Wire Serialization](#2-tabel-lengkap-39-tipe-packet--wire-serialization)
3. [Tabel Enum, Action & Bitmask Flags](#3-tabel-enum-action--bitmask-flags)
4. [Framework Core Architecture & API Guide](#4-framework-core-architecture--api-guide)
5. [Solusi Kasus & Masalah Kompleks](#5-solusi-kasus--masalah-kompleks)
   - Kasus A: Dual-Method Pathfinding & Collision-Aware Traversal
   - Kasus B: Composite Atomic Packet Pipelines (Buy → Place → Verify)
   - Kasus C: Zero-Lag In-Game Avatar State Tracking (Bypass Roblox Service)
   - Kasus D: Anti-Kick Packet Spammer & Burst Rate Limiting Engine
6. [Implementasi Lengkap Script Spammer Macro Berstruktur](#6-implementasi-lengkap-script-spammer-macro-berstruktur)

---

## Import Awal
```
loadstring(game:HttpGet("https://raw.githubusercontent.com/Mytzcodes/Gbxzcf0x2993HsFDj1/refs/heads/main/NXroENinD_DPcKage_Loader.lua"))()
```

## 1. Arsitektur Memori DLL & Struct Protocol

Model struct didesain setara standard industri hook GrowLauncher dan GentaHax dengan binary packing 1 byte (`#pragma pack(push, 1)`). Seluruh data dapat di-map langsung ke FFI C/C++ memory pointer tanpa alignment padding tersembunyi.

```cpp
// ============================================================================
// NXroENinD_DPcKage CORE MEMORY & DLL PACKET DEFINITIONS
// Memory alignment: 1-Byte Packed
// ============================================================================

#pragma pack(push, 1)

// --- Primitive Math Structs ---
typedef struct _VEC2_F32 {
    float x;                     // Offset 0x00 (4 bytes)
    float y;                     // Offset 0x04 (4 bytes)
} VEC2_F32; // Total: 8 bytes

typedef struct _VEC3_F32 {
    float x;                     // Offset 0x00 (4 bytes)
    float y;                     // Offset 0x04 (4 bytes)
    float z;                     // Offset 0x08 (4 bytes)
} VEC3_F32; // Total: 12 bytes

typedef struct _CFRAME_T {
    VEC3_F32 position;          // Offset 0x00 (12 bytes)
    VEC3_F32 rotation;          // Offset 0x0C (12 bytes, Euler Radians)
} CFRAME_T; // Total: 24 bytes

// --- Low-Level Packet Transport Header ---
typedef struct _NET_PACKET_HEADER {
    uint16_t packetId;          // Offset 0x00 (2 bytes) - Identifier 0x0001 to 0xFFFF
    uint16_t payloadLength;     // Offset 0x02 (2 bytes) - Ukuran buffer data
    uint8_t  channel;           // Offset 0x04 (1 byte)  - 0: Reliable, 1: Unreliable
    uint8_t  flags;             // Offset 0x05 (1 byte)  - Bit 0: Compressed, Bit 1: Encrypted
    uint32_t sequence;          // Offset 0x06 (4 bytes) - Packet Counter
    uint32_t timestamp;         // Offset 0x0A (4 bytes) - Client/Server Tick Timestamp
} NET_PACKET_HEADER; // Total: 14 bytes

// --- In-Game Avatar State (Net-Sourced) ---
typedef struct _NET_AVATAR_STATE {
    uint32_t  userId;           // Offset 0x00 (4 bytes) - In-game unique entity id
    char      name[32];         // Offset 0x04 (32 bytes)- Display name (null-terminated)
    VEC3_F32  currentPosition;  // Offset 0x24 (12 bytes)- Live Vector3 coordinates
    VEC3_F32  currentVelocity;  // Offset 0x30 (12 bytes)- Live Physics velocity
    float     currentRotation;  // Offset 0x3C (4 bytes) - Y-axis rotation (radians)
    uint8_t   animationState;   // Offset 0x40 (1 byte)  - Animation enum
    uint8_t   isLocalAvatar;    // Offset 0x41 (1 byte)  - 1 if local client entity
    uint8_t   isInWorld;        // Offset 0x42 (1 byte)  - 1 if loaded in world
    uint8_t   reservedPadding;  // Offset 0x43 (1 byte)  - Alignment padding
    uint32_t  pingMs;           // Offset 0x44 (4 bytes) - Round-trip latency
} NET_AVATAR_STATE; // Total: 72 bytes

// --- Inventory Slot Item Struct ---
typedef struct _NET_INVENTORY_ITEM {
    uint16_t itemId;            // Offset 0x00 (2 bytes) - Item ID
    uint16_t count;             // Offset 0x02 (2 bytes) - Stack quantity
    uint8_t  flags;             // Offset 0x04 (1 byte)  - Bit 0: Equipped, Bit 1: Favorite, Bit 2: Locked
    uint8_t  customData;        // Offset 0x05 (1 byte)  - Sub-type / durability data
} NET_INVENTORY_ITEM; // Total: 6 bytes

// --- Full Inventory Memory Layout ---
typedef struct _NET_INVENTORY_CONTAINER {
    uint16_t           slotCount;       // Offset 0x00 (2 bytes) - Active slots
    uint16_t           maxCapacity;     // Offset 0x02 (2 bytes) - Maximum bag limit
    NET_INVENTORY_ITEM items[256];      // Offset 0x04 (1536 bytes) - 256 slots
} NET_INVENTORY_CONTAINER; // Total: 1540 bytes

// --- Tile Matrix Element ---
typedef struct _WORLD_TILE {
    uint16_t foreground;        // Offset 0x00 (2 bytes) - Foreground Item ID
    uint16_t background;        // Offset 0x02 (2 bytes) - Background Item ID
    uint32_t flags;             // Offset 0x04 (4 bytes) - Bitmask state
    uint8_t  growthStage;       // Offset 0x08 (1 byte)  - Tree/Crop progress (0-7)
    uint8_t  waterLevel;        // Offset 0x09 (1 byte)  - Liquid level (0-255)
    uint16_t lockOwnerId;       // Offset 0x0A (2 bytes) - User ID lock master
} WORLD_TILE; // Total: 12 bytes

// --- Complete World State Memory ---
typedef struct _WORLD_CONTAINER {
    char        worldName[24];  // Offset 0x00 (24 bytes)- UTF-8 World Name
    uint16_t    width;          // Offset 0x18 (2 bytes) - Lebar grid (e.g. 100)
    uint16_t    height;         // Offset 0x1A (2 bytes) - Tinggi grid (e.g. 60)
    uint32_t    ownerUserId;    // Offset 0x1C (4 bytes) - Pemilik World Lock
    uint8_t     weatherId;      // Offset 0x20 (1 byte)  - Weather Enum
    float       weatherParam;   // Offset 0x21 (4 bytes) - Intensitas cuaca
    WORLD_TILE  tiles[6000];    // Offset 0x25 (72000 bytes) - 100 x 60 Tiles
} WORLD_CONTAINER; // Total: 72037 bytes

#pragma pack(pop)
```

---

## 2. Tabel Lengkap 39 Tipe Packet & Wire Serialization

Sistem transmisi packet menggunakan **ByteNet Frame Protocol**:  
Format Frame: `[u16 PacketID] [N Bytes Payload] ... (Batched per-frame via Heartbeat)`

| Hex ID | Des | Nama Packet | Arah | Channel | Payload Schema | Deskripsi & Validasi |
|:---:|:---:|:---|:---:|:---:|:---|:---|
| `0x0001` | 1 | `InputPacket` | C→S | Reliable | `{ action: u8, state: bool, position: vec3 }` | Aksi input mentah keyboard/mouse |
| `0x0002` | 2 | `MovementPacket` | C→S | **Unreliable** | `{ position: vec3, velocity: vec3, rotation: f32 }` | Sinkronisasi posisi avatar |
| `0x0003` | 3 | `ChatPacket` | Bi | Reliable | `{ message: string, channel: u8 }` | Pesan obrolan dunia/global/whisper |
| `0x0004` | 4 | `PlaceBlockPacket` | C→S | Reliable | `{ x: i32, y: i32, itemId: u16 }` | Penempatan balok/item di tile |
| `0x0005` | 5 | `BreakBlockPacket` | C→S | Reliable | `{ x: i32, y: i32 }` | Pukulan atau penghancuran balok |
| `0x0006` | 6 | `DropItemPacket` | C→S | Reliable | `{ itemId: u16, count: u16 }` | Menjatuhkan item dari tas ke tanah |
| `0x0007` | 7 | `CollectItemPacket` | C→S | Reliable | `{ objectId: u32 }` | Mengambil floating drop item |
| `0x0008` | 8 | `WearItemPacket` | C→S | Reliable | `{ itemId: u16 }` | Memakai aksesoris/baju/sayap/alat |
| `0x0009` | 9 | `RemoveItemPacket` | C→S | Reliable | `{ itemId: u16 }` | Melepas perlengkapan avatar |
| `0x000A` | 10 | `TrashItemPacket` | C→S | Reliable | `{ itemId: u16, count: u16 }` | Membuang item permanen (recycle/trash) |
| `0x000B` | 11 | `UseItemPacket` | C→S | Reliable | `{ itemId: u16, x: i32, y: i32 }` | Konsumsi/aktivasi efek item khusus |
| `0x000C` | 12 | `EnterDoorPacket` | C→S | Reliable | `{ x: i32, y: i32 }` | Masuk ke portal, pintu, atau gateway |
| `0x000D` | 13 | `WorldRequestPacket` | C→S | Reliable | `{ worldName: string }` | Permintaan berpindah/memasuki world |
| `0x000E` | 14 | `WorldDataPacket` | S→C | Reliable | `{ worldData: buff }` | Binary blob seluruh map dan data world |
| `0x000F` | 15 | `TileUpdatePacket` | S→C | Reliable | `{ x: i32, y: i32, fg: u16, bg: u16, flags: u32 }` | Update instan status 1 tile |
| `0x0010` | 16 | `InventoryUpdatePacket` | S→C | Reliable | `{ items: array<{ id: u16, count: u16 }> }` | Sinkronisasi penuh daftar inventory |
| `0x0011` | 17 | `PlayerJoinPacket` | S→C | Reliable | `{ userId: u32, name: string, position: vec3 }` | Notifikasi player lain masuk world |
| `0x0012` | 18 | `PlayerLeavePacket` | S→C | Reliable | `{ userId: u32 }` | Notifikasi player meninggalkan world |
| `0x0013` | 19 | `PlayerUpdatePacket` | S→C | **Unreliable** | `{ userId: u32, position: vec3, rotation: f32, anim: u8 }` | Posisi live seluruh entitas lain |
| `0x0014` | 20 | `ConsoleMessagePacket` | S→C | Reliable | `{ text: string, color: u32 }` | Pesan sistem server / notification banner |
| `0x0015` | 21 | `DialogPacket` | S→C | Reliable | `{ dialogType: u8, title: string, body: string }` | Pembukaan pop-up UI dialog |
| `0x0016` | 22 | `TradeRequestPacket` | Bi | Reliable | `{ targetUserId: u32 }` | Inisiasi ajakan transaksi barter |
| `0x0017` | 23 | `TradeUpdatePacket` | Bi | Reliable | `{ items: array<{ id: u16, count: u16 }>, confirmed: bool }` | Penawaran & lock status trade |
| `0x0018` | 24 | `PingPacket` | Bi | **Unreliable** | `{ timestamp: f64 }` | Heartbeat latency check |
| `0x0019` | 25 | `SyncClockPacket` | S→C | Reliable | `{ serverTime: f64 }` | Sinkronisasi waktu server epoch |
| `0x001A` | 26 | `AdminCommandPacket` | C→S | Reliable | `{ command: string, args: string }` | Perintah konsol administratif |
| `0x001B` | 27 | `NpcInteractPacket` | C→S | Reliable | `{ npcId: u32, option: u8 }` | Pilihan interaksi dialog NPC |
| `0x001C` | 28 | `CraftPacket` | C→S | Reliable | `{ recipeId: u16 }` | Permintaan crafting kombinasi item |
| `0x001D` | 29 | `BuyPacket` | C→S | Reliable | `{ shopId: u16, itemId: u16, count: u16 }` | Pembelian item dari shop vendor |
| `0x001E` | 30 | `SellPacket` | C→S | Reliable | `{ shopId: u16, itemId: u16, count: u16 }` | Penjualan item ke vendor |
| `0x001F` | 31 | `SignEditPacket` | C→S | Reliable | `{ x: i32, y: i32, text: string }` | Menulis/mengubah isi teks papan tanda |
| `0x0020` | 32 | `LockPacket` | C→S | Reliable | `{ x: i32, y: i32, action: u8 }` | Manajemen kunci wilayah (WL/SL/BL) |
| `0x0021` | 33 | `FriendPacket` | C→S | Reliable | `{ targetUserId: u32, action: u8 }` | Add, Accept, Block relasi pertemanan |
| `0x0022` | 34 | `EmotePacket` | C→S | Reliable | `{ emoteId: u8 }` | Memicu animasi gestur emote |
| `0x0023` | 35 | `RespawnPacket` | C→S | Reliable | `{}` | Permintaan spawn ulang ke checkpoint |
| `0x0024` | 36 | `GrowthUpdatePacket` | S→C | Reliable | `{ x: i32, y: i32, stage: u8 }` | Perubahan fase pohon/tanaman |
| `0x0025` | 37 | `WeatherPacket` | S→C | Reliable | `{ weatherType: u8, intensity: f32 }` | Penggantian tema atmosfer & langit |
| `0x0026` | 38 | `EffectPacket` | S→C | Reliable | `{ effectType: u8, position: vec3, data: u32 }` | Pemutaran particle effect |
| `0x0027` | 39 | `SoundPacket` | S→C | Reliable | `{ soundId: u16, position: vec3, volume: f32 }` | Trigger SFX audio pada koordinat |

---

## 3. Tabel Enum, Action & Bitmask Flags

### 3.1. Tile State Bitmask Flags
```lua
NX.TileFlags = {
    TILE_SOLID       = 0x00000001, -- Menahan pergerakan (tembok/tanah)
    TILE_SEEDABLE    = 0x00000002, -- Dapat ditanam bibit
    TILE_FLIPPED     = 0x00000004, -- Sprite dibalik horizontal
    TILE_OPEN        = 0x00000008, -- Pintu dalam keadaan terbuka
    TILE_LOCKED      = 0x00000010, -- Diproteksi oleh lock
    TILE_WATER       = 0x00000020, -- Mengandung elemen air
    TILE_FIRE        = 0x00000040, -- Mengandung elemen api/lava berbahaya
    TILE_RED         = 0x00000080, -- Tint merah
    TILE_GREEN       = 0x00000100, -- Tint hijau
    TILE_BLUE        = 0x00000200, -- Tint biru
    TILE_PUBLIC      = 0x00000400, -- Area bangunan terbuka untuk umum
    TILE_SILENCED    = 0x00000800, -- Area tanpa suara
    TILE_MANNEQUIN   = 0x00001000, -- Memiliki data pajangan kostum
    TILE_SIGN        = 0x00002000, -- Memiliki data papan teks baca
    TILE_TREE        = 0x00004000, -- Terdapat pohon/tanaman bertumbuh
    TILE_PROVIDER    = 0x00008000, -- Mesin penghasil item periodik
    TILE_DEADLY      = 0x00010000, -- Membunuh player seketika jika tersentuh
    TILE_CHECKPOINT  = 0x00020000, -- Tempat respawn
    TILE_GATEWAY     = 0x00040000, -- Portal perpindahan sub-world
}
```

### 3.2. Action Enums
```lua
NX.InputAction = {
    NONE = 0, PUNCH = 1, PLACE = 2, JUMP = 3, MOVE_LEFT = 4,
    MOVE_RIGHT = 5, MOVE_UP = 6, MOVE_DOWN = 7, INTERACT = 8,
    WRENCH = 9, RESPAWN = 10, EMOTE = 11, ENTER_PORTAL = 12
}

NX.LockAction = {
    PLACE_LOCK = 0, REMOVE_LOCK = 1, ADD_ACCESS = 2, REMOVE_ACCESS = 3, TOGGLE_PUBLIC = 4
}

NX.FriendAction = {
    REQUEST = 0, ACCEPT = 1, DECLINE = 2, REMOVE = 3, BLOCK = 4
}

NX.AnimationState = {
    IDLE = 0, WALK = 1, RUN = 2, JUMP = 3, FALL = 4, PUNCH = 5,
    PLACE = 6, SWIM = 7, DANCE = 8, WAVE = 9, SIT = 10, SLEEP = 11
}
```

---

## 4. Framework Core Architecture & API Guide

Sistem `NXroENinD_DPcKage` didesain modular, efisien (zero FPS cost saat idle), dan dapat di-bootstrap melalui URL GitHub tunggal:

```lua
-- Single Bootstrap Loader
loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/NXroENinD_DPcKage_Loader.lua", true))()

-- Inisialisasi Environment
NX.Init({
    SmoothBuf = true, -- Mengaktifkan packet frame batching
    LogLevel = 1,
    ConsolePrefix = "[NX-PRO]"
})
```

### 4.1. Network Core Interface
* `NX.SendPkt(packetRef, data)`: Mengirim typed packet (auto-queue bila SmoothBuf aktif).
* `NX.SendRaw(buffer)`: Mengirim binary buffer langsung ke socket RemoteEvent ByteNet.
* `NX.HookPkt(packetRef, callback)`: Memasang tap listener sebelum packet diproses game.
* `NX.UnhookPkt(handle)`: Melepaskan hook tap listener.

### 4.2. In-Game Avatar Interface (`NX.Player()`)
* `NX.Player().name`: Nama entitas in-game dari packet (bukan akun Roblox).
* `NX.Player().userId`: ID unik entitas game.
* `NX.Player().CurrentPosition`: Koordinat live `Vector3` dari packet stream.
* `NX.Player().CurrentVelocity`: Kecepatan live `Vector3`.
* `NX.Player().list`: Array seluruh avatar lain di map.
* `NX.Player().find(query)`: Cari avatar berdasarkan nama atau userId.
* `NX.Player().nearest(maxDist)`: Mendeteksi avatar paling dekat.

### 4.3. Inventory Matrix (`NX.GetInvent()`)
* Mengembalikan `#table` array dengan data item lengkap:
  `{ id, count, name, type, rarity, equipped, stackable, maxStack, flags }`
* `NX.FindItem(query)`: Mencari 1 item pertama berdasarkan nama/ID.
* `NX.CountItem(query)`: Menjumlah seluruh tumpukan item yang cocok.
* `NX.HasItem(query, minCount)`: Boolean ketersediaan item.
* `NX.GetEquipped()`: Menampilkan daftar item yang sedang dipakai di tubuh avatar.

### 4.4. World Tile Matrix (`NX.GetTile(x, y)`)
* `NX.GetTile(x, y)`: Mengembalikan TileObject dengan helper method `:isSolid()`, `:isLocked()`, `:isTree()`, dll.
* `NX.FindTiles(predicate)`: Filter seluruh map mencari tile spesifik (misal: semua pohon matang).
* `NX.TileAt(Vector3)`: Mengonversi koordinat dunia Vector3 menjadi TileObject.

---

## 5. Solusi Kasus & Masalah Kompleks

### Kasus A: Dual-Method Pathfinding & Collision-Aware Traversal
Navigasi dalam map sering mengalami masalah: terhalang tembok, jatuh, atau terkena ban karena teleport instan yang melewati proteksi koordinat.

`NXroENinD_DPcKage` menyediakan `NX.FindPath(x, y, method, callback)`:
1. **Method 1 (Direct Teleport):**
   * Mengirim 1 packet `MovementPacket` tunggal.
   * Instan, 0 delay, cocok untuk private world tanpa anti-noclip agresif.
2. **Method 2 (A* Collision-Aware Grid Walk):**
   * Menghitung jalur optimal A* melintasi tile yang tidak memiliki flag `TILE_SOLID`.
   * Mengirim rangkaian `MovementPacket` berkala dengan interpolasi `velocity` dan delay terukur (`STEP_DELAY = 0.08s`), terlihat natural bagi server dan terhindar dari kick.

```lua
-- Contoh Navigasi Cerdas Menghindari Rintangan Menuju Pohon
local ripeTrees = NX.FindTiles(function(t) return t:isTree() and t.growth >= 7 end)
if #ripeTrees > 0 then
    local target = ripeTrees[1]
    NX.ConsoleMsg("Menuju target (" .. target.x .. ", " .. target.y .. ") via Method 2...", "cyan")
    
    local walk = NX.FindPath(target.x, target.y, 2, function(success, finalPos)
        if success then
            NX.ConsoleMsg("Sampai di pohon! Memulai harvest...", "green")
            NX.SendPkt("BreakBlockPacket", { x = target.x, y = target.y })
        else
            NX.ConsoleMsg("Gagal: Jalur terblokir solid tile!", "red")
        end
    end)
    
    -- Dapat dibatalkan sewaktu-waktu: walk.Cancel()
end
```

---

### Kasus B: Composite Atomic Packet Pipelines (Buy → Place → Verify)
Pada transaksi jual beli cepat atau building complex, packet sering hilang jika dikirim asynchronous tanpa urutan terpadu.

Gunakan pipeline berstruktur:
1. `NX.SendMulti(...)`: Menggabungkan beberapa packet berbeda tipe dalam 1 frame buffer atomic.
2. `NX.SendChain(steps)`: Eksekusi beruntun dengan jeda waktu teratur per-langkah.
3. `NX.SendIf(condition, thenPkts, elsePkts)`: Validasi state inventory sebelum melepaskan packet aksi.

```lua
-- Alur Kompleks: Membeli Seeds dari Shop, menanam di tanah, dan memverifikasi
local function AutomatedPlantingPipeline(shopId, seedId, tileX, tileY)
    NX.SendChain({
        -- Step 1: Beli item dari vendor dan beri waktu server meng-update inventory (0.2s)
        { "BuyPacket", { shopId = shopId, itemId = seedId, count = 1 }, 0.2 },

        -- Step 2: Validasi & Tanam menggunakan UseItemPacket
        { "UseItemPacket", { itemId = seedId, x = tileX, y = tileY }, 0.1 },

        -- Step 3: Kirim chat konfirmasi status
        { "ChatPacket", { message = "Planted at " .. tileX .. "," .. tileY, channel = 0 } }
    })
end
```

---

### Kasus C: Zero-Lag In-Game Avatar State Tracking
Kebanyakan script executor mengandalkan `game.Players.LocalPlayer.Character.HumanoidRootPart`. Kelemahannya:
* Karakter sering desync saat lag atau teleportasi.
* Nama akun Roblox bukan nama samaran in-game di private server.
* Animasi tidak mencerminkan state asli server.

`NXroENinD_DPcKage.Player()` membaca langsung dari wire packets:
* `CurrentPosition` diperbarui real-time saat `PlayerUpdatePacket (0x0013)` atau `MovementPacket (0x0002)` melintas.
* Nama player berasal langsung dari handshake `PlayerJoinPacket (0x0011)`.

```lua
-- Monitor koordinat nyata tanpa menyentuh HumanoidRootPart Roblox
NX.Every(1, function()
    local p = NX.Player()
    local pos = p.CurrentPosition
    local vel = p.CurrentVelocity
    NX.ConsoleMsg(string.format("Avatar: %s | Pos: (%.1f, %.1f) | Speed: %.1f", 
        p.name, pos.X, pos.Y, vel.Magnitude), "gray")
end)
```

---

### Kasus D: Anti-Kick Packet Spammer & Burst Rate Limiting Engine
Spam packet secara kasar (`while true do SendPkt(...) end`) akan:
1. Menyebabkan RemoteEvent queue overflow di Roblox engine (menjatuhkan FPS hingga freeze).
2. Memicu sistem deteksi server rate-limit (otomatis kicked: *"Too many requests"*).

Solusi pada `NXroENinD_DPcKage`:
* Memanfaatkan ring-buffer worker queue.
* Mengatur micro-jitter delay (menyerupai fluktuasi input manusia, misal 0.04s - 0.07s).
* Integrasi langsung dengan `NX.SmoothBuf` untuk mengelompokkan packet ke dalam batch frame render.

---

## 6. Implementasi Lengkap Script Spammer Macro Berstruktur

Berikut adalah implementasi script spammer modular profesional siap pakai dengan kontrol kecepatan, batch size, cancellation token, dan proteksi kick:

```lua
--[[
================================================================================
  NXroENinD_DPcKage — HIGH-SPEED BURST & SPAMMER ENGINE v3.0
  Feature:
    • Structured Queue with Micro-Delay Control
    • Anti-Kick Rate Limiting & Micro-Jitter
    • SmoothBuf Integration (Frame Batching)
    • Multi-Type Packet Support (Chat, Punch, Place, Emote)
    • Live Statistics & Auto Safety Brake
================================================================================
]]

local NX = require(game.ReplicatedStorage:WaitForChild("NXroENinD_DPcKage"))

-- ── 1. Inisialisasi Engine ──────────────────────────────────────────────────
NX.Init({
    SmoothBuf = true,       -- Wajib true untuk transmisi berkecepatan tinggi
    LogLevel = 1,
    ConsolePrefix = "[SPAM-ENGINE]"
})

-- ── 2. Definisi Modul Spammer Berstruktur ────────────────────────────────────
local SpammerEngine = {}
SpammerEngine.__index = SpammerEngine

function SpammerEngine.new(config)
    local self = setmetatable({}, SpammerEngine)
    self.config = {
        baseDelay     = config.baseDelay or 0.05,     -- Jeda dasar per-packet (detik)
        jitter        = config.jitter or 0.015,       -- Variasi acak (mencegah pola bot terdeteksi)
        maxBurstQueue = config.maxBurstQueue or 500,  -- Kapasitas maksimum antrean
        autoFlushSize = config.autoFlushSize or 5,    -- Flush buffer tiap N packet
        safetyBrake   = config.safetyBrake ~= false,  -- Hentikan otomatis jika lag tinggi
    }

    self.queue     = {}
    self.isRunning = false
    self.stats     = { sent = 0, dropped = 0, errors = 0, startTime = 0 }
    self.workerThread = nil
    return self
end

-- Menambahkan aksi ke dalam antrean (Enqueue)
function SpammerEngine:Push(packetNameOrId, payload)
    if #self.queue >= self.config.maxBurstQueue then
        self.stats.dropped += 1
        return false, "Queue Overflow"
    end

    table.insert(self.queue, {
        packet = packetNameOrId,
        data   = payload,
        time   = os.clock()
    })
    return true
end

-- Mengisi antrean secara masif (Batch Push)
function SpammerEngine:PushBulk(packetList)
    local accepted = 0
    for _, item in ipairs(packetList) do
        local ok = self:Push(item[1], item[2])
        if ok then accepted += 1 else break end
    end
    return accepted
end

-- Memulai Pemrosesan Antrean
function SpammerEngine:Start()
    if self.isRunning then return end
    self.isRunning = true
    self.stats.startTime = os.clock()
    NX.ConsoleMsg("Engine Spammer Aktif! Target Jeda: " .. self.config.baseDelay .. "s", "green")

    self.workerThread = task.spawn(function()
        local sentInCurrentBatch = 0

        while self.isRunning do
            if #self.queue > 0 then
                local taskItem = table.remove(self.queue, 1)

                -- Eksekusi Pengiriman Packet melalui Framework
                local ok, err = pcall(function()
                    NX.SendPkt(taskItem.packet, taskItem.data)
                end)

                if ok then
                    self.stats.sent += 1
                    sentInCurrentBatch += 1
                else
                    self.stats.errors += 1
                    warn("[SPAM-ENGINE] Error send: " .. tostring(err))
                end

                -- Flush buffer berkala untuk melepaskan batch
                if sentInCurrentBatch >= self.config.autoFlushSize then
                    NX.SmoothBuf.Flush()
                    sentInCurrentBatch = 0
                end

                -- Perhitungan Jeda Waktu Berstruktur (Base + Jitter)
                local randomJitter = (math.random() * 2 - 1) * self.config.jitter
                local sleepTime = math.max(0.005, self.config.baseDelay + randomJitter)
                task.wait(sleepTime)
            else
                -- Jika antrean kosong, bersihkan sisa batch dan tunggu
                if sentInCurrentBatch > 0 then
                    NX.SmoothBuf.Flush()
                    sentInCurrentBatch = 0
                end
                task.wait(0.05)
            end
        end
    end)
end

-- Menghentikan Pemrosesan
function SpammerEngine:Stop()
    self.isRunning = false
    if self.workerThread then
        task.cancel(self.workerThread)
        self.workerThread = nil
    end
    NX.SmoothBuf.Flush() -- Pastikan sisa buffer terkirim
    local duration = os.clock() - self.stats.startTime
    local rps = duration > 0 and (self.stats.sent / duration) or 0

    NX.ConsoleMsg(string.format("Spammer Berhenti! Terkirim: %d | Gagal: %d | Rata-rata: %.1f pkt/detik", 
        self.stats.sent, self.stats.errors, rps), "yellow")
end

-- Mengosongkan Antrean
function SpammerEngine:Clear()
    self.queue = {}
end

-- ── 3. Contoh Penggunaan Kasus Riil (Presets) ───────────────────────────────

-- Instansiasi Engine Spammer dengan konfigurasi aman
local spammer = SpammerEngine.new({
    baseDelay     = 0.04,   -- 25 packet per detik (sangat cepat tapi aman)
    jitter        = 0.008,  -- Variasi micro-jitter
    autoFlushSize = 4,      -- Batch flush tiap 4 paket
})

-- Skenario A: Rapid Punch Spammer (Menghancurkan Barisan Balok Sekitar)
function RunFastPunchMacro(startX, startY, count)
    spammer:Clear()
    NX.ConsoleMsg("Menyiapkan " .. count .. " packet punch...", "cyan")

    for i = 0, count - 1 do
        spammer:Push("BreakBlockPacket", {
            x = startX + (i % 5),
            y = startY + math.floor(i / 5)
        })
    end
    spammer:Start()
end

-- Skenario B: Rapid Emote & Chat Announce Spammer
function RunChatAnnouncementSpammer(message, repeatTimes)
    spammer:Clear()
    for i = 1, repeatTimes do
        -- Kombinasi packet Emote + Chat berurutan
        spammer:Push("EmotePacket", { emoteId = (i % 8) + 1 })
        spammer:Push("ChatPacket", { message = string.format("%s [%d]", message, i), channel = 0 })
    end
    spammer:Start()
end

-- Skenario C: Multi-Tile Auto Placer (Membangun Lantai Instan)
function RunFastPlaceFloor(blockItemId, startX, y, length)
    spammer:Clear()
    for x = startX, startX + length - 1 do
        spammer:Push("PlaceBlockPacket", {
            x = x,
            y = y,
            itemId = blockItemId
        })
    end
    spammer:Start()
end

-- ── 4. Eksekusi Pengujian ───────────────────────────────────────────────────
NX.ConsoleMsg("=== NXroENinD_DPcKage Spammer Engine Ready ===", "cyan")

-- Contoh menjalankan auto-placer 10 block ke kanan:
RunFastPlaceFloor(2, 10, 20, 10)

-- Berhenti otomatis setelah 5 detik
NX.After(5, function()
    spammer:Stop()
end)

return SpammerEngine
```

---

*NXroENinD_DPcKage v3.0.0 — Complete Technical Documentation & Macro Engine*
