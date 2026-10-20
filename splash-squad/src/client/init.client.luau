--!strict
-- Client entry point. For milestone 1 it opens the test stage where you can
-- meet the kids; the lobby and matches arrive in later milestones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

ReplicatedStorage:WaitForChild("Shared")

-- Players have no normal avatar, so hide the backpack, health bar and reset button.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

local Showcase = require(script.Showcase)
Showcase.start()
