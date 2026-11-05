# GrowBloxKit (GB) - Dokumentasi

Framework scripting untuk game Roblox berbasis **ByteNet** (struktur `ByteNet.packets.packet`), dibuat dari hasil log packet Growblox. Satu file library, satu namespace `GB`, semua struct packet terkumpul di sini.

- Versi: 1.0.0
- File: `GrowBloxKit.lua`
- Prinsip: semua pengiriman memakai fungsi `send()` milik game sendiri, ada batas laju, ada mode `DryRun`, dan struct dipelajari otomatis dari trafik nyata.

---

## 1. Instalasi

```lua
-- Cara A: simpan GrowBloxKit.lua di folder workspace executor
local GB = loadstring(readfile("GrowBloxKit.lua"))()

-- Cara B: paste isi GrowBloxKit.lua di atas script-mu, lalu:
-- local GB = <isi file>   (file diakhiri `return GB`)

GB.Init()   -- scan packet. Boleh yield beberapa detik.
print("Packet terdaftar:", #GB.List())
```

Syarat executor (semakin lengkap semakin baik):

| Fungsi | Dipakai untuk | Jika tidak ada |
|---|---|---|
| `getloadedmodules` / `getgc` | menemukan packet dan namanya | `GB.Init()` menemukan 0 packet |
| `getupvalues` | membaca ID packet | ID tampil `?`, nama tetap bisa |
| `hookfunction` | mempelajari struct paket OUT | struct OUT hanya dari seed + `GB.Send` |
| `writefile` | `GB.ExportDocs` | export gagal |

---

## 2. Quick Start

```lua
local GB = loadstring(readfile("GrowBloxKit.lua"))()
GB.Init()

-- Chat
GB.Chat.SendMessage("Halo semua!")

-- Dengar chat
GB.Chat.OnMessage(function(nama, teks)
    print(nama .. ": " .. teks)
end)

-- Dengar packet masuk
GB.On("note", function(data)
    for _, n in ipairs(GB.ParseNote(data)) do
        if n.fields and n.fields.kind == "donatesay" then
            print("Donasi dari", n.fields.name, "total", n.fields.total)
        end
    end
end)

-- Aksi
GB.Punch(54, 37)        -- pukul tile (54, 37)
GB.SetBusy(false)

-- Lihat dokumentasi hasil pengamatan
print(GB.Docs("act"))
GB.ExportDocs()         -- simpan semua ke file .md
```

Uji tanpa mengirim apa pun:

```lua
GB.Config.DryRun = true
GB.Punch(54, 37)        -- hanya mencetak: [GB][DryRun] Send(act, { kind = 6, ... })
```

---

## 3. Referensi API

### 3.1 Inti

| Fungsi | Keterangan |
|---|---|
| `GB.Init(opts?) -> number` | Scan packet, pasang pengamat, hubungkan chat. `opts = { Scan = true, Learn = true }`. Mengembalikan jumlah packet. |
| `GB.Ready() -> boolean` | `true` jika sudah Init dan ada packet. |
| `GB.List() -> { {name, id, sent, received} }` | Daftar packet, urut berdasarkan ID. |
| `GB.Has(name) -> boolean` | Apakah packet (atau alias) ada. |
| `GB.Send(name, data) -> ok, err` | Kirim packet via `send()` milik game. Divalidasi dan dibatasi laju. |
| `GB.On(name, fn) -> handle` | Dengar packet masuk. `fn(data, ...)`. `handle.Disconnect()` untuk berhenti. Boleh dipanggil sebelum `Init`. |
| `GB.Once(name, fn) -> handle` | Seperti `On`, sekali saja. |
| `GB.Wait(name, timeout?) -> data` | Tunggu satu packet (default 10 detik). Timeout mengembalikan `nil, "timeout"`. |
| `GB.Sequence(steps) -> handle` | Jalankan langkah berurutan. Lihat 3.5. |
| `GB.Alias(alias, real)` | `GB.Alias("punch", "act")`. |
| `GB.Define(name, sample) -> ok` | Tambahkan struct dari contoh data (menambah skema validasi). |
| `GB.Unload()` | Lepas semua listener dan bersihkan state. |

`name` boleh berupa nama packet (`"move"`), nama lengkap namespace (`"Net.move"`), alias (`"chat"`, `"enter"`, `"quit"`, `"punch"`), atau ID angka. ID bisa berubah antar versi game, jadi utamakan nama.

### 3.2 Chat

| Fungsi | Keterangan |
|---|---|
| `GB.Chat.SendMessage(text) -> ok, err` | Antre dan kirim pesan (maks 200 karakter, jeda `ChatInterval`, antrean maks 20). Lewat `TextChannel:SendAsync`, fallback ke `SayMessageRequest`. |
| `GB.Chat.OnMessage(fn) -> handle` | `fn(namaPemain, teks, messageObj)`. |
| `GB.Chat.History() -> table` | Maks 200 chat terakhir: `{name, userId, text, time}`. |

Jika game memakai **packet** sendiri untuk chat, isi `GB.Config.ChatBuilder`:

```lua
GB.Config.ChatBuilder = function(text)
    return "chat", { text = text }   -- sesuaikan dengan struct hasil GB.Docs("chat")
end
```

### 3.3 Aksi (berdasarkan struct yang sudah dipetakan)

| Fungsi | Packet | Keterangan |
|---|---|---|
| `GB.Act(kind, x, y)` | `act` | Kirim `{ kind, x, y }`. |
| `GB.Punch(tx, ty)` | `act` | `act(kind = Config.PunchKind, x = floor(tx)+0.5, y = floor(ty)+0.5)`. **`PunchKind = 6` adalah dugaan dari log**, verifikasi dulu (bagian 6). |
| `GB.SetBusy(bool)` | `busy` | Kirim `1` atau `0`. |
| `GB.Enter(data)` | `enter` | Struct belum dipetakan: isi `data` sesuai hasil `GB.Docs("enter")`. |
| `GB.Quit(data?)` | `quit` | Idem. |

Listener siap pakai: `GB.OnMove(fn)`, `GB.OnEnter(fn)`, `GB.OnQuit(fn)`, `GB.OnNote(fn)` (fn menerima daftar hasil `ParseNote`, lalu data mentah).

### 3.4 Utilitas data

| Fungsi | Keterangan |
|---|---|
| `GB.ParseNote(data) -> { {strings, isJson, json, fields} }` | Menguraikan packet `note`. Untuk item JSON, `fields` berisi pasangan key/value hasil ratakan `json.t`. |
| `GB.Docs(name?) -> string` | Markdown dokumentasi dari struct yang teramati. |
| `GB.ExportDocs(file?) -> path` | Simpan `GB.Docs()` ke file `.md`. |

### 3.5 Sequence

```lua
local seq = GB.Sequence({
    { "busy", 1, 0.2 },                         -- {packet, data, jeda setelahnya}
    { "act", { kind = 6, x = 54.5, y = 37.5 }, 0.3 },
    function() print("selesai satu putaran") end,
    { "busy", 0 },
})
-- seq.Cancel() untuk membatalkan
```

Sequence berhenti sendiri jika satu langkah gagal (validasi / rate limit / packet tidak ada).

---

## 4. Konfigurasi `GB.Config`

| Key | Default | Keterangan |
|---|---|---|
| `DryRun` | `false` | `true` = tidak mengirim, hanya mencetak. |
| `Debug` | `false` | Log internal. |
| `Validate` | `"warn"` | `"warn"` (peringatan), `"error"` (batalkan kirim), `false` (nonaktif). Mengecek field dan tipe terhadap struct yang dipelajari. |
| `PacketRate` | `15` | Maks `GB.Send` per detik. Melebihi batas: `Send` mengembalikan `false, "rate limit"`. |
| `ChatInterval` | `1.2` | Jeda antar pesan chat (detik). |
| `ChatChannel` | `"RBXGeneral"` | Nama `TextChannel` untuk chat. |
| `ChatBuilder` | `nil` | `function(text) -> packetName, data` jika chat lewat packet. |
| `PunchKind` | `6` | Nilai `kind` untuk `GB.Punch`. |
| `PunchBuilder` | `nil` | `function(tx, ty) -> packetName, data` jika ada packet `punch` sendiri. |
| `Aliases` | lihat file | Peta alias -> daftar nama kandidat. |

---

## 5. Referensi Packet (dari log Growblox)

ID di bawah diambil dari log (move = 8, act = 3, busy = 9, note = 2). ID bisa berubah antar update, gunakan nama.

### 5.1 `move` (OUT, id 8)

Laporan posisi dari client. Terkirim sekitar 1 kali/detik saat diam, dan jauh lebih sering saat bergerak.

| Field | Tipe | Contoh | Keterangan |
|---|---|---|---|
| `x` | number | `59.79495` | Posisi X |
| `y` | number | `36.999` | Posisi Y |
| `vx` | number | `7.2` | Kecepatan X (nilai maks teramati 7.2) |
| `vy` | number | `0` | Kecepatan Y |
| `t` | number | `15565` | Penghitung waktu ms. Teramati naik sekitar 1000 per detik, lalu kembali ke 0 setelah 65535 (kemungkinan uint16). |
| `flags` | number | `3` | Bitflag. Selalu `3` di sampel; arti tiap bit belum diketahui. |

```lua
GB.OnMove(function(d) print(d.x, d.y, d.vx, d.vy) end)   -- pemain lain, jika server menyiarkan
```

### 5.2 `act` (OUT, id 3)

Aksi di posisi tertentu.

| Field | Tipe | Contoh | Keterangan |
|---|---|---|---|
| `kind` | number | `6` atau `1` | Jenis aksi. Teramati 2 nilai. |
| `x` | number | `54.5` | Koordinat |
| `y` | number | `37.5` | Koordinat |

Pola di log, dikirim berpasangan beruntun:

- `kind = 6` dengan `x`/`y` **di tengah tile** (`54.5, 37.5`, `56.5, 37.5`, `58.5, 37.5`)
- `kind = 1` dengan `x` mengikuti **posisi pemain** (`54.578`, `54.750`, `56.406`) dan `y = 37.88235`

Arti pasti tiap `kind` adalah **dugaan**. Cara memastikan ada di bagian 6.

### 5.3 `busy` (OUT, id 9)

| Tipe data | Contoh | Keterangan |
|---|---|---|
| number | `0` / `1` | Penanda "sibuk". Dugaan: 1 saat input/menu terbuka, 0 saat selesai. Di log nilainya berganti di sekitar waktu chat dikirim. |

```lua
GB.SetBusy(true); task.wait(0.5); GB.SetBusy(false)
```

### 5.4 `note` (IN, id 2)

Notifikasi dari server. Contoh nyata dari log:

```lua
{
    e = 5,
    w = 0,
    a = {
        { s = { "donatesay" } },
        { j = true, s = { '{"t":["kind","donatesay","total",100,"name","JEEX","n",100]}' } },
    },
}
```

| Field | Tipe | Keterangan |
|---|---|---|
| `e` | number | Kode event / tipe notifikasi (teramati `5`) |
| `w` | number | Belum diketahui (teramati `0`) |
| `a` | array of object | Daftar bagian pesan |
| `a[].s` | array of string | Isi teks |
| `a[].j` | boolean (opsional) | `true` = `s[1]` adalah JSON |

JSON `{"t":[k1,v1,k2,v2,...]}` adalah daftar key/value yang diratakan. `GB.ParseNote` mengubahnya menjadi tabel:

```lua
GB.OnNote(function(parts)
    for _, p in ipairs(parts) do
        local f = p.fields
        if f and f.kind == "donatesay" then
            print(("%s donasi %d"):format(f.name, f.total))
        end
    end
end)
```

### 5.5 Packet yang ada tapi struct-nya belum dipetakan

`enter`, `quit`, `punch`, dan chat via packet (jika ada) disebut ada di game, tetapi belum muncul di log yang tersedia. Library tidak menebak struct-nya. Ikuti bagian 6.

---

## 6. Mencari struct packet baru lalu membuat script

Alur kerja, dari log sampai script:

1. **Rekam.** Pasang Debug Menu v4, buka tab **Packets**, nyalakan **Rekam Packet**, mode `Parsed`.
2. **Lakukan satu aksi saja** di game (masuk world, keluar, pukul satu kali, kirim satu chat).
3. **Baca hasilnya.** Filter kategori atau nama, atau lihat Inspector. Salin dengan **Copy Table Lua**.
4. **Pecah struct.** Untuk tiap field catat nama, tipe, dan mana yang berubah antar percobaan (koordinat, nama world, ID).
5. **Buat wrapper**:

```lua
-- Contoh umum: setelah mengetahui struct packet "enter" = { world = string }
local function EnterWorld(name)
    return GB.Send("enter", { world = name })
end
```

6. **Verifikasi dengan docs bawaan.** Setelah aksi dilakukan di game, library sudah mempelajari struct-nya:

```lua
print(GB.Docs("enter"))     -- tabel field, tipe, wajib/tidak, contoh data
```

7. **Uji aman** dengan `GB.Config.DryRun = true`, lalu matikan `DryRun`.

Memastikan arti `kind` pada `act`:

```lua
GB.On("act", function(d) print("act masuk:", d.kind, d.x, d.y) end)   -- jika server menyiarkan ke client
-- atau gunakan tab Packets (filter: act), lakukan SATU aksi, lihat kind yang muncul.
```

Jika ternyata punch memakai packet `punch` terpisah, pasang builder:

```lua
GB.Config.PunchBuilder = function(tx, ty)
    return "punch", { x = tx, y = ty }    -- sesuaikan dengan struct hasil GB.Docs("punch")
end
```

### Contoh script lengkap: balas perintah chat

```lua
local GB = loadstring(readfile("GrowBloxKit.lua"))()
GB.Init()
local me = game.Players.LocalPlayer.Name

GB.Chat.OnMessage(function(nama, teks)
    if nama == me then return end                  -- jangan membalas diri sendiri
    if teks:lower() == "!ping" then
        GB.Chat.SendMessage("pong, " .. nama)      -- otomatis diberi jeda
    end
end)
```

### Contoh script lengkap: pukul beberapa tile

```lua
GB.Config.DryRun = true            -- ubah ke false setelah yakin
for tx = 54, 58 do
    GB.Punch(tx, 37)
    task.wait(0.2)
end
```

---

## 7. Cara kerja internal (ringkas)

Berdasarkan modul `ByteNet.packets.packet` yang di-decompile:

- Setiap packet adalah tabel dengan `reader`, `listen`, `getListeners`, dan di client `send`.
- **Menerima:** library menambahkan satu listener ke `getListeners()` tiap packet. Dari situ `GB.On` dan pembelajaran struct bekerja.
- **Mengirim:** `GB.Send` memanggil `packet.send(data)` milik game, jadi serialisasi buffer tetap dilakukan ByteNet.
- **ID packet:** dibaca dari upvalue angka pada fungsi `send` (variabel `p_u_7` pada decompile).
- **Nama packet:** dari key tabel namespace (`defineNamespace`) pada modul yang sudah dimuat.
- **Struct OUT:** library meng-hook `process.client.sendReliable` / `sendUnreliable` (jika `hookfunction` tersedia) untuk mengamati packet yang dikirim game sendiri.

---

## 8. Troubleshooting

| Gejala | Penyebab / solusi |
|---|---|
| `GB.Init()` mengembalikan `0` | Executor tanpa `getgc`/`getloadedmodules`, atau game belum selesai memuat. Tunggu masuk game lalu `GB.Init()` lagi. |
| `packet 'x' tidak ditemukan` | Cek `GB.List()`. Packet memakai nama lain: `GB.Alias("punch", "namaAsli")`. |
| Peringatan `validasi ...` | Field kamu tidak cocok dengan struct teramati. Cek `GB.Docs(name)`. Pakai `Validate = "error"` agar pengiriman dibatalkan. |
| `rate limit` | Turunkan frekuensi atau naikkan `GB.Config.PacketRate` dengan wajar. |
| Chat tidak terkirim | Isi `GB.Config.ChatBuilder` jika chat game lewat packet; cek `ChatChannel`. |
| Server mengabaikan packet | Server memvalidasi sendiri (jarak, kepemilikan, cooldown). Library hanya memanggil `send()`; hasil akhir ditentukan server. |

---

## 9. Catatan penggunaan

- Library ini sengaja **tidak** menyertakan helper untuk memalsukan posisi (`move`) maupun mengirim packet mentah di luar `send()` milik game. Packet `move` hanya didokumentasikan dan bisa didengar lewat `GB.OnMove`.
- Pastikan penggunaan sesuai aturan game dan Roblox. Script otomatis dapat berakibat akun terkena sanksi.
- Batas laju dan `DryRun` ada agar eksperimen tidak membanjiri server atau pemain lain dengan pesan.
