--!strict
-- Block models for every enemy type. Clients build these (never the server)
-- and move them around from position updates. Offsets are relative to the
-- enemy's feet, facing -Z. Parts with a `limb` swing while walking around
-- their `joint` (also relative to the feet).

export type PartSpec = {
	size: Vector3,
	offset: Vector3,
	color: Color3,
	limb: ("Leg" | "LegOpposite" | "Arm" | "ArmOpposite" | "Bob")?,
	joint: Vector3?,
	tilt: number?, -- fixed rotation around X in degrees (e.g. horns)
	neon: boolean?,
}

export type ModelSpec = {
	scale: number,
	parts: { PartSpec },
	debris: { Color3 }, -- colors of the chunks that fly off on death
}

local EnemyModels = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- The shared humanoid block body: two legs, a torso and a big head.
local function body(skin: Color3, shirt: Color3, pants: Color3, eyes: Color3, armsForward: boolean): { PartSpec }
	local parts: { PartSpec } = {
		{ size = Vector3.new(0.9, 2, 0.9), offset = Vector3.new(-0.5, 1, 0), color = pants, limb = "Leg", joint = Vector3.new(-0.5, 2, 0) },
		{ size = Vector3.new(0.9, 2, 0.9), offset = Vector3.new(0.5, 1, 0), color = pants, limb = "LegOpposite", joint = Vector3.new(0.5, 2, 0) },
		{ size = Vector3.new(2, 1.9, 1.2), offset = Vector3.new(0, 2.85, 0), color = shirt },
		{ size = Vector3.new(2.1, 2.1, 2.1), offset = Vector3.new(0, 4.85, 0), color = skin },
		{ size = Vector3.new(0.34, 0.32, 0.1), offset = Vector3.new(-0.45, 5.05, -1.07), color = eyes, neon = true },
		{ size = Vector3.new(0.34, 0.32, 0.1), offset = Vector3.new(0.45, 5.05, -1.07), color = eyes, neon = true },
	}
	if armsForward then
		-- Classic zombie pose: both arms stretched out in front.
		table.insert(parts, { size = Vector3.new(0.55, 0.55, 1.8), offset = Vector3.new(-0.75, 3.4, -1.3), color = skin, limb = "Bob", joint = Vector3.new(-0.75, 3.4, -0.4) })
		table.insert(parts, { size = Vector3.new(0.55, 0.55, 1.8), offset = Vector3.new(0.75, 3.4, -1.3), color = skin, limb = "Bob", joint = Vector3.new(0.75, 3.4, -0.4) })
	else
		table.insert(parts, { size = Vector3.new(0.55, 1.8, 0.55), offset = Vector3.new(-1.28, 2.85, 0), color = shirt, limb = "ArmOpposite", joint = Vector3.new(-1.28, 3.7, 0) })
		table.insert(parts, { size = Vector3.new(0.55, 1.8, 0.55), offset = Vector3.new(1.28, 2.85, 0), color = shirt, limb = "Arm", joint = Vector3.new(1.28, 3.7, 0) })
	end
	return parts
end

local function with(parts: { PartSpec }, extra: { PartSpec }): { PartSpec }
	for _, part in extra do
		table.insert(parts, part)
	end
	return parts
end

EnemyModels.SPECS = {
	-- Pale grey-green, dark clothes, arms out front.
	Zombie = {
		scale = 1,
		parts = with(body(rgb(150, 172, 138), rgb(70, 80, 64), rgb(48, 48, 60), rgb(120, 20, 20), true), {
			{ size = Vector3.new(1.5, 0.2, 1.3), offset = Vector3.new(0.1, 5.95, 0.2), color = rgb(112, 132, 100) }, -- patchy scalp
			{ size = Vector3.new(0.9, 0.4, 0.1), offset = Vector3.new(0.2, 4.35, -1.07), color = rgb(60, 30, 30) }, -- mouth
		}),
		debris = { rgb(150, 172, 138), rgb(70, 80, 64), rgb(150, 20, 20) },
	},
	-- Smaller, yellow-green and fast, in a torn red shirt.
	Runner = {
		scale = 0.88,
		parts = with(body(rgb(178, 188, 118), rgb(150, 46, 40), rgb(64, 52, 40), rgb(30, 30, 30), true), {
			{ size = Vector3.new(2.2, 0.35, 2.2), offset = Vector3.new(0, 5.95, 0.15), color = rgb(52, 40, 30) }, -- hair
		}),
		debris = { rgb(178, 188, 118), rgb(150, 46, 40), rgb(150, 20, 20) },
	},
	-- Red all over with small black horns and glowing yellow eyes.
	Devil = {
		scale = 1.05,
		parts = with(body(rgb(212, 42, 34), rgb(178, 30, 26), rgb(110, 18, 18), rgb(255, 220, 60), true), {
			{ size = Vector3.new(0.38, 0.8, 0.38), offset = Vector3.new(-0.68, 6.2, -0.25), color = rgb(36, 16, 16), tilt = -18 },
			{ size = Vector3.new(0.38, 0.8, 0.38), offset = Vector3.new(0.68, 6.2, -0.25), color = rgb(36, 16, 16), tilt = -18 },
			{ size = Vector3.new(0.3, 0.3, 1.4), offset = Vector3.new(0, 1.9, 1.15), color = rgb(110, 18, 18), tilt = 25 }, -- tail
		}),
		debris = { rgb(212, 42, 34), rgb(110, 18, 18), rgb(36, 16, 16) },
	},
	-- A big slow tank wrapped in off-white bandages.
	Mummy = {
		scale = 1.15,
		parts = with(body(rgb(226, 216, 188), rgb(220, 208, 176), rgb(206, 194, 160), rgb(30, 20, 16), true), {
			{ size = Vector3.new(2.06, 0.28, 1.26), offset = Vector3.new(0, 2.4, 0), color = rgb(188, 176, 140) },
			{ size = Vector3.new(2.06, 0.28, 1.26), offset = Vector3.new(0, 3.3, 0), color = rgb(188, 176, 140) },
			{ size = Vector3.new(2.16, 0.3, 2.16), offset = Vector3.new(0, 4.3, 0), color = rgb(188, 176, 140) },
			{ size = Vector3.new(2.16, 0.3, 2.16), offset = Vector3.new(0, 5.55, 0), color = rgb(188, 176, 140) },
		}),
		debris = { rgb(226, 216, 188), rgb(188, 176, 140), rgb(150, 20, 20) },
	},
	-- Dark purple cloak and high collar, pale face, red eyes. Teleports.
	Vampire = {
		scale = 1,
		parts = with(body(rgb(226, 220, 236), rgb(72, 30, 98), rgb(36, 26, 46), rgb(230, 30, 30), false), {
			{ size = Vector3.new(2.6, 3.4, 0.3), offset = Vector3.new(0, 2.5, 0.78), color = rgb(30, 14, 42) }, -- cape
			{ size = Vector3.new(2.5, 1, 0.35), offset = Vector3.new(0, 4.1, 0.75), color = rgb(150, 20, 40) }, -- collar
			{ size = Vector3.new(2.2, 0.45, 2.2), offset = Vector3.new(0, 5.95, 0.1), color = rgb(20, 16, 24) }, -- slicked hair
		}),
		debris = { rgb(72, 30, 98), rgb(226, 220, 236), rgb(30, 14, 42) },
	},
} :: { [string]: ModelSpec }

return EnemyModels
