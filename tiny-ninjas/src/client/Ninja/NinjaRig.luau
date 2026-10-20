--!strict
-- Draws a stick-figure ninja with thin parts: a cylinder along every bone, a ball for
-- the head and a headband across it with two trailing tails. It can show a live pose
-- (joint positions from the Animator) or a ragdoll (one pair of endpoints per bone).
-- The parts are anchored and never collide; all movement comes from our own simulation.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local Rig = require(Shared.Sim.Rig)

local S = Config.STUDS_PER_PX
local THICK = Config.LIMB_THICKNESS_PX * S
local TAIL_THICK = Config.LIMB_THICKNESS_PX * 0.8 * S
local HEAD_R = Config.HEAD_RADIUS_PX * S
local Z_HEAD = 0.04 -- head drawn in front of the limbs...
local Z_BAND = Z_HEAD + HEAD_R + 0.02 -- ...and the band in front of the head ball's surface
local Z_TAIL = -0.04

export type NinjaRig = {
	model: Model,
	parts: { BasePart },
	cframes: { CFrame },
	head: BasePart,
	band: BasePart,
	z: number,
	visible: boolean,
	bones: { { number } }, -- scratch: bone endpoints
}

local NinjaRig = {}

local function makePart(shape: Enum.PartType, color: Color3, size: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A rig parented to `parent`, drawn at depth z (in front of the level's blocks).
function NinjaRig.new(parent: Instance, bodyColor: Color3, bandColor: Color3, z: number): NinjaRig
	local model = Instance.new("Model")
	model.Name = "Ninja"
	local parts: { BasePart } = {}
	for _, bone in Rig.BONES do
		local color = if bone.kind == "tail" then bandColor else bodyColor
		local thick = if bone.kind == "tail" then TAIL_THICK else THICK
		-- Cylinders run along their X axis; a little extra length rounds off the joints.
		local size = Vector3.new(bone.length * S + thick, thick, thick)
		table.insert(parts, makePart(Enum.PartType.Cylinder, color, size, model))
	end
	local head = makePart(Enum.PartType.Ball, bodyColor, Vector3.one * HEAD_R * 2, model)
	head.Name = "Head"
	local band = makePart(Enum.PartType.Cylinder, bandColor, Vector3.new(HEAD_R * 2 + 0.06, THICK * 0.9, THICK * 0.9), model)
	band.Name = "Headband"
	table.insert(parts, head)
	table.insert(parts, band)
	model.Parent = parent
	return {
		model = model,
		parts = parts,
		cframes = table.create(#parts, CFrame.identity),
		head = head,
		band = band,
		z = z,
		visible = true,
		bones = {},
	}
end

-- A part lying along the segment from a to b, in the level's plane.
local function along(ax: number, ay: number, bx: number, by: number, z: number): CFrame
	local a, b = Units.toWorld(ax, ay, z), Units.toWorld(bx, by, z)
	local d = b - a
	local len = d.Magnitude
	local xAxis = if len > 1e-6 then d / len else Vector3.xAxis
	local yAxis = Vector3.zAxis:Cross(xAxis)
	return CFrame.fromMatrix((a + b) / 2, xAxis, yAxis, xAxis:Cross(yAxis))
end

-- Draws bone endpoints given as { ax, ay, bx, by } per bone, in Rig.BONES order (px).
function NinjaRig.drawBones(rig: NinjaRig, bones: { { number } })
	local cf = rig.cframes
	local z = rig.z
	local headX, headY, neckX, neckY = 0, 0, 0, 0
	for i, bone in Rig.BONES do
		local s = bones[i]
		cf[i] = along(s[1], s[2], s[3], s[4], z + (if bone.kind == "tail" then Z_TAIL else 0))
		if bone.kind == "neck" then
			neckX, neckY, headX, headY = s[1], s[2], s[3], s[4]
		end
	end
	local n = #Rig.BONES
	cf[n + 1] = CFrame.new(Units.toWorld(headX, headY, z + Z_HEAD))
	-- The headband crosses the head at right angles to the neck.
	local dx, dy = headX - neckX, headY - neckY
	local len = math.max(math.sqrt(dx * dx + dy * dy), 1e-6)
	local px, py = -dy / len, dx / len
	local r = Config.HEAD_RADIUS_PX
	cf[n + 2] = along(headX - px * r, headY - py * r, headX + px * r, headY + py * r, z + Z_BAND)
	Workspace:BulkMoveTo(rig.parts, cf, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Draws a pose from the Animator.
function NinjaRig.drawPose(rig: NinjaRig, pose: Rig.Pose)
	local bones = rig.bones
	for i, bone in Rig.BONES do
		local a, b = pose[bone.a], pose[bone.b]
		local s = bones[i]
		if s then
			s[1], s[2], s[3], s[4] = a.x, a.y, b.x, b.y
		else
			bones[i] = { a.x, a.y, b.x, b.y }
		end
	end
	NinjaRig.drawBones(rig, bones)
end

function NinjaRig.setVisible(rig: NinjaRig, visible: boolean)
	if rig.visible == visible then
		return
	end
	rig.visible = visible
	for _, part in rig.parts do
		part.Transparency = if visible then 0 else 1
	end
end

function NinjaRig.destroy(rig: NinjaRig)
	rig.model:Destroy()
end

return NinjaRig
