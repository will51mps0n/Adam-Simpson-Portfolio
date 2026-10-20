--!strict
-- Where level objects are and what shape they have, shared by the server (rules) and
-- the clients (drawing and touching). Level files give positions in tiles; everything
-- here is in simulation px (y down).
--
-- Object options used in level files:
--   gold, exitSwitch, exitDoor        exitSwitch/exitDoor: group (default 1) pairs them up
--   door (opens when a ninja is near), lockedDoor, trapDoor
--                                     orient = "v" (a wall you walk into, default) or "h"
--                                     lockedDoor/trapDoor: switch = { x = , y = }
--   launchPad                         dir = "up", "upleft", "right", ... (default "up")
--   bounceBlock
--   oneWay                            dir = side it's solid from: "up" (default) = land on it
--   mine, zapDrone, laserDrone, chaingunDrone, floorGuard, thwump, gaussTurret,
--   rocketTurret                      see src/server/Enemies

local Config = require(script.Parent.Parent.Config)
local Levels = require(script.Parent.Parent.Levels)

local T = Config.TILE_PX
local D = math.sqrt(0.5)

type ObjectDef = Levels.ObjectDef

local LevelObjects = {}

LevelObjects.DIRECTIONS = {
	right = { 1, 0 },
	left = { -1, 0 },
	up = { 0, -1 },
	down = { 0, 1 },
	upright = { D, -D },
	upleft = { -D, -D },
	downright = { D, D },
	downleft = { -D, D },
} :: { [string]: { number } }

function LevelObjects.center(obj: ObjectDef): (number, number)
	return (obj.x + 0.5) * T, (obj.y + 0.5) * T
end

function LevelObjects.direction(name: any, default: string): (number, number)
	local d = LevelObjects.DIRECTIONS[if type(name) == "string" then name else default]
		or LevelObjects.DIRECTIONS[default]
	return d[1], d[2]
end

-- A box centered on the object's tile.
local function centeredBox(obj: ObjectDef, w: number, h: number): (number, number, number, number)
	local cx, cy = LevelObjects.center(obj)
	return cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
end

function LevelObjects.goldBox(obj: ObjectDef): (number, number, number, number)
	local s = Config.GOLD_SIZE_PX
	return centeredBox(obj, s, s)
end

function LevelObjects.exitSwitchBox(obj: ObjectDef): (number, number, number, number)
	return LevelObjects.switchBoxAt(LevelObjects.center(obj))
end

-- The exit door stands on the bottom of its tile.
function LevelObjects.exitDoorBox(obj: ObjectDef): (number, number, number, number)
	local cx, cy = LevelObjects.center(obj)
	local w, h = Config.EXIT_DOOR_W_PX, Config.EXIT_DOOR_H_PX
	return cx - w / 2, cy + T / 2 - h, cx + w / 2, cy + T / 2
end

function LevelObjects.isDoor(obj: ObjectDef): boolean
	return obj.type == "door" or obj.type == "lockedDoor" or obj.type == "trapDoor"
end

-- Doors are a thin wall through the middle of their tile.
function LevelObjects.doorBox(obj: ObjectDef): (number, number, number, number)
	local t = Config.DOOR_THICKNESS_PX
	if obj.orient == "h" then
		return centeredBox(obj, T, t)
	end
	return centeredBox(obj, t, T)
end

-- The middle of a locked door's or trap door's switch, if it has one.
function LevelObjects.doorSwitchCenter(obj: ObjectDef): (number?, number?)
	local sw = obj.switch
	if type(sw) ~= "table" or type(sw.x) ~= "number" or type(sw.y) ~= "number" then
		return nil, nil
	end
	return (sw.x + 0.5) * T, (sw.y + 0.5) * T
end

-- The box of a switch whose middle is (cx, cy).
function LevelObjects.switchBoxAt(cx: number, cy: number): (number, number, number, number)
	local s = Config.SWITCH_SIZE_PX
	return cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2
end

function LevelObjects.group(obj: ObjectDef): any
	return if obj.group ~= nil then obj.group else 1
end

-- A launch pad sits against the surface behind it and fires along `dir`.
-- Returns the middle of the pad and the direction.
function LevelObjects.launchPad(obj: ObjectDef): (number, number, number, number)
	local dx, dy = LevelObjects.direction(obj.dir, "up")
	local cx, cy = LevelObjects.center(obj)
	local back = T / 2 - 2
	return cx - dx * back, cy - dy * back, dx, dy
end

-- One-way platform: a thin slab along one edge of its tile, solid from that side.
-- Returns the box and the normal of its solid face.
function LevelObjects.oneWay(obj: ObjectDef): (number, number, number, number, number, number)
	local dx, dy = LevelObjects.direction(obj.dir, "up")
	local x0, y0 = obj.x * T, obj.y * T
	local x1, y1 = x0 + T, y0 + T
	local t = Config.ONE_WAY_THICKNESS_PX
	if dy < 0 then
		return x0, y0, x1, y0 + t, 0, -1
	elseif dy > 0 then
		return x0, y1 - t, x1, y1, 0, 1
	elseif dx < 0 then
		return x0, y0, x0 + t, y1, -1, 0
	end
	return x1 - t, y0, x1, y1, 1, 0
end

function LevelObjects.bounceBlockBox(obj: ObjectDef): (number, number, number, number)
	local s = Config.BOUNCE_BLOCK_SIZE_PX
	return centeredBox(obj, s, s)
end

function LevelObjects.spawns(def: Levels.LevelDef): { { x: number, y: number } }
	local list = {}
	for _, obj in def.objects do
		if obj.type == "spawn" then
			local x, y = LevelObjects.center(obj)
			table.insert(list, { x = x, y = y })
		end
	end
	if #list == 0 then
		table.insert(list, { x = 2.5 * T, y = 2.5 * T })
	end
	return list
end

-- True if a circle overlaps a box.
function LevelObjects.circleTouchesBox(cx: number, cy: number, r: number, x0: number, y0: number, x1: number, y1: number): boolean
	local nx, ny = math.clamp(cx, x0, x1), math.clamp(cy, y0, y1)
	return (cx - nx) ^ 2 + (cy - ny) ^ 2 < r * r
end

return LevelObjects
