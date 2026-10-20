--!strict
-- A tiny skeleton for the kids. Every part is anchored and follows a "bone"
-- (Body, Head, ArmL, ...). Each frame the animator hands us a Pose and we
-- move all the parts at once. Squash and stretch scales the whole kid
-- about their feet, so hats, hair and clothes squash along with the body.

local KidRig = {}

export type Bone = {
	name: string,
	parent: string?,
	pivot: CFrame, -- rest transform relative to the parent bone
}

export type Attached = {
	part: BasePart,
	bone: string,
	offset: CFrame, -- relative to the bone
	size: Vector3, -- rest size
	mesh: SpecialMesh?,
	-- Parts that carry a SurfaceGui (the head, emblems) squash by changing
	-- their Size so the drawing squashes with them.
	squashBySize: boolean,
}

export type Rig = {
	root: BasePart,
	bones: { [string]: Bone },
	order: { string },
	attached: { Attached },
	restSpace: { [string]: CFrame }, -- each bone at rest, in root space
	lastSquash: Vector2,
	parts: { BasePart },
	frames: { CFrame },
}

export type Pose = {
	root: CFrame, -- world CFrame of the point between the feet
	squash: Vector2?, -- X = width multiplier, Y = height multiplier (1, 1 = rest)
	bones: { [string]: CFrame }?, -- extra rotation for each bone
}

function KidRig.new(root: BasePart): Rig
	local rig: Rig = {
		root = root,
		bones = {},
		order = {},
		attached = {},
		restSpace = { Root = CFrame.identity },
		lastSquash = Vector2.new(1, 1),
		parts = { root },
		frames = { CFrame.identity },
	}
	rig.bones.Root = { name = "Root", parent = nil, pivot = CFrame.identity }
	table.insert(rig.order, "Root")
	return rig
end

-- Bones must be added parent first.
function KidRig.addBone(rig: Rig, name: string, parent: string, pivot: CFrame)
	assert(rig.bones[parent], `parent bone {parent} must be added before {name}`)
	rig.bones[name] = { name = name, parent = parent, pivot = pivot }
	rig.restSpace[name] = rig.restSpace[parent] * pivot
	table.insert(rig.order, name)
end

-- Attach a part to a bone. `offset` is in the bone's own space.
function KidRig.attach(rig: Rig, part: BasePart, bone: string, offset: CFrame, squashBySize: boolean?)
	assert(rig.bones[bone], `unknown bone {bone}`)
	table.insert(rig.attached, {
		part = part,
		bone = bone,
		offset = offset,
		size = part.Size,
		mesh = part:FindFirstChildOfClass("SpecialMesh"),
		squashBySize = squashBySize == true,
	})
	table.insert(rig.parts, part)
	table.insert(rig.frames, CFrame.identity)
end

-- Attach a part using a CFrame in root space (where the kid stands at the origin facing -Z).
function KidRig.attachInRootSpace(rig: Rig, part: BasePart, bone: string, rootSpace: CFrame, squashBySize: boolean?)
	KidRig.attach(rig, part, bone, rig.restSpace[bone]:Inverse() * rootSpace, squashBySize)
end

-- How much a part stretches along one of its own axes when the kid is squashed.
local function axisScale(axis: Vector3, squash: Vector2): number
	local x, y = axis.X * squash.X, axis.Y * squash.Y
	return math.sqrt(x * x + y * y + axis.Z * axis.Z)
end

function KidRig.apply(rig: Rig, pose: Pose)
	local squash = pose.squash or Vector2.new(1, 1)
	local boneAnim = pose.bones
	local boneSpace: { [string]: CFrame } = {}
	for _, name in rig.order do
		local bone = rig.bones[name]
		local parentSpace = if bone.parent then boneSpace[bone.parent] else CFrame.identity
		local extra = boneAnim and boneAnim[name]
		boneSpace[name] = if extra then parentSpace * bone.pivot * extra else parentSpace * bone.pivot
	end

	local squashed = math.abs(squash.X - 1) > 1e-4 or math.abs(squash.Y - 1) > 1e-4
	-- Resizing every part is the expensive bit, so skip tiny changes (idle breathing).
	local target = if squashed then squash else Vector2.one
	local squashChanged = (target - rig.lastSquash).Magnitude > 0.004
		or (not squashed and rig.lastSquash ~= Vector2.one)
	if squashChanged then
		rig.lastSquash = target
	end

	local rootCF = pose.root
	rig.frames[1] = rootCF
	for i, item in rig.attached do
		local placed = boneSpace[item.bone] * item.offset
		if squashed then
			local p = placed.Position
			placed = CFrame.new(p.X * squash.X, p.Y * squash.Y, p.Z) * placed.Rotation
		end
		rig.frames[i + 1] = rootCF * placed

		if squashChanged then
			local scale = if squashed
				then Vector3.new(
					axisScale(placed.XVector, squash),
					axisScale(placed.YVector, squash),
					axisScale(placed.ZVector, squash)
				)
				else Vector3.one
			if item.squashBySize then
				item.part.Size = item.size * scale
			elseif item.mesh then
				item.mesh.Scale = scale
			end
		end
	end

	if rig.root:IsDescendantOf(workspace) then
		workspace:BulkMoveTo(rig.parts, rig.frames, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, part in rig.parts do
			part.CFrame = rig.frames[i]
		end
	end
end

return KidRig
