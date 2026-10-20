--!strict
-- The blocky hero: a big square head with dark hair and a red commando
-- headband, a box torso in the player's shirt color, and both arms held
-- forward around a small dark gun.
-- Offsets are relative to the HumanoidRootPart, which sits about 3 studs above
-- the floor and faces -Z. Legs ride on the avatar's own legs so they swing
-- when walking.

local Config = require(script.Parent.Parent.Config)

export type Attach = "Root" | "LeftLeg" | "RightLeg"

export type PartSpec = {
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	attach: Attach,
	shape: Enum.PartType?,
	transparency: number?,
}

local HeroModel = {}

local EYE_COLOR = Color3.fromRGB(24, 24, 28)

function HeroModel.parts(shirt: Color3): { PartSpec }
	local skin = Config.SKIN_COLOR
	local hair = Config.HAIR_COLOR
	return {
		-- Legs (the offset is used only if the avatar has no leg to ride on)
		{ name = "LeftLeg", size = Vector3.new(0.9, 2, 0.9), offset = CFrame.new(-0.5, -2, 0), color = Config.PANTS_COLOR, attach = "LeftLeg" },
		{ name = "RightLeg", size = Vector3.new(0.9, 2, 0.9), offset = CFrame.new(0.5, -2, 0), color = Config.PANTS_COLOR, attach = "RightLeg" },
		-- Body
		{ name = "Torso", size = Vector3.new(2, 1.8, 1.2), offset = CFrame.new(0, -0.2, 0), color = shirt, attach = "Root" },
		{ name = "Head", size = Vector3.new(2.2, 2.2, 2.2), offset = CFrame.new(0, 1.8, 0), color = skin, attach = "Root" },
		{ name = "Hair", size = Vector3.new(2.4, 0.5, 2.4), offset = CFrame.new(0, 3, 0.05), color = hair, attach = "Root" },
		{ name = "HairBack", size = Vector3.new(2.4, 1.4, 0.4), offset = CFrame.new(0, 2.3, 1.05), color = hair, attach = "Root" },
		-- Red commando headband with two tails hanging off the back
		{ name = "Headband", size = Vector3.new(2.32, 0.36, 2.32), offset = CFrame.new(0, 2.4, 0), color = Config.HEADBAND_COLOR, attach = "Root" },
		{ name = "BandTailL", size = Vector3.new(0.26, 0.26, 1), offset = CFrame.new(-0.25, 2.25, 1.55) * CFrame.Angles(math.rad(-25), math.rad(-12), 0), color = Config.HEADBAND_COLOR, attach = "Root" },
		{ name = "BandTailR", size = Vector3.new(0.26, 0.26, 1), offset = CFrame.new(0.25, 2.2, 1.55) * CFrame.Angles(math.rad(-35), math.rad(12), 0), color = Config.HEADBAND_COLOR, attach = "Root" },
		{ name = "LeftEye", size = Vector3.new(0.32, 0.42, 0.1), offset = CFrame.new(-0.45, 1.95, -1.12), color = EYE_COLOR, attach = "Root" },
		{ name = "RightEye", size = Vector3.new(0.32, 0.42, 0.1), offset = CFrame.new(0.45, 1.95, -1.12), color = EYE_COLOR, attach = "Root" },
		-- Arms held forward, hands meeting at the gun
		{ name = "LeftArm", size = Vector3.new(0.55, 0.55, 1.5), offset = CFrame.new(-0.72, 0.4, -1.15), color = shirt, attach = "Root" },
		{ name = "RightArm", size = Vector3.new(0.55, 0.55, 1.5), offset = CFrame.new(0.72, 0.4, -1.15), color = shirt, attach = "Root" },
		{ name = "LeftHand", size = Vector3.new(0.6, 0.6, 0.6), offset = CFrame.new(-0.5, 0.4, -2.05), color = skin, attach = "Root" },
		{ name = "RightHand", size = Vector3.new(0.6, 0.6, 0.6), offset = CFrame.new(0.5, 0.4, -2.05), color = skin, attach = "Root" },
		{ name = "Gun", size = Vector3.new(0.4, 0.5, 1.4), offset = CFrame.new(0, 0.5, -2.5), color = Config.GUN_COLOR, attach = "Root" },
		-- A faint ring on the floor in the shirt color, so co-op players are easy to spot from above
		{
			name = "Ring",
			size = Vector3.new(0.1, 3.8, 3.8),
			offset = CFrame.new(0, -2.95, 0) * CFrame.Angles(0, 0, math.rad(90)),
			color = shirt,
			attach = "Root",
			shape = Enum.PartType.Cylinder,
			transparency = 0.45,
		},
	}
end

return HeroModel
