--!strict
-- Client entry point: starts each controller once the game has loaded.

local StarterGui = game:GetService("StarterGui")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local CameraController = require(script.Parent.CameraController)
local CharacterController = require(script.Parent.CharacterController)
local ClientArena = require(script.Parent.ClientArena)
local Effects = require(script.Parent.Effects)
local Input = require(script.Parent.InputController)
local MobileControls = require(script.Parent.MobileControls)
local PauseUI = require(script.Parent.PauseUI)
local SettingsUI = require(script.Parent.SettingsUI)
local WeaponController = require(script.Parent.WeaponController)

-- Weapons use the number keys, so hide Roblox's tool bar. CoreGui may need a moment to be ready.
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
			return
		end
		task.wait(0.5)
	end
end)

Input.start()
ClientArena.start()
Effects.start()
CharacterController.start()
CameraController.start()
WeaponController.start()
MobileControls.start()
SettingsUI.start()
PauseUI.start()
