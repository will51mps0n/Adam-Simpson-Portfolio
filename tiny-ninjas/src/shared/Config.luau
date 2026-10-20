--!strict
-- Every number you might want to tune lives in this file.
-- Movement values use the original game's units: pixels and frames at 60 frames per second.

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
-- Ninja movement (used from milestone 2), per frame at 60 Hz, in pixels
--------------------------------------------------------------------------------

Config.PHYSICS_HZ = 60
Config.NINJA_RADIUS = 10

Config.GRAVITY_FALL = 0.0667
Config.GRAVITY_JUMP_HELD = 0.0111
Config.MAX_JUMP_FRAMES = 45
Config.GROUND_ACCEL = 0.0667
Config.AIR_ACCEL = 0.0444
Config.MAX_X_SPEED = 3.333
Config.GROUND_FRICTION = 0.9459
Config.WALL_FRICTION = 0.9113 -- wall slide
Config.AIR_DRAG = 0.9933
Config.JUMP_VELOCITY = 2.0 -- upward
Config.WALL_JUMP_X = 1.0 -- away from the wall
Config.WALL_JUMP_Y = 1.4 -- upward
Config.MAX_SURVIVABLE_IMPACT = 6.0

--------------------------------------------------------------------------------
-- Episodes
--------------------------------------------------------------------------------

Config.TIME_START = 90 -- seconds on the time bar when an episode starts
Config.GOLD_TIME = 2 -- seconds added per gold

return Config
