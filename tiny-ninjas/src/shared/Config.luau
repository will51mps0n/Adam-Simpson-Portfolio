--!strict
-- Every number you might want to tune lives in this file.
-- Movement values use the original game's units: pixels (px) and frames at 60 frames per
-- second. "per frame" speeds are px per 1/60 s; enemy timings are in seconds.

local Config = {}

Config.GAME_NAME = "Tiny Ninjas"

--------------------------------------------------------------------------------
-- World scale
--------------------------------------------------------------------------------

Config.TILE_PX = 24 -- one tile is 24 px wide
Config.STUDS_PER_PX = 0.125 -- 1 px = 0.125 studs, so one tile = 3 studs
Config.LEVEL_GRID_W = 31 -- a normal one-screen level is 31 x 23 tiles
Config.LEVEL_GRID_H = 23
Config.WORLD_TOP_Y = 300 -- height (studs) of a level's top edge, keeps levels well above the void
Config.TILE_DEPTH_STUDS = 3 -- how far blocks reach into the screen (never seen head-on)
Config.CURVE_SEGMENTS = 8 -- straight pieces used to draw each quarter circle
Config.SEAM_OVERLAP_STUDS = 0.01 -- tiny overlap between pieces so no hairline gaps show

--------------------------------------------------------------------------------
-- Look
--------------------------------------------------------------------------------

Config.COLORS = {
	BACKGROUND = Color3.fromHex("#C9C9C9"), -- empty space inside a level
	TILE = Color3.fromHex("#7A7A7A"), -- solid blocks, slopes and curves
	VOID = Color3.fromHex("#7A7A7A"), -- everything outside the level

	NINJA = Color3.fromHex("#111111"),
	HEADBAND = Color3.fromHex("#D93A3A"),

	GOLD = Color3.fromHex("#E9C23B"),
	GOLD_EDGE = Color3.fromHex("#A8851C"),
	EXIT_DOOR = Color3.fromHex("#3B3B3B"),
	EXIT_DOOR_OPEN = Color3.fromHex("#F4E7A6"),
	EXIT_SWITCH = Color3.fromHex("#E04848"),
	EXIT_SWITCH_ON = Color3.fromHex("#4FCB6B"),
	SWITCH_BASE = Color3.fromHex("#3B3B3B"),
	DOOR = Color3.fromHex("#4E4E4E"),
	LOCKED_DOOR = Color3.fromHex("#3F6FB5"), -- locked doors and their switches
	TRAP_DOOR = Color3.fromHex("#8A4FB5"), -- trap doors and their switches
	LAUNCH_PAD = Color3.fromHex("#F08A24"),
	BOUNCE_BLOCK = Color3.fromHex("#A3A3A3"),
	BOUNCE_BLOCK_EDGE = Color3.fromHex("#5C5C5C"),
	ONE_WAY = Color3.fromHex("#9A9A9A"),

	MINE = Color3.fromHex("#262626"),
	MINE_CORE = Color3.fromHex("#E23232"),
	ZAP_DRONE = Color3.fromHex("#2E7BE6"),
	LASER_DRONE = Color3.fromHex("#E8E8E8"),
	LASER = Color3.fromHex("#FF2B2B"),
	CHAINGUN_DRONE = Color3.fromHex("#6B6B6B"),
	BULLET = Color3.fromHex("#FFB000"),
	FLOOR_GUARD = Color3.fromHex("#3E9B4C"),
	THWUMP = Color3.fromHex("#6E6E6E"),
	THWUMP_FACE = Color3.fromHex("#2F8CFF"),
	GAUSS_TURRET = Color3.fromHex("#4B3A6B"),
	GAUSS_SHOT = Color3.fromHex("#9FF3FF"),
	ROCKET_TURRET = Color3.fromHex("#5A3A22"),
	ROCKET = Color3.fromHex("#FF7A1A"),
	EXPLOSION = Color3.fromHex("#FF9A2E"),
	EYE = Color3.fromHex("#FFFFFF"),
	PUPIL = Color3.fromHex("#111111"),
}

-- Flat, shadowless lighting so colors look exactly as written above.
Config.LIGHTING = {
	Ambient = Color3.new(1, 1, 1),
	OutdoorAmbient = Color3.new(1, 1, 1),
	Brightness = 0,
	EnvironmentDiffuseScale = 0,
	EnvironmentSpecularScale = 0,
	ExposureCompensation = 0,
	GlobalShadows = false,
}

--------------------------------------------------------------------------------
-- Camera
--------------------------------------------------------------------------------

Config.CAMERA_FOV = 12 -- degrees; a narrow view from far away looks flat
Config.CAMERA_PADDING_PX = 12 -- empty screen pixels kept around the level
Config.CAMERA_HUD_TOP_PX = 30 -- room kept at the top of the screen for the time bar

-- Follow camera, used for levels bigger than one screen
Config.FOLLOW_MARGIN_TILES = 5 -- space kept around the outermost players
Config.FOLLOW_MIN_VIEW_TILES = 18 -- never zoom in closer than this many tiles tall
Config.FOLLOW_SMOOTHING = 5 -- how quickly the camera catches up (higher = snappier)

--------------------------------------------------------------------------------
-- Ninja movement, per frame at 60 Hz, in pixels
--------------------------------------------------------------------------------

Config.PHYSICS_HZ = 60
Config.NINJA_RADIUS = 10

Config.GRAVITY_FALL = 0.0667
Config.GRAVITY_JUMP_HELD = 0.0111 -- gravity while jump is held, for up to MAX_JUMP_FRAMES
Config.MAX_JUMP_FRAMES = 45
Config.GROUND_ACCEL = 0.0667
Config.AIR_ACCEL = 0.0444
Config.MAX_X_SPEED = 3.333 -- running can't go faster; slopes and launch pads can
Config.GROUND_FRICTION = 0.9459 -- speed kept per frame when you stop pushing on the ground
Config.STOP_SPEED = 0.1 -- below this the ninja stands still (and doesn't slide down slopes)
Config.WALL_FRICTION = 0.9113 -- falling speed kept per frame while sliding down a wall
Config.AIR_DRAG = 0.9933 -- speed kept per frame (always, both directions)

Config.JUMP_VELOCITY = 2.0 -- upward kick of a jump from flat ground
Config.SLOPE_JUMP_NORMAL_X = 2 / 3 -- slope jump: this much of the slope's outward direction sideways
Config.SLOPE_JUMP_NORMAL_Y = 2.0 -- ...and this much upward (so slope jumps go perpendicular-ish)
Config.SLOPE_JUMP_UPHILL = 1.4 -- running uphill and jumping forward: a straight-up kick this strong
Config.WALL_JUMP_X = 1.0 -- away from the wall
Config.WALL_JUMP_Y = 1.4 -- upward
Config.WALL_SLIDE_JUMP_X = 2 / 3 -- jump while sliding AND still pressing into the wall: a small hop
Config.WALL_SLIDE_JUMP_Y = 1.0
Config.JUMP_BUFFER_FRAMES = 5 -- a jump pressed this many frames before landing still counts
Config.COYOTE_FRAMES = 4 -- you can still jump this many frames after leaving a floor or wall

-- Landing (or hitting a ceiling) faster than this along the surface's normal kills.
-- Flat floors and ceilings are harsher: the limit drops by IMPACT_FLAT_PENALTY on them,
-- so landing on a slope that matches your fall is safer than landing flat.
Config.MAX_SURVIVABLE_IMPACT = 6.0
Config.IMPACT_FLAT_PENALTY = 4 / 3
Config.CRUSH_DEPTH_PX = 4 -- squeezed this deep into solid things = crushed

Config.RESPAWN_DELAY = 1.0 -- seconds after dying before the level restarts by itself

--------------------------------------------------------------------------------
-- Ninja look and animation
--------------------------------------------------------------------------------

Config.LIMB_THICKNESS_PX = 1.7
Config.HEAD_RADIUS_PX = 2.7
Config.HEADBAND_TAIL_PX = 4 -- length of each of the two pieces of a headband tail
Config.LANDING_CROUCH_FRAMES = 9
Config.WALL_JUMP_SPIN_FRAMES = 18

--------------------------------------------------------------------------------
-- Ragdoll
--------------------------------------------------------------------------------

Config.RAGDOLL_GRAVITY = 0.0667
Config.RAGDOLL_DRAG = 0.995
Config.RAGDOLL_BOUNCE = 0.35 -- how much speed into a surface bounces back
Config.RAGDOLL_FRICTION = 0.8 -- speed along a surface kept on each touch
Config.RAGDOLL_LIMIT = 8 -- older ragdolls disappear past this many
Config.EXPLOSION_PUSH = 7 -- px per frame thrown outward by an explosion
Config.EXPLOSION_SPLIT_CHANCE = 0.35 -- chance each joint tears apart in an explosion

--------------------------------------------------------------------------------
-- Level objects
--------------------------------------------------------------------------------

Config.TIME_START = 90 -- seconds on the time bar when an episode starts
Config.GOLD_TIME = 2 -- seconds added per gold
Config.GOLD_SIZE_PX = 6
Config.SWITCH_SIZE_PX = 8
Config.EXIT_DOOR_W_PX = 18
Config.EXIT_DOOR_H_PX = 24
Config.DOOR_THICKNESS_PX = 6
Config.DOOR_OPEN_DISTANCE_PX = 26 -- a normal door opens while a ninja's center is this close
Config.LAUNCH_PAD_SPEED = 5.2 -- px per frame, in the pad's direction
Config.LAUNCH_PAD_REACH_PX = 16 -- how far above the pad it still catches you
Config.BOUNCE_BLOCK_SIZE_PX = 18
Config.BOUNCE_STIFFNESS = 0.06 -- spring pulling a squashed bounce block back
Config.BOUNCE_DAMPING = 0.9
Config.BOUNCE_MAX_SQUASH_PX = 8
Config.ONE_WAY_THICKNESS_PX = 4

--------------------------------------------------------------------------------
-- Enemies (speeds in px per frame at 60 Hz, times in seconds)
--------------------------------------------------------------------------------

Config.ENEMY_HZ = 30 -- the server moves enemies this many times a second
Config.INTERP_DELAY = 0.1 -- enemies are drawn this far in the past so motion stays smooth online

Config.MINE_RADIUS_PX = 4
Config.EXPLOSION_RADIUS_PX = 22

Config.DRONE_RADIUS_PX = 8
Config.ZAP_SPEED = 1.0
Config.ZAP_CHARGE_SPEED = 2.6 -- seeker drones charge this fast once they see you in line
Config.LASER_AIM_TIME = 0.5
Config.LASER_FIRE_TIME = 0.3
Config.LASER_COOLDOWN = 1.2
Config.LASER_RANGE_PX = 700
Config.CHAINGUN_POWER_UP_TIME = 0.6
Config.CHAINGUN_BULLETS = 10
Config.CHAINGUN_INTERVAL = 0.09
Config.CHAINGUN_COOLDOWN = 1.6
Config.BULLET_SPEED = 4.5
Config.BULLET_RADIUS_PX = 1.5

Config.FLOOR_GUARD_W_PX = 12
Config.FLOOR_GUARD_H_PX = 10
Config.FLOOR_GUARD_SPEED = Config.MAX_X_SPEED * 1.1
Config.FLOOR_GUARD_ACCEL = 0.2

Config.THWUMP_SIZE_PX = 18
Config.THWUMP_ACCEL = 0.4
Config.THWUMP_MAX_SPEED = 6
Config.THWUMP_RETURN_SPEED = 0.6
Config.THWUMP_PAUSE = 0.35 -- rest after slamming before heading home

Config.TURRET_RADIUS_PX = 6
Config.GAUSS_AIM_DELAY = 1.0 -- the gauss turret aims where you were this long ago
Config.GAUSS_COOLDOWN = 1.6
Config.GAUSS_WARN_TIME = 0.35 -- flashes this long before firing
Config.ROCKET_COOLDOWN = 2.5
Config.ROCKET_SPEED = 2.2
Config.ROCKET_TURN = 0.045 -- radians per frame a rocket can turn toward its target
Config.ROCKET_LIFETIME = 8
Config.ROCKET_RADIUS_PX = 3

Config.SIGHT_RANGE_PX = 900 -- enemies can't see ninjas farther than this

--------------------------------------------------------------------------------
-- Testing helpers
--------------------------------------------------------------------------------

Config.DEV_LEVEL_KEYS = true -- number keys switch between the test levels

return Config
