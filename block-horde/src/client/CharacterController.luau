--!strict
-- In a run: moves the local character from input and turns it to face the
-- aim direction (jumping off, Humanoid.AutoRotate off, Roblox's own controls
-- off). In the lobby it steps aside and Roblox's normal controls take over.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Input = require(script.Parent.InputController)

local player = Players.LocalPlayer

local CharacterController = {}

local humanoid: Humanoid? = nil
local root: BasePart? = nil
local align: AlignOrientation? = nil
local facing = Vector3.new(0, 0, -1)
local appliedArena: boolean? = nil -- which mode the current character is set up for

-- Roblox's default movement controls (the PlayerModule's ControlModule).
local controls: any = nil
task.spawn(function()
	local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 20)
	if module and module:IsA("ModuleScript") then
		local ok, playerModule = pcall(require, module)
		if ok and playerModule then
			controls = (playerModule :: any):GetControls()
			appliedArena = nil -- re-apply the current mode now that controls exist
		end
	end
end)

function CharacterController.getRoot(): BasePart?
	return root
end

-- Unit vector on the floor plane the character is facing (and shooting toward).
function CharacterController.getFacing(): Vector3
	return facing
end

function CharacterController.isAlive(): boolean
	return humanoid ~= nil and humanoid.Health > 0 and humanoid.Parent ~= nil
end

local function flat(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return nil
	end
	return f.Unit
end

local function setup(character: Model)
	local h = character:WaitForChild("Humanoid") :: Humanoid
	local r = character:WaitForChild("HumanoidRootPart") :: BasePart

	local attachment = Instance.new("Attachment")
	attachment.Name = "FacingAttachment"
	attachment.Parent = r
	local a = Instance.new("AlignOrientation")
	a.Name = "Facing"
	a.Mode = Enum.OrientationAlignmentMode.OneAttachment
	a.Attachment0 = attachment
	a.RigidityEnabled = true
	a.Enabled = false
	a.Parent = r

	facing = flat(r.CFrame.LookVector) or Vector3.new(0, 0, -1)
	a.CFrame = CFrame.lookAt(Vector3.zero, facing)
	humanoid, root, align = h, r, a
	appliedArena = nil
end

-- Switches between the game's top-down controls and Roblox's normal ones.
local function applyMode(h: Humanoid, a: AlignOrientation, arena: boolean)
	appliedArena = arena
	h.AutoRotate = not arena
	h:SetStateEnabled(Enum.HumanoidStateType.Jumping, not arena)
	a.Enabled = arena
	if controls then
		if arena then
			controls:Disable()
		else
			controls:Enable()
		end
	end
	if not arena then
		h:Move(Vector3.zero, false)
	end
end

local function update()
	local h, r, a = humanoid, root, align
	if not h or not r or not a or not h.Parent then
		return
	end
	local arena = player:GetAttribute("InRun") == true
	if arena ~= appliedArena then
		applyMode(h, a, arena)
	end
	if not arena then
		return -- the lobby uses Roblox's normal controls
	end
	if workspace:GetAttribute("Paused") == true or h.Health <= 0 then
		h:Move(Vector3.zero, false)
		return
	end

	local move = Input.getMoveVector()
	h:Move(move, false)

	local aim: Vector3? = nil
	if Input.scheme == "Mouse" then
		local point = Input.getMouseGroundPoint(r.Position.Y + Config.MUZZLE_HEIGHT)
		if point then
			local toPoint = point - r.Position
			if Vector3.new(toPoint.X, 0, toPoint.Z).Magnitude > 0.5 then
				aim = flat(toPoint)
			end
		end
	elseif move.Magnitude > 0.1 then
		aim = flat(move)
	end
	if aim then
		facing = aim
	end
	a.CFrame = CFrame.lookAt(Vector3.zero, facing)
end

function CharacterController.start()
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end
	RunService:BindToRenderStep("BlockHordeCharacter", Enum.RenderPriority.Input.Value + 1, update)
end

return CharacterController
