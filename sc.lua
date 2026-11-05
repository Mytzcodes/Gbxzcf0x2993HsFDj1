-- findEvent_A.lua
local DEBUG_ID = "0_536957"   -- dari log

local function findEvent()
    -- 1) coba jalur normal dulu (kalau ada yang reparent balik)
    local p = game:GetService("Players").LocalPlayer
    local ok, ev = pcall(function()
        return p.PlayerGui.GameGui.Game:FindFirstChild("Event")
    end)
    if ok and ev and ev:IsA("BindableEvent") then
        print("[OK] ketemu di path normal")
        return ev
    end

    -- 2) fallback: scan semua nil-parent instance
    if not getnilinstances then
        warn("[X] getnilinstances() tidak ada — butuh executor")
        return nil
    end

    for _, obj in getnilinstances() do
        if obj:IsA("BindableEvent")
            and obj.Name == "Event"
            and obj:GetDebugId() == DEBUG_ID then
            print("[OK] ketemu via getnilinstances, debugId =", obj:GetDebugId())
            return obj
        end
    end

    -- 3) last resort: BindableEvent bernama "Event" apa saja
    for _, obj in getnilinstances() do
        if obj:IsA("BindableEvent") and obj.Name == "Event" then
            print("[~] fallback: ambil Event pertama, debugId =", obj:GetDebugId())
            return obj
        end
    end

    warn("[X] Event tidak ditemukan")
    return nil
end

local Event = findEvent()
if Event then
    Event:Fire("A")
    print("[OK] 'A' terkirim ke .Event")
end
