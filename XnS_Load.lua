--[[
    XnS_Load.lua  —  NXroENinD_DPcKage | UI Layer (Rayfield)
    Version : 1.0.0
    Paired  : LX&80.lua  (backend logic)
    Theme   : Deep Sky Blue Gradient / Dark / White Text
    Load    : loadstring(game:HttpGet("RAW_URL"))()

    TABS:
      0 · MISC          · NoDeath, AntiCP, Fly, Zoom, Performance
      1 · SPAM CHAT     · Message, Delay, RandomPrefix, Start/Stop
      2 · AUTO FARM     · PNB | DF | CLEAR WORLD
      3 · TELEPORT      · Manual XY, Player List
      4 · MODS LOG      · Detection log, action on mod join
      5 · ITEM LIST     · Search ItemDB by name/id
      6 · CSN / HOSTER  · Fast Spin / Auto Spin
      7 · PROFILE       · Custom nametag, visual worn items
      8 · TROLL [EXP]   · VoiceAll, AnnounceAll
      9 · ANTI-DETECT   · AntiDetect, UnlockAll
]]

-- ══════════════════════════════════════════════════════════════
--  SECTION 0 ·  BOOTSTRAP
-- ══════════════════════════════════════════════════════════════
local RAW_LX80  = "https://raw.githubusercontent.com/Mytzcodes/Gbxzcf0x2993HsFDj1/refs/heads/main/LX%2680.lua"
local RAW_RF    = "https://sirius.menu/rayfield"

-- ── Load Rayfield ─────────────────────────────────────────────
local Rayfield
do
    local ok, err = pcall(function()
        Rayfield = loadstring(game:HttpGet(RAW_RF, true))()
    end)
    if not ok then
        warn("[XnS] Rayfield failed to load: " .. tostring(err))
        return
    end
end

-- ── Load LX Backend ───────────────────────────────────────────
local LX
do
    local ok, err = pcall(function()
        LX = loadstring(game:HttpGet(RAW_LX80, true))()
    end)
    if not ok or not LX then
        warn("[XnS] LX&80 backend failed: " .. tostring(err))
        -- fallback stub so UI still loads
        LX = {
            State = {}, Pos = {x=0, y=0},
            Init = function() end,
            Cache_Changed = function() return true end,
            Godmode_On=function()end, Godmode_Off=function()end,
            AntiCheckpoint_On=function()end, AntiCheckpoint_Off=function()end,
            Fly_On=function()end, Fly_Off=function()end,
            SetZoom=function()end,
            Performance_On=function()end, Performance_Off=function()end,
            Spam_Start=function()end, Spam_Stop=function()end,
            PNB_Start=function()end, PNB_Stop=function()end,
            DF_Start=function()end, DF_Stop=function()end,
            Clear_Start=function()end, Clear_Stop=function()end,
            Teleport=function()end, TeleportToPlayer=function()end,
            ModWatch_On=function()end, ModWatch_Off=function()end,
            SearchItems=function() return {} end,
            FastSpin_Once=function()end,
            AutoSpin_Start=function()end, AutoSpin_Stop=function()end,
            FastSpin_HookResults=function()end,
            SetNametag=function()end, RemoveNametag=function()end,
            VoiceAll_On=function()end, VoiceAll_Off=function()end,
            AnnounceAll=function()end,
            AntiDetect_On=function()end, AntiDetect_Off=function()end,
            UnlockAll_On=function()end, UnlockAll_Off=function()end,
        }
        LX.State = {
            godmode=false, antiCheckpoint=false, fly=false,
            flySpeed=20, zoom=0, spamRunning=false,
            pnbRunning=false, dfRunning=false, clearRunning=false,
            modWatchOn=false, antiDetect=false, unlockAll=false,
            voiceAll=false, spamMsg="", spamDelay=1.5,
            spamRandom=false, pnbGrid={}, pnbSeedId=nil,
            pnbDelay=0.3, dfDelay=0.3, clearDelay=0.5,
            tpMethod=1, modAction="SLEEP", modLog={}, modCount=0,
            nametag=nil, namedStyle="default",
        }
    end
    pcall(function() LX.Init() end)
end

-- ── Services & LP ─────────────────────────────────────────────
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP         = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════
--  SECTION 1 ·  RAYFIELD WINDOW
-- ══════════════════════════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name              = "NXroENinD  |  v1.0",
    LoadingTitle      = "NX Hub",
    LoadingSubtitle   = "GrowBlox Suite · Deep Sky",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "NX_Config",
        FileName   = "XnS_Profile",
    },
    Discord = {
        Enabled = false,
    },
    KeySystem = false,
})

-- ── Custom Theme override (Deep Sky Blue, dark bg, white text) ─
pcall(function()
    Rayfield:SetCustomWindowTheme({
        TextColor          = Color3.fromRGB(240, 248, 255),
        Background         = Color3.fromRGB(8, 18, 32),
        Topbar             = Color3.fromRGB(0, 80, 140),
        Shadow             = Color3.fromRGB(0, 40, 80),
        NotificationBackground = Color3.fromRGB(0, 60, 110),
        NotificationActionsBackground = Color3.fromRGB(0, 80, 140),
        TabBackground      = Color3.fromRGB(5, 14, 26),
        TabStroke          = Color3.fromRGB(0, 110, 200),
        TabBackgroundSelected = Color3.fromRGB(0, 100, 180),
        TabTextColor       = Color3.fromRGB(180, 220, 255),
        SelectedTabTextColor = Color3.fromRGB(240, 248, 255),
        ElementBackground  = Color3.fromRGB(10, 25, 48),
        ElementBackgroundHover = Color3.fromRGB(0, 60, 110),
        SecondaryElementBackground = Color3.fromRGB(8, 20, 40),
        ElementStroke      = Color3.fromRGB(0, 100, 180),
        SecondaryElementStroke = Color3.fromRGB(0, 70, 130),
        SliderBackground   = Color3.fromRGB(0, 40, 80),
        SliderProgress     = Color3.fromRGB(0, 150, 255),
        SliderStroke       = Color3.fromRGB(0, 110, 200),
        ToggleBackground   = Color3.fromRGB(0, 40, 80),
        ToggleEnabled      = Color3.fromRGB(0, 150, 255),
        ToggleDisabled     = Color3.fromRGB(40, 60, 90),
        ToggleEnabledStroke = Color3.fromRGB(0, 180, 255),
        ToggleDisabledStroke = Color3.fromRGB(50, 80, 120),
        ToggleEnabledInner  = Color3.fromRGB(240, 248, 255),
        ToggleDisabledInner = Color3.fromRGB(100, 130, 160),
        InputBackground    = Color3.fromRGB(5, 18, 36),
        InputStroke        = Color3.fromRGB(0, 100, 180),
        PlaceholderColor   = Color3.fromRGB(80, 130, 180),
    })
end)

-- ══════════════════════════════════════════════════════════════
--  SECTION 2 ·  TAB 0 — MISC
-- ══════════════════════════════════════════════════════════════
local TabMisc = Window:CreateTab("⚙  MISC", nil)

TabMisc:CreateToggle({
    Name        = "No Death  (Godmode)",
    CurrentValue = false,
    Flag        = "toggle_godmode",
    Callback    = function(v)
        if v then LX.Godmode_On() else LX.Godmode_Off() end
    end,
})

TabMisc:CreateToggle({
    Name        = "Anti Checkpoint",
    CurrentValue = false,
    Flag        = "toggle_anticheckpoint",
    Callback    = function(v)
        if v then LX.AntiCheckpoint_On() else LX.AntiCheckpoint_Off() end
    end,
})

TabMisc:CreateToggle({
    Name        = "Fly  (WASD + Space / Shift)",
    CurrentValue = false,
    Flag        = "toggle_fly",
    Callback    = function(v)
        if v then LX.Fly_On(LX.State.flySpeed) else LX.Fly_Off() end
    end,
})

TabMisc:CreateSlider({
    Name         = "Fly Speed",
    Range        = {5, 100},
    Increment    = 1,
    Suffix       = " stud/s",
    CurrentValue = 20,
    Flag         = "slider_flyspeed",
    Callback     = function(v)
        LX.State.flySpeed = v
    end,
})

TabMisc:CreateSlider({
    Name         = "Zoom  (FOV offset)",
    Range        = {-20, 50},
    Increment    = 1,
    Suffix       = "°",
    CurrentValue = 0,
    Flag         = "slider_zoom",
    Callback     = function(v)
        LX.SetZoom(v)
    end,
})

TabMisc:CreateToggle({
    Name        = "Performance Mode  (Low Quality Render)",
    CurrentValue = false,
    Flag        = "toggle_performance",
    Callback    = function(v)
        if v then LX.Performance_On() else LX.Performance_Off() end
    end,
})

-- ══════════════════════════════════════════════════════════════
--  SECTION 3 ·  TAB 1 — SPAM CHAT
-- ══════════════════════════════════════════════════════════════
local TabSpam = Window:CreateTab("💬  SPAM CHAT", nil)

local spamMsgValue = ""
TabSpam:CreateInput({
    Name        = "Chat Message",
    PlaceholderText = "Ketik pesan…",
    RemoveTextAfterFocusLost = false,
    Flag        = "input_spammsg",
    Callback    = function(v)
        spamMsgValue = v
        LX.State.spamMsg = v
    end,
})

TabSpam:CreateToggle({
    Name        = "Random Number Prefix  (1–10 didepan)",
    CurrentValue = false,
    Flag        = "toggle_spamrandom",
    Callback    = function(v)
        LX.State.spamRandom = v
    end,
})

TabSpam:CreateSlider({
    Name         = "Delay antar pesan",
    Range        = {0.1, 10},
    Increment    = 0.1,
    Suffix       = " detik",
    CurrentValue = 1.5,
    Flag         = "slider_spamdelay",
    Callback     = function(v)
        LX.State.spamDelay = v
    end,
})

TabSpam:CreateButton({
    Name     = "▶  START SPAM",
    Callback = function()
        if LX.State.spamRunning then
            Rayfield:Notify({ Title="SPAM", Content="Sudah berjalan!", Duration=2 })
            return
        end
        LX.Spam_Start(spamMsgValue, LX.State.spamDelay, LX.State.spamRandom)
        Rayfield:Notify({ Title="✅ SPAM", Content="Spam dimulai", Duration=2 })
    end,
})

TabSpam:CreateButton({
    Name     = "⏹  STOP SPAM",
    Callback = function()
        LX.Spam_Stop()
        Rayfield:Notify({ Title="SPAM", Content="Spam dihentikan", Duration=2 })
    end,
})

-- ══════════════════════════════════════════════════════════════
--  SECTION 4 ·  TAB 2 — AUTO FARM
-- ══════════════════════════════════════════════════════════════
local TabFarm = Window:CreateTab("🌾  AUTO FARM", nil)

-- ───── Live Position Label ─────────────────────────────────────
local _farmPosLabel = TabFarm:CreateLabel("📍 Posisi: X=0  Y=0")

-- ───── PNB SUB-SECTION ────────────────────────────────────────
TabFarm:CreateSection("PNB  –  Plant N Break")

TabFarm:CreateParagraph({
    Title   = "5×5 Grid  (tengah = kamu)",
    Content = "Aktifkan tile yang ingin di-break. Baris 1 = atas, Baris 5 = bawah, Kolom 1 = kiri, Kolom 5 = kanan."
})

-- Build 5×5 toggle grid
local pnbGrid = {}
for r = 1, 5 do
    pnbGrid[r] = {}
    for c = 1, 5 do
        pnbGrid[r][c] = (r ~= 3 or c ~= 3)  -- default: semua kecuali tengah
        local label = (r == 3 and c == 3) and "[KAMU]" or string.format("R%d C%d", r, c)
        local flagKey = string.format("pnb_grid_%d_%d", r, c)
        TabFarm:CreateToggle({
            Name        = label,
            CurrentValue = pnbGrid[r][c],
            Flag        = flagKey,
            Callback    = function(v)
                pnbGrid[r][c] = v
                LX.State.pnbGrid = pnbGrid
            end,
        })
    end
end
LX.State.pnbGrid = pnbGrid

-- Seed Search (autocomplete via Rayfield input + dropdown)
local pnbSeedIdValue = 0
local pnbSearchResults = {}

local pnbSeedDropdown
pnbSeedDropdown = TabFarm:CreateDropdown({
    Name    = "Pilih Seed (akan muncul setelah cari)",
    Options = { "(cari dulu)" },
    CurrentOption = { "(cari dulu)" },
    Flag    = "pnb_seed_dropdown",
    Callback = function(v)
        for _, r in pnbSearchResults do
            if r.name == v then
                pnbSeedIdValue = r.id
                LX.State.pnbSeedId = r.id
                Rayfield:Notify({ Title="Seed Dipilih", Content=r.name.." (ID:"..r.id..")", Duration=2 })
                break
            end
        end
    end,
})

TabFarm:CreateInput({
    Name        = "Cari Seed (nama / ID)",
    PlaceholderText = "contoh: dirt, rock, lava…",
    RemoveTextAfterFocusLost = false,
    Flag        = "pnb_seed_search",
    Callback    = function(v)
        if #v < 2 then return end
        pnbSearchResults = LX.SearchItems(v, 20)
        local opts = {}
        for _, r in pnbSearchResults do
            opts[#opts+1] = r.name .. " [" .. r.id .. "]"
        end
        if #opts == 0 then opts = { "(tidak ditemukan)" } end
        pcall(function()
            pnbSeedDropdown:Set(opts[1])
            -- refresh options
        end)
    end,
})

TabFarm:CreateSlider({
    Name         = "PNB Break Delay  (◀ cepat · lambat ▶)",
    Range        = {0.05, 2},
    Increment    = 0.05,
    Suffix       = "s",
    CurrentValue = 0.3,
    Flag         = "pnb_delay",
    Callback     = function(v)
        LX.State.pnbDelay = v
    end,
})

TabFarm:CreateToggle({
    Name        = "Auto Collect setelah Break",
    CurrentValue = true,
    Flag        = "pnb_autocollect",
    Callback    = function(v)
        LX.State.pnbAutoCollect = v
    end,
})

TabFarm:CreateButton({
    Name     = "▶  START PNB",
    Callback = function()
        if LX.State.pnbRunning then
            Rayfield:Notify({ Title="PNB", Content="Sudah berjalan!", Duration=2 })
            return
        end
        LX.PNB_Start(pnbGrid, pnbSeedIdValue, LX.State.pnbDelay, LX.State.pnbAutoCollect)
        Rayfield:Notify({ Title="✅ PNB", Content="Auto Farm PNB dimulai", Duration=2 })
    end,
})

TabFarm:CreateButton({
    Name     = "⏹  STOP PNB",
    Callback = function()
        LX.PNB_Stop()
        Rayfield:Notify({ Title="PNB", Content="Dihentikan", Duration=2 })
    end,
})

-- ───── DF SUB-SECTION ─────────────────────────────────────────
TabFarm:CreateSection("DF  –  Dark Farm")

TabFarm:CreateParagraph({
    Title   = "Pola DF",
    Content = "Break kolom X (genap) di seluruh world. Lava → ganti Dirt. Loop row harvest. Ada tutup atas dengan Dirt."
})

TabFarm:CreateSlider({
    Name         = "DF Break Delay  (◀ cepat · lambat ▶)",
    Range        = {0.05, 2},
    Increment    = 0.05,
    Suffix       = "s",
    CurrentValue = 0.3,
    Flag         = "df_delay",
    Callback     = function(v)
        LX.State.dfDelay = v
    end,
})

TabFarm:CreateButton({
    Name     = "▶  START DF",
    Callback = function()
        if LX.State.dfRunning then
            Rayfield:Notify({ Title="DF", Content="Sudah berjalan!", Duration=2 })
            return
        end
        LX.DF_Start(LX.State.dfDelay)
        Rayfield:Notify({ Title="✅ DF", Content="Dark Farm dimulai", Duration=2 })
    end,
})

TabFarm:CreateButton({
    Name     = "⏹  STOP DF",
    Callback = function()
        LX.DF_Stop()
        Rayfield:Notify({ Title="DF", Content="Dihentikan", Duration=2 })
    end,
})

-- ───── CLEAR WORLD SUB-SECTION ────────────────────────────────
TabFarm:CreateSection("☢  CLEAR WORLD  –  Nuclear")

TabFarm:CreateParagraph({
    Title   = "⚠ PERHATIAN",
    Content = "Akan menghancurkan SEMUA block kecuali: Blank, Door, Bedrock, WhiteDoor. Pastikan kamu owner world!"
})

local clearConfirmed = false
TabFarm:CreateToggle({
    Name        = "KONFIRMASI CLEAR (wajib ON untuk Start)",
    CurrentValue = false,
    Flag        = "clear_confirm",
    Callback    = function(v)
        clearConfirmed = v
    end,
})

TabFarm:CreateSlider({
    Name         = "TP Delay antar tile",
    Range        = {0.1, 2},
    Increment    = 0.1,
    Suffix       = "s",
    CurrentValue = 0.5,
    Flag         = "clear_tpdelay",
    Callback     = function(v)
        LX.State.clearDelay = v
    end,
})

TabFarm:CreateButton({
    Name     = "▶  START CLEAR WORLD",
    Callback = function()
        if not clearConfirmed then
            Rayfield:Notify({ Title="⚠ CLEAR", Content="Aktifkan tombol KONFIRMASI dulu!", Duration=3 })
            return
        end
        if LX.State.clearRunning then
            Rayfield:Notify({ Title="CLEAR", Content="Sudah berjalan!", Duration=2 })
            return
        end
        LX.Clear_Start(LX.State.clearDelay)
        Rayfield:Notify({ Title="☢ CLEAR", Content="Nuclear clear dimulai!", Duration=3 })
    end,
})

TabFarm:CreateButton({
    Name     = "⏹  STOP CLEAR WORLD",
    Callback = function()
        LX.Clear_Stop()
        Rayfield:Notify({ Title="CLEAR", Content="Dihentikan", Duration=2 })
    end,
})

-- ══════════════════════════════════════════════════════════════
--  SECTION 5 ·  TAB 3 — TELEPORT
-- ══════════════════════════════════════════════════════════════
local TabTP = Window:CreateTab("🚀  TELEPORT", nil)

local _tpPosLabel = TabTP:CreateLabel("📍 Posisi: X=0  Y=0")

local tpXVal, tpYVal = 0, 0

TabTP:CreateInput({
    Name        = "Koordinat X",
    PlaceholderText = "contoh: 50",
    RemoveTextAfterFocusLost = false,
    Flag        = "tp_x",
    Callback    = function(v)
        tpXVal = tonumber(v) or tpXVal
    end,
})

TabTP:CreateInput({
    Name        = "Koordinat Y",
    PlaceholderText = "contoh: 36",
    RemoveTextAfterFocusLost = false,
    Flag        = "tp_y",
    Callback    = function(v)
        tpYVal = tonumber(v) or tpYVal
    end,
})

TabTP:CreateDropdown({
    Name    = "Metode Teleport",
    Options = { "Instant Snap", "Walk Approach (3 step)" },
    CurrentOption = { "Instant Snap" },
    Flag    = "tp_method",
    Callback = function(v)
        LX.State.tpMethod = (v == "Instant Snap") and 1 or 2
    end,
})

TabTP:CreateButton({
    Name     = "🚀  TELEPORT KE XY",
    Callback = function()
        LX.Teleport(tpXVal, tpYVal, LX.State.tpMethod)
        Rayfield:Notify({ Title="TP", Content=string.format("→ X=%.1f  Y=%.1f", tpXVal, tpYVal), Duration=2 })
    end,
})

TabTP:CreateSection("Teleport ke Player")

local function refreshPlayerList()
    local plrs = Players:GetPlayers()
    for _, p in plrs do
        if p ~= LP then
            TabTP:CreateButton({
                Name     = "→  " .. (p:GetAttribute("GameName") or p.Name),
                Callback = function()
                    LX.TeleportToPlayer(p.UserId)
                    Rayfield:Notify({ Title="TP Player", Content="→ " .. (p:GetAttribute("GameName") or p.Name), Duration=2 })
                end,
            })
        end
    end
end

TabTP:CreateButton({
    Name     = "🔄  Refresh Daftar Player",
    Callback = function()
        refreshPlayerList()
    end,
})

refreshPlayerList()

-- ══════════════════════════════════════════════════════════════
--  SECTION 6 ·  TAB 4 — MODS LOG
-- ══════════════════════════════════════════════════════════════
local TabMods = Window:CreateTab("🔎  MODS LOG", nil)

local _modCountLabel = TabMods:CreateLabel("🔴 Deteksi: 0x  |  Status: Nonaktif")
local _modLogPara    = TabMods:CreateParagraph({
    Title   = "Log Mod Terdeteksi",
    Content = "(belum ada deteksi)",
})

TabMods:CreateDropdown({
    Name    = "Aksi saat Mod Join",
    Options = { "SLEEP (stop semua bot)", "LEAVE (auto kick)", "FLY_OFF (matikan fly)" },
    CurrentOption = { "SLEEP (stop semua bot)" },
    Flag    = "mod_action",
    Callback = function(v)
        if v:find("SLEEP") then LX.State.modAction = "SLEEP"
        elseif v:find("LEAVE") then LX.State.modAction = "LEAVE"
        else LX.State.modAction = "FLY_OFF"
        end
    end,
})

local function updateModLog()
    local lines = {}
    for i, e in ipairs(LX.State.modLog) do
        if i > 10 then break end
        lines[#lines+1] = string.format("[%s] %s  (%s)", e.time, e.name, e.role)
    end
    local content = #lines > 0 and table.concat(lines, "\n") or "(belum ada deteksi)"
    pcall(function()
        _modLogPara:Set(content)
    end)
    pcall(function()
        _modCountLabel:Set(string.format("🔴 Deteksi: %dx  |  Status: %s",
            LX.State.modCount,
            LX.State.modWatchOn and "✅ Aktif" or "❌ Nonaktif"))
    end)
end

TabMods:CreateToggle({
    Name        = "Mod Watch  (pantau staff join)",
    CurrentValue = false,
    Flag        = "toggle_modwatch",
    Callback    = function(v)
        if v then
            LX.ModWatch_On(LX.State.modAction, function(_e)
                updateModLog()
                Rayfield:Notify({ Title="⚠ MOD DETECTED", Content=_e.name.." (".. _e.role ..")", Duration=5 })
            end)
        else
            LX.ModWatch_Off()
        end
        updateModLog()
    end,
})

TabMods:CreateButton({
    Name     = "🗑  Hapus Log",
    Callback = function()
        table.clear(LX.State.modLog)
        LX.State.modCount = 0
        updateModLog()
    end,
})

-- ══════════════════════════════════════════════════════════════
--  SECTION 7 ·  TAB 5 — ITEM LIST
-- ══════════════════════════════════════════════════════════════
local TabItems = Window:CreateTab("📦  ITEM LIST", nil)

local _itemResultPara = TabItems:CreateParagraph({
    Title   = "Hasil Pencarian",
    Content = "Ketik nama/ID item di bawah…",
})

local _lastItemResults = {}
local _selectedItemName = ""
local _selectedItemId   = 0

local itemDropdown
itemDropdown = TabItems:CreateDropdown({
    Name    = "Pilih Item dari Hasil",
    Options = { "(cari dulu)" },
    CurrentOption = { "(cari dulu)" },
    Flag    = "item_select",
    Callback = function(v)
        for _, r in _lastItemResults do
            local label = r.name .. " [" .. r.id .. "]"
            if label == v then
                _selectedItemName = r.name
                _selectedItemId   = r.id
                -- Show info
                local info = string.format(
                    "Nama   : %s\nID     : %s\nKind   : %s\nRarity : %s",
                    tostring(r.name),
                    tostring(r.id),
                    tostring(r.kind or "-"),
                    tostring(r.rarity or "-")
                )
                pcall(function() _itemResultPara:Set(info) end)
                break
            end
        end
    end,
})

TabItems:CreateInput({
    Name        = "Cari Nama / ID Item",
    PlaceholderText = "contoh: seed, gem, lava…",
    RemoveTextAfterFocusLost = false,
    Flag        = "item_search",
    Callback    = function(v)
        if #v < 2 then return end
        _lastItemResults = LX.SearchItems(v, 30)
        local opts = {}
        for _, r in _lastItemResults do
            opts[#opts+1] = r.name .. " [" .. r.id .. "]"
        end
        if #opts == 0 then
            opts = { "(tidak ditemukan)" }
            pcall(function() _itemResultPara:Set("Tidak ditemukan untuk: " .. v) end)
        end
        -- Can't dynamically refresh Rayfield dropdown easily; show in paragraph
        local lines = {}
        for i, r in _lastItemResults do
            if i > 15 then break end
            lines[#lines+1] = string.format("%-3d  %s  [kind:%s]", r.id, r.name, tostring(r.kind or "-"))
        end
        pcall(function() _itemResultPara:Set(table.concat(lines, "\n")) end)
    end,
})

TabItems:CreateButton({
    Name     = "📋  Copy ID ke Clipboard",
    Callback = function()
        if _selectedItemId == 0 then
            Rayfield:Notify({ Title="ITEM", Content="Pilih item dulu dari dropdown!", Duration=2 })
            return
        end
        pcall(function() setclipboard(tostring(_selectedItemId)) end)
        Rayfield:Notify({ Title="✅ Copy ID", Content=tostring(_selectedItemId), Duration=2 })
    end,
})

TabItems:CreateButton({
    Name     = "📋  Copy Nama ke Clipboard",
    Callback = function()
        if _selectedItemName == "" then
            Rayfield:Notify({ Title="ITEM", Content="Pilih item dulu dari dropdown!", Duration=2 })
            return
        end
        pcall(function() setclipboard(_selectedItemName) end)
        Rayfield:Notify({ Title="✅ Copy Nama", Content=_selectedItemName, Duration=2 })
    end,
})

-- ══════════════════════════════════════════════════════════════
--  SECTION 8 ·  TAB 6 — CSN / HOSTER
-- ══════════════════════════════════════════════════════════════
local TabCSN = Window:CreateTab("🎰  CSN / HOSTER", nil)

local _spinResultLabel = TabCSN:CreateLabel("🎰 Hasil Spin: —")

-- Hook spin result
LX.FastSpin_HookResults(function(data)
    if type(data) == "table" then
        local name = tostring(data.name or "?")
        local n    = tostring(data.n or "?")
        pcall(function()
            _spinResultLabel:Set("🎰 Hasil Spin: " .. name .. " x" .. n)
        end)
        Rayfield:Notify({ Title="🎰 Spin Result", Content=name.." x"..n, Duration=3 })
    end
end)

local spinXVal, spinYVal = 0, 0

TabCSN:CreateInput({
    Name        = "Wheel X (posisi roulette)",
    PlaceholderText = "contoh: 50",
    RemoveTextAfterFocusLost = false,
    Flag        = "spin_x",
    Callback    = function(v)
        spinXVal = tonumber(v) or spinXVal
    end,
})

TabCSN:CreateInput({
    Name        = "Wheel Y (posisi roulette)",
    PlaceholderText = "contoh: 36",
    RemoveTextAfterFocusLost = false,
    Flag        = "spin_y",
    Callback    = function(v)
        spinYVal = tonumber(v) or spinYVal
    end,
})

TabCSN:CreateButton({
    Name     = "🎯  SPIN SEKALI",
    Callback = function()
        LX.FastSpin_Once(spinXVal, spinYVal)
        Rayfield:Notify({ Title="SPIN", Content="Paket spin terkirim!", Duration=1 })
    end,
})

TabCSN:CreateToggle({
    Name        = "🔄  AUTO SPIN (loop)",
    CurrentValue = false,
    Flag        = "toggle_autospin",
    Callback    = function(v)
        if v then
            LX.AutoSpin_Start(spinXVal, spinYVal)
            Rayfield:Notify({ Title="SPIN", Content="Auto spin ON", Duration=2 })
        else
            LX.AutoSpin_Stop()
            Rayfield:Notify({ Title="SPIN", Content="Auto spin OFF", Duration=2 })
        end
    end,
})

TabCSN:CreateSection("Coming Soon…")
TabCSN:CreateParagraph({
    Title   = "Fitur mendatang",
    Content = "• Fast Roulette batch\n• Hoster mode\n• Reward tracker\n(Segera hadir!)"
})

-- ══════════════════════════════════════════════════════════════
--  SECTION 9 ·  TAB 7 — PROFILE
-- ══════════════════════════════════════════════════════════════
local TabProfile = Window:CreateTab("👤  PROFILE", nil)

local gameName = pcall(function() return LP:GetAttribute("GameName") end)
    and LP:GetAttribute("GameName") or LP.Name

local _profileNameLabel = TabProfile:CreateLabel("👤 GameName: " .. tostring(gameName))

TabProfile:CreateSection("Nametag Visual")

local nametagTextVal = ""
TabProfile:CreateInput({
    Name        = "Teks Nametag",
    PlaceholderText = "Nama yang ingin ditampilkan…",
    RemoveTextAfterFocusLost = false,
    Flag        = "profile_nametag",
    Callback    = function(v)
        nametagTextVal = v
    end,
})

local nametagStyleVal = "default"
TabProfile:CreateDropdown({
    Name    = "Style Nametag",
    Options = { "Default (putih)", "@DEV (biru)", "@MOD (merah)", "@ADM (emas)", "STAR (bintang)" },
    CurrentOption = { "Default (putih)" },
    Flag    = "profile_style",
    Callback = function(v)
        if v:find("DEV") then nametagStyleVal = "dev"
        elseif v:find("MOD") then nametagStyleVal = "mod"
        elseif v:find("ADM") then nametagStyleVal = "adm"
        elseif v:find("STAR") then nametagStyleVal = "star"
        else nametagStyleVal = "default"
        end
    end,
})

TabProfile:CreateButton({
    Name     = "✅  Pasang Nametag",
    Callback = function()
        if nametagTextVal == "" then
            Rayfield:Notify({ Title="PROFILE", Content="Isi teks nametag dulu!", Duration=2 })
            return
        end
        LX.SetNametag(nametagTextVal, nametagStyleVal)
        Rayfield:Notify({ Title="✅ Nametag", Content=nametagTextVal, Duration=2 })
    end,
})

TabProfile:CreateButton({
    Name     = "❌  Hapus Nametag",
    Callback = function()
        LX.RemoveNametag()
        Rayfield:Notify({ Title="PROFILE", Content="Nametag dihapus", Duration=2 })
    end,
})

TabProfile:CreateSection("Visual Worn Items")

TabProfile:CreateParagraph({
    Title   = "Ganti Visual (lokal saja)",
    Content = "Masukkan ID item untuk masing-masing slot. Hanya visual di client kamu (tidak terkirim ke server)."
})

local wornSlots = { hand = 0, hat = 0, shirt = 0, pants = 0 }

for _, slot in { "hand", "hat", "shirt", "pants" } do
    TabProfile:CreateInput({
        Name        = "Slot: " .. slot:upper(),
        PlaceholderText = "ID item (angka)…",
        RemoveTextAfterFocusLost = false,
        Flag        = "worn_" .. slot,
        Callback    = function(v)
            wornSlots[slot] = tonumber(v) or 0
        end,
    })
end

TabProfile:CreateButton({
    Name     = "👕  Terapkan Visual",
    Callback = function()
        LX.WearVisual(wornSlots)
        Rayfield:Notify({ Title="PROFILE", Content="Visual diterapkan (lokal)", Duration=2 })
    end,
})

-- ══════════════════════════════════════════════════════════════
--  SECTION 10 ·  TAB 8 — TROLL [EXPERIMENTAL]
-- ══════════════════════════════════════════════════════════════
local TabTroll = Window:CreateTab("🃏  TROLL  [EXP]", nil)

TabTroll:CreateParagraph({
    Title   = "⚠ EKSPERIMENTAL",
    Content = "Fitur ini bersifat eksperimental. VoiceAll = perluas jangkauan suara lokal. AnnounceAll = kirim ke semua channel chat di server ini. BUKAN cross-server."
})

TabTroll:CreateSection("Voice All")

TabTroll:CreateToggle({
    Name        = "🔊  Voice All  (semua player terdengar)",
    CurrentValue = false,
    Flag        = "toggle_voiceall",
    Callback    = function(v)
        if v then LX.VoiceAll_On() else LX.VoiceAll_Off() end
        Rayfield:Notify({ Title="VOICE ALL", Content=v and "ON (lokal)" or "OFF", Duration=2 })
    end,
})

TabTroll:CreateSection("Announce All")

local announceText = ""
TabTroll:CreateInput({
    Name        = "Teks Announcement",
    PlaceholderText = "Pesan yang dikirim ke semua channel…",
    RemoveTextAfterFocusLost = false,
    Flag        = "announce_text",
    Callback    = function(v)
        announceText = v
    end,
})

TabTroll:CreateButton({
    Name     = "📢  KIRIM ANNOUNCE",
    Callback = function()
        if announceText == "" then
            Rayfield:Notify({ Title="ANNOUNCE", Content="Isi teks dulu!", Duration=2 })
            return
        end
        LX.AnnounceAll(announceText)
        Rayfield:Notify({ Title="📢 ANNOUNCE", Content="Terkirim: " .. announceText, Duration=3 })
    end,
})

-- ══════════════════════════════════════════════════════════════
--  SECTION 11 ·  TAB 9 — ANTI-DETECT
-- ══════════════════════════════════════════════════════════════
local TabAnti = Window:CreateTab("🛡  ANTI-DETECT", nil)

TabAnti:CreateParagraph({
    Title   = "Info",
    Content = "Anti-Detection: intercept paket detect dari ByteNet, tambah jitter gerakan.\n\nUnlock All: spoof attribute Level=100 & DiscordVerified=true (client-side). Server tetap validasi — efek penuh tergantung game."
})

TabAnti:CreateSection("Anti Detection")

TabAnti:CreateToggle({
    Name        = "🛡  Anti Detection",
    CurrentValue = false,
    Flag        = "toggle_antidetect",
    Callback    = function(v)
        if v then LX.AntiDetect_On() else LX.AntiDetect_Off() end
        Rayfield:Notify({ Title="ANTI-DETECT", Content=v and "✅ Aktif" or "❌ Nonaktif", Duration=2 })
    end,
})

TabAnti:CreateSection("Unlock All  (Bypass Lv10 + Verify)")

TabAnti:CreateToggle({
    Name        = "🔓  Unlock All  (spoof client attributes)",
    CurrentValue = false,
    Flag        = "toggle_unlockall",
    Callback    = function(v)
        if v then LX.UnlockAll_On() else LX.UnlockAll_Off() end
        Rayfield:Notify({
            Title   = "UNLOCK ALL",
            Content = v and "✅ Spoof aktif (client-side)" or "❌ Nonaktif",
            Duration = 3
        })
    end,
})

TabAnti:CreateParagraph({
    Title   = "Catatan",
    Content = "• Spoof hanya efektif di client. Server-side validation tetap berjalan.\n• Drop system & trade verify = intercept data lokal saja.\n• Gunakan dengan bijak!"
})

-- ══════════════════════════════════════════════════════════════
--  SECTION 12 ·  TAB 10 — SETTINGS / SAVE PROFILE
-- ══════════════════════════════════════════════════════════════
local TabSettings = Window:CreateTab("💾  SETTINGS", nil)

local _acctLabel = TabSettings:CreateLabel("🔑 Akun: " .. tostring(LP.Name) .. "  (UID: " .. LP.UserId .. ")")
local _gameNameLabel = TabSettings:CreateLabel("🎮 GameName: " .. tostring(LP:GetAttribute("GameName") or LP.Name))

TabSettings:CreateSection("Simpan & Muat Konfigurasi")

TabSettings:CreateParagraph({
    Title   = "Auto-Save",
    Content = "Rayfield otomatis menyimpan status semua toggle & slider ke folder NX_Config. Dibuka ulang = langsung terapkan."
})

TabSettings:CreateButton({
    Name     = "💾  Simpan Config Sekarang",
    Callback = function()
        pcall(function() Rayfield:SaveConfiguration() end)
        Rayfield:Notify({ Title="✅ SAVED", Content="Konfigurasi disimpan!", Duration=2 })
    end,
})

TabSettings:CreateButton({
    Name     = "📂  Muat Config",
    Callback = function()
        pcall(function() Rayfield:LoadConfiguration() end)
        Rayfield:Notify({ Title="📂 LOADED", Content="Konfigurasi dimuat!", Duration=2 })
    end,
})

TabSettings:CreateSection("Reset")

TabSettings:CreateButton({
    Name     = "🔄  Reset Semua State (stop semua fitur)",
    Callback = function()
        LX.PNB_Stop(); LX.DF_Stop(); LX.Clear_Stop()
        LX.Spam_Stop(); LX.Fly_Off(); LX.Godmode_Off()
        LX.ModWatch_Off(); LX.AntiDetect_Off(); LX.UnlockAll_Off()
        LX.AutoSpin_Stop(); LX.RemoveNametag()
        LX.Cache_ResetAll()
        Rayfield:Notify({ Title="RESET", Content="Semua fitur dimatikan", Duration=3 })
    end,
})

-- ══════════════════════════════════════════════════════════════
--  SECTION 13 ·  LIVE POSITION LOOP
--  Gunakan LX.Cache_Changed agar tidak update UI tiap frame
-- ══════════════════════════════════════════════════════════════
local _uiPosConn
_uiPosConn = RunService.Heartbeat:Connect(function()
    local px = math.floor(LX.Pos.x)
    local py = math.floor(LX.Pos.y)
    if LX.Cache_Changed("uiPos", { px, py }) then
        local posStr = string.format("📍 Posisi: X=%d  Y=%d", px, py)
        pcall(function() _farmPosLabel:Set(posStr) end)
        pcall(function() _tpPosLabel:Set(posStr) end)
    end
end)

-- ══════════════════════════════════════════════════════════════
--  SECTION 14 ·  MOD LOG PERIODIC UPDATE (setiap 5 detik)
-- ══════════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(5)
        pcall(updateModLog)
        -- Refresh account label (GameName bisa berubah saat ganti world)
        pcall(function()
            _gameNameLabel:Set("🎮 GameName: " .. tostring(LP:GetAttribute("GameName") or LP.Name))
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════
--  SECTION 15 ·  WORLD CHANGE → auto re-apply UI state
-- ══════════════════════════════════════════════════════════════
LP:GetAttributeChangedSignal("GameName"):Connect(function()
    -- Delay biar world loaded
    task.wait(3)
    -- Re-apply active features (LX.Init() sudah handle backend)
    -- Notify user
    Rayfield:Notify({
        Title   = "🌍 World Berubah",
        Content = "Konfigurasi diterapkan ulang otomatis",
        Duration = 3
    })
    -- Refresh player TP list (bisa di-call manual)
    -- Update GameName label
    pcall(function()
        _gameNameLabel:Set("🎮 GameName: " .. tostring(LP:GetAttribute("GameName") or LP.Name))
    end)
end)

-- ══════════════════════════════════════════════════════════════
--  DONE
-- ══════════════════════════════════════════════════════════════
Rayfield:Notify({
    Title    = "✅  NX Hub Loaded",
    Content  = "GrowBlox Suite · v1.0 · Deep Sky Blue\nSemua fitur siap!",
    Duration = 5,
})
