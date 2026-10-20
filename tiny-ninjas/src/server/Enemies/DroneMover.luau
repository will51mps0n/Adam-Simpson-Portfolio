--!strict
-- How drones get around: from tile center to tile center along the grid, like the
-- original game's drones.
--
-- Movement modes (the level object's `move` option):
--   "cw"      follow walls clockwise around a room (keeps the wall on its left)
--   "ccw"     follow walls counter-clockwise (keeps the wall on its right)
--   "bounce"  go straight, turn around at walls
--   "path"    visit the tiles in `path` = { { x = , y = }, ... } in a loop, in straight lines
--   "still"   stay put
-- `dir` gives the starting direction (default "right").
-- Seeker drones can also `charge`: rush straight ahead until they hit a wall.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local LevelObjects = require(Shared.Sim.LevelObjects)

local T = Config.TILE_PX

export type Blocked = (cx: number, cy: number) -> boolean

export type Mover = {
	mode: string,
	cx: number, -- the tile being left
	cy: number,
	dx: number, -- grid direction toward the next tile
	dy: number,
	progress: number, -- px traveled from the current tile's center toward the next one
	x: number,
	y: number,
	path: { { x: number, y: number } }?,
	pathIndex: number,
	charging: boolean,
}

local DroneMover = {}

local function gridDirection(name: any): (number, number)
	local dx, dy = LevelObjects.direction(name, "right")
	return math.sign(math.round(dx)), math.sign(math.round(dy))
end

-- The next direction to take on arriving at a tile center.
local function choose(m: Mover, blocked: Blocked): (number, number)
	local dx, dy = m.dx, m.dy
	if m.charging then
		if not blocked(m.cx + dx, m.cy + dy) then
			return dx, dy
		end
		m.charging = false -- hit a wall: back to patrolling
	end
	local left, right = { dy, -dx }, { -dy, dx }
	local straight, back = { dx, dy }, { -dx, -dy }
	local options
	if m.mode == "cw" then
		options = { left, straight, right, back }
	elseif m.mode == "ccw" then
		options = { right, straight, left, back }
	elseif m.mode == "bounce" then
		options = { straight, back }
	else
		return 0, 0
	end
	for _, o in options do
		if (o[1] ~= 0 or o[2] ~= 0) and not blocked(m.cx + o[1], m.cy + o[2]) then
			return o[1], o[2]
		end
	end
	return 0, 0
end

function DroneMover.new(obj: Levels.ObjectDef, blocked: Blocked): Mover
	local mode = if type(obj.move) == "string" then obj.move else "cw"
	local dx, dy = gridDirection(obj.dir)
	local x, y = LevelObjects.center(obj)
	local m: Mover = {
		mode = mode,
		cx = obj.x,
		cy = obj.y,
		dx = dx,
		dy = dy,
		progress = 0,
		x = x,
		y = y,
		path = nil,
		pathIndex = 1,
		charging = false,
	}
	if mode == "path" and type(obj.path) == "table" and #obj.path > 0 then
		m.path = obj.path
	elseif mode ~= "path" and mode ~= "still" and blocked(m.cx + dx, m.cy + dy) then
		m.dx, m.dy = choose(m, blocked)
	end
	return m
end

-- Moves `dist` px. Returns true if the drone passed through a tile center.
function DroneMover.step(m: Mover, dist: number, blocked: Blocked): boolean
	local path = m.path
	if path then
		-- Straight lines between waypoints.
		for _ = 1, #path + 1 do
			if dist <= 0 then
				break
			end
			local wp = path[m.pathIndex]
			local tx, ty = (wp.x + 0.5) * T, (wp.y + 0.5) * T
			local ox, oy = tx - m.x, ty - m.y
			local d = math.sqrt(ox * ox + oy * oy)
			if d <= dist then
				m.x, m.y = tx, ty
				dist -= d
				m.pathIndex = m.pathIndex % #path + 1
			else
				m.x += ox / d * dist
				m.y += oy / d * dist
				m.dx, m.dy = ox / d, oy / d
				dist = 0
			end
		end
		return false
	end

	if m.dx == 0 and m.dy == 0 then
		m.dx, m.dy = choose(m, blocked)
		if m.dx == 0 and m.dy == 0 then
			return false
		end
	end
	local arrived = false
	m.progress += dist
	while m.progress >= T do
		m.progress -= T
		m.cx += m.dx
		m.cy += m.dy
		arrived = true
		m.dx, m.dy = choose(m, blocked)
		if m.dx == 0 and m.dy == 0 then
			m.progress = 0
			break
		end
	end
	m.x = (m.cx + 0.5) * T + m.dx * m.progress
	m.y = (m.cy + 0.5) * T + m.dy * m.progress
	return arrived
end

-- Start rushing in grid direction (dx, dy). Only call this at a tile center.
function DroneMover.charge(m: Mover, dx: number, dy: number)
	m.dx, m.dy = dx, dy
	m.progress = 0
	m.charging = true
end

return DroneMover
