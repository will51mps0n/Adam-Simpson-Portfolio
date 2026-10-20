--!strict
-- Milestone 1 stand-ins for zombies: wooden dummies on the room's 'T' cells.
-- They flash white when hit, break when killed and come back a few seconds later.
-- Milestone 3 replaces these with real zombies.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RoomGrid = require(ReplicatedStorage.Shared.RoomGrid)
local Enemies = require(script.Parent.Enemies)

local PracticeTargets = {}

local WOOD_LIGHT = Color3.fromRGB(204, 160, 102)
local WOOD_DARK = Color3.fromRGB(122, 84, 52)
local TARGET_RED = Color3.fromRGB(214, 40, 40)
local TARGET_WHITE = Color3.fromRGB(245, 245, 245)

local folder: Folder
local models: { [number]: Model } = {}

local function addPart(model: Model, size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part:SetAttribute("BaseColor", color)
	part.Parent = model
	return part
end

local function buildDummy(x: number, z: number): Model
	local model = Instance.new("Model")
	model.Name = "Dummy"
	local at = CFrame.new(x, 0, z)
	local up = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder to lie flat
	addPart(model, Vector3.new(2.2, 0.4, 2.2), at * CFrame.new(0, 0.2, 0), WOOD_DARK)
	local body = addPart(model, Vector3.new(1.8, 2.2, 1), at * CFrame.new(0, 1.5, 0), WOOD_LIGHT)
	addPart(model, Vector3.new(3, 0.4, 0.4), at * CFrame.new(0, 2.2, 0), WOOD_DARK)
	addPart(model, Vector3.new(1.6, 1.6, 1.6), at * CFrame.new(0, 3.4, 0), WOOD_LIGHT)
	-- A bullseye painted on top of the head, which is what the overhead camera sees.
	addPart(model, Vector3.new(0.1, 1.3, 1.3), at * CFrame.new(0, 4.22, 0) * up, TARGET_RED, Enum.PartType.Cylinder)
	addPart(model, Vector3.new(0.1, 0.85, 0.85), at * CFrame.new(0, 4.24, 0) * up, TARGET_WHITE, Enum.PartType.Cylinder)
	addPart(model, Vector3.new(0.1, 0.4, 0.4), at * CFrame.new(0, 4.26, 0) * up, TARGET_RED, Enum.PartType.Cylinder)
	model.PrimaryPart = body
	model:SetAttribute("Radius", Config.DUMMY_RADIUS)
	return model
end

local function spawnDummy(x: number, z: number)
	local enemy = Enemies.spawn("Dummy", x, z, Config.DUMMY_HEALTH, Config.DUMMY_RADIUS)
	local model = buildDummy(x, z)
	model.Parent = folder
	models[enemy.id] = model
end

local function flash(model: Model)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.Color = Color3.new(1, 1, 1)
		end
	end
	task.delay(Config.HIT_FLASH_TIME, function()
		for _, part in model:GetChildren() do
			local base = part:GetAttribute("BaseColor")
			if part:IsA("BasePart") and typeof(base) == "Color3" then
				part.Color = base
			end
		end
	end)
end

function PracticeTargets.start(grid: RoomGrid.RoomGrid)
	folder = Instance.new("Folder")
	folder.Name = "PracticeTargets"
	folder.Parent = workspace

	Enemies.Hit:Connect(function(enemy: Enemies.Enemy)
		local model = models[enemy.id]
		if model then
			flash(model)
		end
	end)

	Enemies.Killed:Connect(function(enemy: Enemies.Enemy)
		local model = models[enemy.id]
		if not model then
			return
		end
		models[enemy.id] = nil
		model:Destroy()
		task.delay(Config.DUMMY_RESPAWN, spawnDummy, enemy.x, enemy.z)
	end)

	for _, cell in grid:find("T") do
		spawnDummy(grid:cellCenter(cell.c, cell.r))
	end
end

return PracticeTargets
