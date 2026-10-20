--!strict
-- Owns the level on screen: builds it on this client and points the camera at it.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Levels = require(Shared.Levels)
local LevelBuilder = require(Shared.LevelBuilder)
local CameraController = require(script.Parent.CameraController)

local LevelController = {}

local current: LevelBuilder.BuiltLevel? = nil

function LevelController.load(id: string): LevelBuilder.BuiltLevel
	if current then
		current.model:Destroy()
	end
	local built = LevelBuilder.build(Levels.get(id), Workspace)
	current = built
	CameraController.setLevel(built)
	return built
end

function LevelController.current(): LevelBuilder.BuiltLevel?
	return current
end

return LevelController
