--!strict
-- Every tunable number lives here. Change a value, rebuild, and play.
-- Distances are in studs, times in seconds, speeds in studs per second.

export type WeaponDef = {
	name: string,
	slot: number,
	damage: number,
	fireInterval: number,
	range: number,
	pierce: number,
	maxAmmo: number?,
	tracerColor: Color3,
}

local Config = {}

Config.GAME_NAME = "Block Horde"

-- Camera ---------------------------------------------------------------------
Config.CAMERA_DISTANCE = 120 -- how far the camera sits from the player
Config.CAMERA_TILT_DEG = 15 -- degrees away from looking straight down (tilted to look north)
Config.CAMERA_FOV = 30
Config.CAMERA_FOLLOW_SHARPNESS = 10 -- higher = camera catches up faster

-- Player ---------------------------------------------------------------------
Config.WALK_SPEED = 16
Config.PLAYER_MAX_HEALTH = 100
Config.RESPAWN_DELAY = 3

-- Where bullets leave the gun, relative to the player's center.
Config.MUZZLE_FORWARD = 3.2
Config.MUZZLE_HEIGHT = 0.5

-- Shirt colors for the blocky hero. Player 1 gets the first, and so on.
Config.SHIRT_COLORS = {
	Color3.fromRGB(133, 128, 74), -- olive khaki
	Color3.fromRGB(52, 101, 196), -- blue
	Color3.fromRGB(226, 128, 36), -- orange
	Color3.fromRGB(133, 72, 186), -- purple
	Color3.fromRGB(32, 160, 150), -- teal
	Color3.fromRGB(222, 98, 160), -- pink
}
Config.SKIN_COLOR = Color3.fromRGB(240, 196, 150)
Config.HAIR_COLOR = Color3.fromRGB(58, 40, 28)
Config.PANTS_COLOR = Color3.fromRGB(62, 60, 54)
Config.GUN_COLOR = Color3.fromRGB(40, 40, 44)

-- Rooms ----------------------------------------------------------------------
Config.CELL_SIZE = 4 -- one map character = one 4x4 stud cell
Config.WALL_HEIGHT = 6
Config.WALL_COLOR = Color3.fromRGB(112, 102, 92)
Config.WALL_TOP_COLOR = Color3.fromRGB(92, 83, 74)
Config.FLOOR_COLOR_A = Color3.fromRGB(196, 196, 192)
Config.FLOOR_COLOR_B = Color3.fromRGB(186, 186, 182)
Config.VOID_COLOR = Color3.fromRGB(28, 28, 32)
Config.START_ROOM = "Practice"

-- Weapons --------------------------------------------------------------------
-- slot: number key that selects it (10 means the 0 key).
-- maxAmmo = nil means infinite ammo.
-- pierce: how many enemies one bullet can pass through (1 = stops at the first).
Config.WEAPONS = {
	pistol = {
		name = "PISTOL",
		slot = 1,
		damage = 10,
		fireInterval = 0.3,
		range = 60,
		pierce = 1,
		maxAmmo = nil,
		tracerColor = Color3.fromRGB(255, 226, 64),
	},
} :: { [string]: WeaponDef }

-- Effects ----------------------------------------------------------------------
Config.TRACER_LIFETIME = 0.07
Config.TRACER_WIDTH = 0.18
Config.MUZZLE_FLASH_TIME = 0.05

-- Practice targets (Milestone 1 only, replaced by real zombies in Milestone 3)
Config.DUMMY_HEALTH = 30
Config.DUMMY_RADIUS = 1.3
Config.DUMMY_RESPAWN = 3
Config.HIT_FLASH_TIME = 0.1

return Config
