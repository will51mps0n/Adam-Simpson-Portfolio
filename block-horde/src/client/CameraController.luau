--!strict
-- Overhead camera: high above the player, tilted a little to look north,
-- narrow field of view. Smooth follow, no zoom, no rotation. Shakes on
-- explosions. When you are down during a run it follows a living teammate
-- (Q / E to switch).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CharacterController = require(script.Parent.CharacterController)
local Input = require(script.Parent.InputController)

local player = Players.LocalPlayer

local CameraController = {}

local focus: Vector3? = nil
local trauma = 0
local spectateIndex = 1
local spectating: Player? = nil

-- Adds shake; amount 1 is the strongest.
function CameraController.shake(amount: number)
	trauma = math.min(1, trauma + amount)
end

function CameraController.spectating(): Player?
	return spectating
end

local function livingTeammates(): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if other ~= player and other:GetAttribute("InRun") == true and humanoid and humanoid.Health > 0 then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

local function rootOf(target: Player): BasePart?
	local character = target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function pickTarget(): BasePart?
	spectating = nil
	local root = CharacterController.getRoot()
	if root and CharacterController.isAlive() then
		return root
	end
	if player:GetAttribute("InRun") ~= true then
		return root
	end
	local mates = livingTeammates()
	if #mates == 0 then
		return root
	end
	spectateIndex = (spectateIndex - 1) % #mates + 1
	spectating = mates[spectateIndex]
	return rootOf(mates[spectateIndex])
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if camera.FieldOfView ~= Config.CAMERA_FOV then
		camera.FieldOfView = Config.CAMERA_FOV
	end

	local root = pickTarget()
	if root then
		local target = Vector3.new(root.Position.X, 0, root.Position.Z)
		if focus and (focus - target).Magnitude < 150 then
			focus = focus:Lerp(target, 1 - math.exp(-Config.CAMERA_FOLLOW_SHARPNESS * dt))
		else
			focus = target -- first frame, or teleported far (lobby <-> arena): snap
		end
	end

	local at = focus or Vector3.zero
	local tilt = math.rad(Config.CAMERA_TILT_DEG)
	local distance = Config.CAMERA_DISTANCE
	local eye = at + Vector3.new(0, distance * math.cos(tilt), distance * math.sin(tilt))
	local cframe = CFrame.lookAt(eye, at)
	if trauma > 0 then
		local amount = trauma * trauma * Config.CAMERA_SHAKE_MAX
		cframe += cframe.RightVector * (math.random() * 2 - 1) * amount + cframe.UpVector * (math.random() * 2 - 1) * amount
		trauma = math.max(0, trauma - dt / Config.CAMERA_SHAKE_TIME)
	end
	camera.CFrame = cframe
end

function CameraController.start()
	Input.CycleWeapon:Connect(function(step: number)
		if spectating then
			spectateIndex += step
		end
	end)
	RunService:BindToRenderStep("BlockHordeCamera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
