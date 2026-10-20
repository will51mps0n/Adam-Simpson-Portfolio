--!strict
-- Block models for things in the arena: placeable barrels, fake walls,
-- mines and turrets, plus ammo crates. Built by the server.

local PropModels = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function block(model: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- at: the floor point at the center of the cell.
function PropModels.barrel(at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Barrel"
	local body = block(model, "Body", Vector3.new(2.8, 3, 2.8), at * CFrame.new(0, 1.5, 0), rgb(200, 40, 32))
	block(model, "Band", Vector3.new(2.9, 0.25, 2.9), at * CFrame.new(0, 0.8, 0), rgb(120, 20, 20))
	block(model, "Band", Vector3.new(2.9, 0.25, 2.9), at * CFrame.new(0, 2.2, 0), rgb(120, 20, 20))
	block(model, "Lid", Vector3.new(2.4, 0.12, 2.4), at * CFrame.new(0, 3.06, 0), rgb(222, 72, 60))
	block(model, "Warning", Vector3.new(0.9, 0.06, 0.9), at * CFrame.new(0, 3.14, 0), rgb(245, 200, 40))
	model.PrimaryPart = body
	return model
end

function PropModels.wall(at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "FakeWall"
	local body = block(model, "Body", Vector3.new(4, 4.6, 4), at * CFrame.new(0, 2.3, 0), rgb(150, 146, 140))
	block(model, "Top", Vector3.new(4, 0.3, 4), at * CFrame.new(0, 4.75, 0), rgb(122, 118, 112))
	block(model, "Seam", Vector3.new(4.04, 0.15, 4.04), at * CFrame.new(0, 1.5, 0), rgb(122, 118, 112))
	block(model, "Seam", Vector3.new(4.04, 0.15, 4.04), at * CFrame.new(0, 3.1, 0), rgb(122, 118, 112))
	model.PrimaryPart = body
	return model
end

function PropModels.mine(at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Mine"
	local base = block(model, "Base", Vector3.new(1.8, 0.3, 1.8), at * CFrame.new(0, 0.15, 0), rgb(50, 50, 54))
	block(model, "Top", Vector3.new(1, 0.15, 1), at * CFrame.new(0, 0.37, 0), rgb(92, 92, 98))
	block(model, "Light", Vector3.new(0.35, 0.12, 0.35), at * CFrame.new(0, 0.5, 0), rgb(255, 40, 40), Enum.Material.Neon)
	for _, part in model:GetChildren() do
		(part :: BasePart).CanCollide = false
	end
	model.PrimaryPart = base
	return model
end

-- Returns the turret and its head (the part that turns to aim).
function PropModels.turret(at: CFrame): (Model, Model)
	local model = Instance.new("Model")
	model.Name = "Turret"
	local base = block(model, "Base", Vector3.new(2.6, 1, 2.6), at * CFrame.new(0, 0.5, 0), rgb(70, 72, 78))
	block(model, "Post", Vector3.new(0.8, 1.6, 0.8), at * CFrame.new(0, 1.8, 0), rgb(56, 58, 62))
	local head = Instance.new("Model")
	head.Name = "Head"
	local pivot = block(head, "Housing", Vector3.new(1.6, 1, 1.8), at * CFrame.new(0, 3, 0), rgb(98, 104, 92))
	block(head, "Barrel", Vector3.new(0.35, 0.35, 1.8), at * CFrame.new(0, 3.05, -1.6), rgb(36, 36, 40))
	block(head, "AmmoBox", Vector3.new(0.6, 0.6, 0.8), at * CFrame.new(0.95, 3, 0.2), rgb(110, 116, 60))
	head.PrimaryPart = pivot
	head.Parent = model
	model.PrimaryPart = base
	return model, head
end

function PropModels.ammoCrate(at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "AmmoCrate"
	local body = block(model, "Body", Vector3.new(2.2, 1.6, 2.2), at * CFrame.new(0, 0.8, 0), rgb(176, 128, 72), Enum.Material.Wood)
	block(model, "Slat", Vector3.new(2.26, 0.25, 2.26), at * CFrame.new(0, 0.4, 0), rgb(120, 84, 46))
	block(model, "Slat", Vector3.new(2.26, 0.25, 2.26), at * CFrame.new(0, 1.2, 0), rgb(120, 84, 46))
	block(model, "Label", Vector3.new(1.2, 0.06, 0.6), at * CFrame.new(0, 1.63, 0), rgb(245, 200, 40))
	for _, part in model:GetChildren() do
		(part :: BasePart).CanCollide = false
	end
	model.PrimaryPart = body
	return model
end

return PropModels
