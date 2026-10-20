--!strict
-- Every tunable number lives here. Change a value, reinstall, and play.
-- Distances are in studs (1 map cell = 4 studs), times in seconds,
-- speeds in studs per second.

export type WeaponDef = {
	name: string, -- full name for pop-ups
	short: string, -- name on the weapon bar
	slot: number, -- number key that selects it (10 means the 0 key)
	kind: "hitscan" | "grenade" | "rocket" | "place",
	place: string?, -- for kind "place": which placeable it drops
	fireInterval: number, -- seconds between shots
	maxAmmo: number?, -- nil = infinite
	damage: number?,
	range: number?,
	pierce: number?, -- enemies one bullet passes through (1 = stops at the first)
	pellets: number?, -- bullets per shot
	spread: number?, -- degrees: the whole cone for several pellets, random wobble for one
	blastRadius: number?,
	speed: number?, -- rockets
	fuse: number?, -- grenades
	throwDistance: number?, -- grenades: first throw
	throwStep: number?, -- grenades: extra distance for each quick follow-up throw
	throwMax: number?,
	throwComboWindow: number?, -- grenades: press again within this long to throw further
	beam: boolean?, -- draw as a glowing beam instead of a tracer
	tracerColor: Color3?,
}

export type EnemyDef = {
	health: number,
	speed: number,
	radius: number, -- hit circle and body size
	damage: number, -- melee damage per hit
	attackCooldown: number,
	score: number, -- points per kill before the multiplier
	-- Devil only
	keepDistance: number?,
	fireballInterval: number?,
	fireballRange: number?,
	-- Vampire only
	teleportInterval: number?,
	teleportDistance: number?,
}

export type DifficultyDef = { count: number, speed: number, damage: number }

export type MixDef = { fromWave: number, share: number, growth: number, max: number }

local Config = {}

Config.GAME_NAME = "Block Horde"

-- Camera ---------------------------------------------------------------------
Config.CAMERA_DISTANCE = 120 -- how far the camera sits from the player
Config.CAMERA_TILT_DEG = 15 -- degrees away from looking straight down (tilted to look north)
Config.CAMERA_FOV = 30
Config.CAMERA_FOLLOW_SHARPNESS = 10 -- higher = camera catches up faster
Config.CAMERA_SHAKE_MAX = 1.6 -- studs of shake right next to a big explosion
Config.CAMERA_SHAKE_RANGE = 70 -- explosions further away than this do not shake
Config.CAMERA_SHAKE_TIME = 0.35

-- Player ---------------------------------------------------------------------
Config.WALK_SPEED = 16
Config.PLAYER_MAX_HEALTH = 100
Config.HEALTH_REGEN_PER_SEC = 5
Config.HEALTH_REGEN_DELAY = 4 -- seconds without damage before regen starts
Config.PLAYER_RADIUS = 1.2 -- how close an enemy must get to hit you
Config.REVIVE_AT_WAVE_END = false -- true: dead players come back at the next wave
Config.HUB_RESPAWN_DELAY = 3

-- Where bullets leave the gun, relative to the player's center.
Config.MUZZLE_FORWARD = 3.2
Config.MUZZLE_HEIGHT = 0.5

-- Shirt colors for the blocky hero. Player 1 gets the first, and so on.
Config.SHIRT_COLORS = {
	Color3.fromRGB(122, 128, 70), -- army olive
	Color3.fromRGB(52, 101, 196), -- blue
	Color3.fromRGB(226, 128, 36), -- orange
	Color3.fromRGB(133, 72, 186), -- purple
	Color3.fromRGB(32, 160, 150), -- teal
	Color3.fromRGB(222, 98, 160), -- pink
}
Config.SKIN_COLOR = Color3.fromRGB(236, 190, 140)
Config.HAIR_COLOR = Color3.fromRGB(40, 30, 24)
Config.HEADBAND_COLOR = Color3.fromRGB(206, 36, 36)
Config.PANTS_COLOR = Color3.fromRGB(70, 66, 52)
Config.GUN_COLOR = Color3.fromRGB(40, 40, 44)

-- Multiplier -------------------------------------------------------------------
Config.MULT_DECAY_DELAY = 2 -- seconds after a kill before the multiplier starts draining
Config.MULT_DECAY_RATE = 2 -- points per second it drains (never below 1)

-- Waves ----------------------------------------------------------------------
-- Wave n sends (WAVE_BASE + WAVE_PER_WAVE * n) enemies, times
-- (1 + WAVE_PER_EXTRA_PLAYER * (players - 1)), times the difficulty's count.
Config.WAVE_BASE = 6
Config.WAVE_PER_WAVE = 4
Config.WAVE_PER_EXTRA_PLAYER = 0.3
Config.WAVE_SPAWN_TIME = 10 -- enemies trickle in over about this long
Config.WAVE_SPEED_PER_WAVE = 0.04 -- enemies get 4% faster each wave...
Config.WAVE_SPEED_CAP = 2 -- ...up to double speed
Config.WAVE_BREAK = 4 -- pause between waves
Config.RUN_START_DELAY = 3 -- "GET READY" before wave 1
Config.MAX_ALIVE_ENEMIES = 200 -- extra enemies wait off-screen until there is room
Config.RESULTS_TIME = 10 -- game over screen before going back to the lobby

-- Which enemies show up. Share = fraction of a wave; it grows each wave up to the max.
Config.ENEMY_MIX = {
	Devil = { fromWave = 3, share = 0.125, growth = 0.01, max = 0.3 },
	Runner = { fromWave = 5, share = 0.15, growth = 0.01, max = 0.3 },
	Mummy = { fromWave = 8, share = 0.06, growth = 0.005, max = 0.15 },
	Vampire = { fromWave = 10, share = 0.06, growth = 0.005, max = 0.15 },
} :: { [string]: MixDef }

Config.DIFFICULTY_ORDER = { "Beginner", "Intermediate", "Expert", "Nightmare" }
Config.DIFFICULTIES = {
	Beginner = { count = 0.75, speed = 0.85, damage = 0.6 },
	Intermediate = { count = 1, speed = 1, damage = 1 },
	Expert = { count = 1.3, speed = 1.12, damage = 1.4 },
	Nightmare = { count = 1.7, speed = 1.25, damage = 2 },
} :: { [string]: DifficultyDef }

-- Enemies ----------------------------------------------------------------------
-- The order matters: it is how enemy types are numbered on the network.
Config.ENEMY_KINDS = { "Zombie", "Runner", "Devil", "Mummy", "Vampire" }
Config.ENEMIES = {
	Zombie = { health = 30, speed = 7, radius = 1.1, damage = 10, attackCooldown = 1, score = 10 },
	Runner = { health = 20, speed = 12, radius = 1, damage = 8, attackCooldown = 0.9, score = 15 },
	Devil = {
		health = 180, -- 6x a zombie
		speed = 9,
		radius = 1.2,
		damage = 15,
		attackCooldown = 1,
		score = 50,
		keepDistance = 18,
		fireballInterval = 2.5,
		fireballRange = 45,
	},
	Mummy = { health = 160, speed = 5, radius = 1.4, damage = 25, attackCooldown = 1.3, score = 40 },
	Vampire = {
		health = 60,
		speed = 8,
		radius = 1.1,
		damage = 15,
		attackCooldown = 1,
		score = 40,
		teleportInterval = 4,
		teleportDistance = 14,
	},
} :: { [string]: EnemyDef }

Config.FIREBALL_SPEED = 22
Config.FIREBALL_DAMAGE = 15 -- to players
Config.FIREBALL_ENEMY_DAMAGE = 30 -- to zombies it passes through
Config.FIREBALL_RADIUS = 0.9
Config.ENEMY_SEPARATION = 6 -- how hard enemies push apart
Config.ENEMY_ENTER_DISTANCE = 6 -- enemies appear this far outside an entry gap and walk in
Config.FLOW_FIELD_INTERVAL = 0.25 -- seconds between path updates
Config.PLACEABLE_PATH_COST = 12 -- how much enemies prefer walking around your barrels and walls

-- Weapons --------------------------------------------------------------------
Config.WEAPON_ORDER = { "pistol", "uzi", "shotgun", "barrels", "grenades", "mines", "rockets", "railgun", "fakewalls", "turret" }
Config.WEAPONS = {
	pistol = {
		name = "PISTOL",
		short = "PISTOL",
		slot = 1,
		kind = "hitscan",
		fireInterval = 0.3,
		damage = 10,
		range = 60,
		tracerColor = Color3.fromRGB(255, 226, 64),
	},
	uzi = {
		name = "UZI",
		short = "UZI",
		slot = 2,
		kind = "hitscan",
		fireInterval = 0.1,
		maxAmmo = 150,
		damage = 7,
		range = 55,
		spread = 4,
		tracerColor = Color3.fromRGB(255, 236, 110),
	},
	shotgun = {
		name = "SHOTGUN",
		short = "SHOTGUN",
		slot = 3,
		kind = "hitscan",
		fireInterval = 0.75,
		maxAmmo = 24,
		damage = 11,
		range = 26,
		pellets = 5,
		spread = 30,
		tracerColor = Color3.fromRGB(255, 210, 90),
	},
	barrels = { name = "BARRELS", short = "BARREL", slot = 4, kind = "place", place = "barrel", fireInterval = 0.35, maxAmmo = 10, damage = 90, blastRadius = 12 },
	grenades = {
		name = "GRENADES",
		short = "GRENADE",
		slot = 5,
		kind = "grenade",
		fireInterval = 0.35,
		maxAmmo = 12,
		damage = 70,
		blastRadius = 12,
		fuse = 1.5,
		throwDistance = 16,
		throwStep = 5,
		throwMax = 34,
		throwComboWindow = 0.7,
	},
	mines = { name = "MINES", short = "MINE", slot = 6, kind = "place", place = "mine", fireInterval = 0.35, maxAmmo = 10, damage = 110, blastRadius = 10 },
	rockets = {
		name = "ROCKET LAUNCHER",
		short = "ROCKET",
		slot = 7,
		kind = "rocket",
		fireInterval = 0.9,
		maxAmmo = 12,
		damage = 90,
		blastRadius = 10,
		speed = 75,
		range = 100,
	},
	railgun = {
		name = "RAILGUN",
		short = "RAIL",
		slot = 8,
		kind = "hitscan",
		fireInterval = 1.2,
		maxAmmo = 12,
		damage = 70,
		range = 120,
		pierce = math.huge,
		beam = true,
		tracerColor = Color3.fromRGB(90, 230, 255),
	},
	fakewalls = { name = "FAKE WALLS", short = "WALL", slot = 9, kind = "place", place = "wall", fireInterval = 0.3, maxAmmo = 12 },
	turret = { name = "MACHINE-GUN TURRET", short = "TURRET", slot = 10, kind = "place", place = "turret", fireInterval = 0.5, maxAmmo = 2 },
} :: { [string]: WeaponDef }

-- What each upgrade does. Multipliers apply to the weapon's numbers.
Config.UPGRADE_EFFECTS = {
	FastFire = { fireInterval = 0.75 },
	RapidFire = { fireInterval = 0.5 },
	DoubleAmmo = { maxAmmo = 2 },
	QuadAmmo = { maxAmmo = 4 },
	DoubleDamage = { damage = 2 },
	WideShot = { spread = 1.4, pellets = 2 },
	WiderShot = { spread = 1.8, pellets = 4 },
	LongShot = { range = 1.5 },
	BigBang = { blastRadius = 1.4, damage = 1.3 },
	BiggerBang = { blastRadius = 1.8, damage = 1.6 },
	BigShot = { spread = 1.3, pellets = 3, damage = 1.25 },
	UnlimitedAmmo = {},
} :: { [string]: { [string]: number } }

-- Placeables (dropped on the cell in front of you) ------------------------------
-- (Barrel and mine blast size and damage are with the weapons above.)
Config.BARREL_HEALTH = 40 -- enemies chew through it; shoot it and it explodes
Config.BARREL_RADIUS = 1.6 -- hit circle for bullets
Config.BARREL_CHAIN_DELAY = 0.12 -- delay before a barrel caught in a blast goes off
Config.WALL_HEALTH = 220
Config.MINE_TRIGGER_RADIUS = 2
Config.TURRET_HEALTH = 150
Config.TURRET_RANGE = 34
Config.TURRET_FIRE_INTERVAL = 0.22
Config.TURRET_DAMAGE = 9
Config.TURRET_AMMO = 250

-- Explosions -------------------------------------------------------------------
Config.SELF_DAMAGE = true -- your own explosions hurt you
Config.SELF_DAMAGE_SCALE = 0.5 -- ...but only this much
Config.TEAM_DAMAGE = false -- your explosions never hurt teammates
Config.EXPLOSION_EDGE_DAMAGE = 0.4 -- damage at the edge of a blast compared to the center

-- Ammo boxes -------------------------------------------------------------------
Config.AMMO_BOX_INTERVAL = 8
Config.AMMO_BOX_MAX = 3
Config.AMMO_BOX_REFILL = 0.3 -- fraction of each weapon's max ammo
Config.AMMO_BOX_PICKUP_RADIUS = 2.6

-- Rooms ----------------------------------------------------------------------
Config.CELL_SIZE = 4 -- one map character = one 4x4 stud cell
Config.WALL_HEIGHT = 6
Config.WALL_COLOR = Color3.fromRGB(112, 102, 92)
Config.WALL_TOP_COLOR = Color3.fromRGB(88, 80, 72)
Config.FLOOR_COLOR_A = Color3.fromRGB(196, 196, 192)
Config.FLOOR_COLOR_B = Color3.fromRGB(184, 184, 180)
Config.VOID_COLOR = Color3.fromRGB(26, 26, 30)
Config.HUB_CENTER_Z = 700 -- the lobby sits this far south of the arena

-- Lobby and parties --------------------------------------------------------------
Config.PARTY_MAX_PLAYERS = 6
Config.PARTY_DEFAULT_SIZE = 4
Config.PARTY_COUNTDOWN = 5
Config.TELEPORT_RETRIES = 3
Config.ARRIVAL_WAIT = 20 -- in a party's private server, wait this long for everyone to arrive

-- High scores ----------------------------------------------------------------------
Config.SCOREBOARD_SIZE = 8
Config.SCOREBOARD_REFRESH = 60
Config.SCOREBOARD_CYCLE = 6 -- seconds each difficulty shows on a board

-- Effects ----------------------------------------------------------------------
Config.TRACER_LIFETIME = 0.07
Config.TRACER_WIDTH = 0.18
Config.BEAM_LIFETIME = 0.25
Config.MUZZLE_FLASH_TIME = 0.05
Config.HIT_FLASH_TIME = 0.1
Config.SPLAT_MAX = 150 -- blood splats kept on the floor; the oldest fade out
Config.DEBRIS_PER_DEATH = 6
Config.ENEMY_INTERP_DELAY = 0.12 -- clients draw enemies this far in the past to keep motion smooth
Config.SNAPSHOT_RATE = 15 -- enemy position updates per second

-- Sounds ------------------------------------------------------------------------
-- Leave an id empty to skip that sound. To add one, find a sound in Studio's
-- Toolbox (Audio), copy its id, and paste it as "rbxassetid://123456".
Config.SOUNDS = {
	explosion = { id = "rbxasset://sounds/collide.wav", volume = 0.7 },
	rocket = { id = "rbxasset://sounds/Rocket shot.wav", volume = 0.5 },
	unlock = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8 },
	playerDeath = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.7 },
	pistol = { id = "", volume = 0.5 },
	uzi = { id = "", volume = 0.4 },
	shotgun = { id = "", volume = 0.6 },
	railgun = { id = "", volume = 0.6 },
	zombieGroan = { id = "", volume = 0.4 },
	enemyDeath = { id = "", volume = 0.5 },
} :: { [string]: { id: string, volume: number } }

return Config
