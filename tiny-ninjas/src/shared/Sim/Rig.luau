--!strict
-- The stick figure: named joints and the bones between them. The live animation and the
-- ragdoll both produce joint positions; the renderer draws a limb along every bone.

local Config = require(script.Parent.Parent.Config)

export type Point = { x: number, y: number }
export type Pose = { [string]: Point } -- joint name -> position (simulation px)

export type Bone = {
	a: string,
	b: string,
	length: number,
	kind: "limb" | "neck" | "tail",
}

local Rig = {}

Rig.UPPER_ARM = 4.3
Rig.LOWER_ARM = 4.3
Rig.UPPER_LEG = 4.8
Rig.LOWER_LEG = 4.8
Rig.TORSO = 6.0
Rig.NECK = 2.3 -- neck joint to the center of the head
Rig.TAIL = Config.HEADBAND_TAIL_PX

Rig.JOINTS = {
	"head",
	"neck",
	"hip",
	"elbowL",
	"handL",
	"elbowR",
	"handR",
	"kneeL",
	"footL",
	"kneeR",
	"footR",
	"tail1",
	"tail1End",
	"tail2",
	"tail2End",
}

Rig.BONES = {
	{ a = "neck", b = "head", length = Rig.NECK, kind = "neck" },
	{ a = "neck", b = "hip", length = Rig.TORSO, kind = "limb" },
	{ a = "neck", b = "elbowL", length = Rig.UPPER_ARM, kind = "limb" },
	{ a = "elbowL", b = "handL", length = Rig.LOWER_ARM, kind = "limb" },
	{ a = "neck", b = "elbowR", length = Rig.UPPER_ARM, kind = "limb" },
	{ a = "elbowR", b = "handR", length = Rig.LOWER_ARM, kind = "limb" },
	{ a = "hip", b = "kneeL", length = Rig.UPPER_LEG, kind = "limb" },
	{ a = "kneeL", b = "footL", length = Rig.LOWER_LEG, kind = "limb" },
	{ a = "hip", b = "kneeR", length = Rig.UPPER_LEG, kind = "limb" },
	{ a = "kneeR", b = "footR", length = Rig.LOWER_LEG, kind = "limb" },
	{ a = "head", b = "tail1", length = Rig.TAIL, kind = "tail" },
	{ a = "tail1", b = "tail1End", length = Rig.TAIL, kind = "tail" },
	{ a = "head", b = "tail2", length = Rig.TAIL * 0.85, kind = "tail" },
	{ a = "tail2", b = "tail2End", length = Rig.TAIL * 0.85, kind = "tail" },
} :: { Bone }

function Rig.newPose(x: number, y: number): Pose
	local pose: Pose = {}
	for _, name in Rig.JOINTS do
		pose[name] = { x = x, y = y }
	end
	return pose
end

function Rig.copyPose(from: Pose, into: Pose?): Pose
	local pose: Pose = into or {}
	for name, p in from do
		local q = pose[name]
		if q then
			q.x, q.y = p.x, p.y
		else
			pose[name] = { x = p.x, y = p.y }
		end
	end
	return pose
end

return Rig
