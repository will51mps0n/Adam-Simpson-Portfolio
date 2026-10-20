--!strict
-- Thwump: a heavy block with one deadly blue face (option dir, default "left"). When a
-- living ninja is in front of that face and in plain view, it slams that way until it
-- hits something, rests a moment, then slowly returns home. Its other sides are safe to
-- stand on, but it can crush you against a wall.
-- Snapshot: s = 0 home / 1 slamming / 2 resting / 3 returning.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local LevelGrid = require(Shared.LevelGrid)
local LevelObjects = require(Shared.Sim.LevelObjects)
local Collision = require(Shared.Sim.Collision)
local Types = require(script.Parent.Types)

local T = Config.TILE_PX
local HALF = Config.THWUMP_SIZE_PX / 2

local Thwump = {}

local function hitsTiles(grid: LevelGrid.Grid, x: number, y: number): boolean
	for ty = math.floor((y - HALF + 0.01) / T), math.floor((y + HALF - 0.01) / T) do
		for tx = math.floor((x - HALF + 0.01) / T), math.floor((x + HALF - 0.01) / T) do
			if LevelGrid.shapeAt(grid, tx, ty).kind ~= "empty" then
				return true
			end
		end
	end
	return false
end

local function step(e: Types.Enemy, ctx: Types.Ctx)
	local dx, dy = e.dx, e.dy
	if e.s == 0 then
		for _, n in ctx.ninjas do
			local ox, oy = n.x - e.x, n.y - e.y
			local ahead = ox * dx + oy * dy
			local side = math.abs(ox * -dy + oy * dx)
			if ahead > 0 and side < HALF + Config.NINJA_RADIUS then
				local fx, fy = e.x + dx * ahead, e.y + dy * ahead
				if Collision.lineOfSight(ctx.grid, e.x + dx * HALF, e.y + dy * HALF, fx, fy) then
					e.s = 1
					e.v = 0
					break
				end
			end
		end
	elseif e.s == 1 then
		e.v = math.min(e.v + Config.THWUMP_ACCEL * ctx.frames, Config.THWUMP_MAX_SPEED)
		local remaining = e.v * ctx.frames
		while remaining > 0 do
			local move = math.min(remaining, 1)
			if hitsTiles(ctx.grid, e.x + dx * move, e.y + dy * move) then
				e.s = 2
				e.timer = Config.THWUMP_PAUSE
				e.v = 0
				ctx.emit("thud", e.id)
				break
			end
			e.x += dx * move
			e.y += dy * move
			remaining -= move
		end
	elseif e.s == 2 then
		e.timer -= ctx.dt
		if e.timer <= 0 then
			e.s = 3
		end
	else
		local ox, oy = e.homeX - e.x, e.homeY - e.y
		local d = math.sqrt(ox * ox + oy * oy)
		local move = Config.THWUMP_RETURN_SPEED * ctx.frames
		if d <= move then
			e.x, e.y = e.homeX, e.homeY
			e.s = 0
		else
			e.x += ox / d * move
			e.y += oy / d * move
		end
	end
end

function Thwump.new(obj: Levels.ObjectDef, id: number): Types.Enemy
	local x, y = LevelObjects.center(obj)
	local dx, dy = LevelObjects.direction(obj.dir, "left")
	dx, dy = math.sign(math.round(dx)), math.sign(math.round(dy))
	if dx ~= 0 and dy ~= 0 then
		dy = 0 -- thwumps only slam along the grid
	end
	return {
		id = id,
		kind = "thwump",
		x = x,
		y = y,
		a = 0,
		s = 0,
		step = step,
		dx = dx,
		dy = dy,
		homeX = x,
		homeY = y,
		v = 0,
		timer = 0,
	}
end

return Thwump
