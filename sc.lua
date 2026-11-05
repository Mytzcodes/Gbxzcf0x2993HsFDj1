-- FireServer_A.lua
local rs = game:GetService("ReplicatedStorage")
local remote = rs:WaitForChild("ByteNetReliable")

-- Bungkus "A" jadi buffer (UTF-8 byte = 0x41)
local b = buffer.create(1)
buffer.writeu8(b, 0, 0x41)   -- 'A'

remote:FireServer(b)
print("[OK] 'A' dikirim ke ByteNetReliable")
