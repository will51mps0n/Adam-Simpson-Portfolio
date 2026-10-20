--!strict
-- Floor guard: sits on a stretch of floor. While a ninja stands on that same stretch it
-- races toward them, a little faster than a ninja can run, and never leaves its floor.
-- Snapshot: s = 0 waiting / 1 chasing.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local LevelGrid = require(Shared.LevelGrid)
local LevelObjects = require(Shared.Sim.LevelObjects)
local Types = require(script.Parent.Types)

local T = Config.TILE_PX
local W, H = Config.FLOOR_GUARD_W_PX, Config.FLOOR_GUARD_H_PX

local FloorGuard = {}

local function step(e: Types.Enemy, ctx: Types.Ctx)
	local floorY = e.floorY
	local left, right = e.runLeft, e.runRight
	local target: Types.NinjaInfo? = nil
	local best = math.huge
	for _, n in ctx.ninjas do
		local onFloor = n.grounded and math.abs(n.y + Config.NINJA_RADIUS - floorY) < 4
		if onFloor and n.x > left - Config.NINJA_RADIUS and n.x < right + Config.NINJA_RADIUS then
			local d = math.abs(n.x - e.x)
			if d < best then
				target, best = n, d
			end
		end
	end

	local accel = Config.FLOOR_GUARD_ACCEL * ctx.frames
	if target then
		local want = if target.x > e.x then Config.FLOOR_GUARD_SPEED else -Config.FLOOR_GUARD_SPEED
		e.vx += math.clamp(want - e.vx, -accel, accel)
		e.s = 1
	else
		e.vx -= math.clamp(e.vx, -accel, accel)
		e.s = 0
	end
	e.x += e.vx * ctx.frames
	local minX, maxX = left + W / 2, right - W / 2
	if e.x < minX or e.x > maxX then
		e.x = math.clamp(e.x, minX, maxX)
		e.vx = 0
	end
end

function FloorGuard.new(obj: Levels.ObjectDef, id: number, grid: LevelGrid.Grid): Types.Enemy
	local cx, cy = obj.x, obj.y
	local function floorAt(x: number): boolean
		return LevelGrid.shapeAt(grid, x, cy).kind == "empty" and LevelGrid.shapeAt(grid, x, cy + 1).kind == "full"
	end
	local left, right = cx, cx
	while floorAt(left - 1) do
		left -= 1
	end
	while floorAt(right + 1) do
		right += 1
	end
	local x = LevelObjects.center(obj)
	local floorY = (cy + 1) * T
	return {
		id = id,
		kind = "floorGuard",
		x = x,
		y = floorY - H / 2,
		a = 0,
		s = 0,
		step = step,
		vx = 0,
		floorY = floorY,
		runLeft = left * T,
		runRight = (right + 1) * T,
	}
end

return FloorGuard
