--!strict
-- Client entry point: sets up the look, controls, HUD and camera, then starts the game.

local StarterGui = game:GetService("StarterGui")

local LightingSetup = require(script.LightingSetup)
local CameraController = require(script.CameraController)
local Hud = require(script.Hud)
local Input = require(script.Input)
local ClientSession = require(script.ClientSession)

-- No Roblox character, so hide the default HUD pieces that would be empty.
for _, kind in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(kind, false)
	end)
end

LightingSetup.apply()
CameraController.start()
Hud.start()
Input.start()
ClientSession.start()
