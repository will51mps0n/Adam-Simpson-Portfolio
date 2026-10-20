--!strict
-- Client entry point: starts each controller once the game has loaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local CameraController = require(script.Parent.CameraController)
local CharacterController = require(script.Parent.CharacterController)
local ClientArena = require(script.Parent.ClientArena)
local Effects = require(script.Parent.Effects)
local EnemyRenderer = require(script.Parent.EnemyRenderer)
local GameOverUI = require(script.Parent.GameOverUI)
local HealthBars = require(script.Parent.HealthBars)
local HUD = require(script.Parent.HUD)
local Input = require(script.Parent.InputController)
local MobileControls = require(script.Parent.MobileControls)
local PartyUI = require(script.Parent.PartyUI)
local PauseUI = require(script.Parent.PauseUI)
local Popups = require(script.Parent.Popups)
local ProjectileRenderer = require(script.Parent.ProjectileRenderer)
local SettingsUI = require(script.Parent.SettingsUI)
local WeaponController = require(script.Parent.WeaponController)

-- Weapons use the number keys and health is on the HUD, so hide Roblox's
-- tool bar and health bar. CoreGui may need a moment to be ready.
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if ok then
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
EnemyRenderer.start()
ProjectileRenderer.start()
WeaponController.start()
HUD.start()
Popups.start()
GameOverUI.start()
PartyUI.start()
HealthBars.start()
MobileControls.start()
SettingsUI.start()
PauseUI.start()

Net.event("Explosion").OnClientEvent:Connect(Effects.fromServer)
