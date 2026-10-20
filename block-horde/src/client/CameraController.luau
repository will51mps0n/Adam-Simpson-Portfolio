--!strict
-- Overhead camera: high above the player, tilted a little to look north,
-- narrow field of view. Smooth follow, no zoom, no rotation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CharacterController = require(script.Parent.CharacterController)

local CameraController = {}

local focus: Vector3? = nil

local function update(dt: number)
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if camera.FieldOfView ~= Config.CAMERA_FOV then
		camera.FieldOfView = Config.CAMERA_FOV
	end

	local root = CharacterController.getRoot()
	if root then
		local target = Vector3.new(root.Position.X, 0, root.Position.Z)
		if focus then
			focus = focus:Lerp(target, 1 - math.exp(-Config.CAMERA_FOLLOW_SHARPNESS * dt))
		else
			focus = target
		end
	end

	local at = focus or Vector3.zero
	local tilt = math.rad(Config.CAMERA_TILT_DEG)
	local distance = Config.CAMERA_DISTANCE
	local eye = at + Vector3.new(0, distance * math.cos(tilt), distance * math.sin(tilt))
	camera.CFrame = CFrame.lookAt(eye, at)
end

function CameraController.start()
	RunService:BindToRenderStep("BlockHordeCamera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
