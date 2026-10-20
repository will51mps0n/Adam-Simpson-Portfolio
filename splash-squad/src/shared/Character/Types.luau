--!strict
-- Shared types for the character modules.

local HeadShape = require(script.Parent.HeadShape)

-- Measurements of one kid, in studs. Heights are measured up from the feet.
export type Dims = {
	scale: number,
	head: Vector3,
	body: Vector3,
	leg: Vector3,
	arm: Vector3,
	hand: Vector3,
	shoe: Vector3,
	feet: Vector3,
	legSpread: number,
	legTopY: number,
	bodyBottomY: number,
	bodyTopY: number,
	neckY: number,
	headCenterY: number,
	height: number,
	shoulderY: number,
	shoulderX: number,
}

-- Handed to the hair, hat and accessory builders.
export type Context = {
	model: Model,
	dims: Dims,
	scale: number,
	skin: Color3,
	headRadii: Vector3,
	-- Filled in by the hair builder:
	cap: HeadShape.Cap?,
	hairTop: number, -- head space height of the top of the hair
	hairPuff: number, -- how far the hair sticks out (1 = bald)
	-- Attach a part. Head space has its origin at the head's center.
	addToHead: (part: BasePart, headSpace: CFrame) -> (),
	addToBone: (part: BasePart, bone: string, boneSpace: CFrame, squashBySize: boolean?) -> (),
	addInRootSpace: (part: BasePart, bone: string, rootSpace: CFrame) -> (),
}

return {}
