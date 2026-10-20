--!strict
-- Small helpers for making the rounded cartoon parts the kids are built from.
-- Every shape is an ellipsoid (a Part with a sphere SpecialMesh), because
-- ellipsoids can be stretched in any direction and squashed while animating.

local Shapes = {}

local function basePart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
	return part
end

-- An egg/ball/bean shape that exactly fills `size`.
function Shapes.ellipsoid(name: string, size: Vector3, color: Color3, parent: Instance?): Part
	local part = basePart(name, size, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = parent
	return part
end

function Shapes.ball(name: string, diameter: number, color: Color3, parent: Instance?): Part
	return Shapes.ellipsoid(name, Vector3.new(diameter, diameter, diameter), color, parent)
end

-- A plain invisible box, used as the root of a kid and to carry flat drawings (SurfaceGuis).
function Shapes.carrier(name: string, size: Vector3, parent: Instance?): Part
	local part = basePart(name, size, Color3.new(1, 1, 1))
	part.Transparency = 1
	part.CastShadow = false
	part.Parent = parent
	return part
end

function Shapes.block(name: string, size: Vector3, color: Color3, parent: Instance?): Part
	local part = basePart(name, size, color)
	part.Parent = parent
	return part
end

-- A CFrame at `position` whose local Y axis points along `direction`.
function Shapes.alongY(position: Vector3, direction: Vector3): CFrame
	local up = direction.Unit
	local helper = if math.abs(up.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	local right = helper:Cross(up).Unit
	return CFrame.fromMatrix(position, right, up)
end

-- A CFrame at `position` whose front (-Z, where SurfaceGuis and discs face) points along `direction`.
function Shapes.facing(position: Vector3, direction: Vector3): CFrame
	local look = direction.Unit
	local helper = if math.abs(look.Y) > 0.98 then Vector3.zAxis else Vector3.yAxis
	local right = look:Cross(helper).Unit
	local up = right:Cross(look).Unit
	return CFrame.fromMatrix(position, right, up)
end

-- Direction from spherical angles, in a kid's own space where the front is -Z.
-- elevation: 0 = level, 90 = straight up. azimuth: 0 = front, +90 = the kid's right (+X).
function Shapes.direction(elevation: number, azimuth: number): Vector3
	local el, az = math.rad(elevation), math.rad(azimuth)
	return Vector3.new(math.cos(el) * math.sin(az), math.sin(el), -math.cos(el) * math.cos(az))
end

return Shapes
