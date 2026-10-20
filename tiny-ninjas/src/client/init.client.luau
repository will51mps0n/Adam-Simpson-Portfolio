--!strict
-- Client entry point: sets up the look, builds the level on this client and starts the camera.

local StarterGui = game:GetService("StarterGui")

local LightingSetup = require(script.LightingSetup)
local CameraController = require(script.CameraController)
local CameraTest = require(script.CameraTest)

-- No Roblox character, so hide the default HUD pieces that would be empty.
for _, kind in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(kind, false)
	end)
end

LightingSetup.apply()
CameraController.start()
CameraTest.start()
