local player = game:GetService("Players").LocalPlayer
local event  = player.PlayerGui.GameGui.Game:WaitForChild("Event")

event:Fire("A")
