--!strict
-- Wall turrets and rockets.
--
-- Gauss turret: its aim follows you, but GAUSS_AIM_DELAY seconds late. When it's ready
--   it flashes for GAUSS_WARN_TIME, then fires an instant shot along its aim to the first
--   wall. Snapshot: a = aim, s = 0 tracking / 1 about to fire.
-- Rocket turret: whenever it can see you and has reloaded, it fires a homing rocket.
--   Snapshot: a = aim.
-- Rockets turn toward the nearest living ninja (a little at a time) until they hit
--   something and explode. Snapshot: a = heading.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local LevelObjects = require(Shared.Sim.LevelObjects)
local Collision = require(Shared.Sim.Collision)
local Targeting = require(script.Parent.Targeting)
local Types = require(script.Parent.Types)

type Enemy = Types.Enemy
type Ctx = Types.Ctx

export type Rocket = {
	id: number,
	x: number,
	y: number,
	a: number,
	age: number,
}

local Turrets = {}

local function stepGauss(e: Enemy, ctx: Ctx)
	e.cooldown -= ctx.dt
	local history: { { t: number, x: number, y: number } } = e.history
	local target = Targeting.nearestVisible(ctx, e.x, e.y)
	if target then
		table.insert(history, { t = ctx.now, x = target.x, y = target.y })
	elseif e.s == 0 then
		table.clear(history) -- lost sight: start over
	end
	while #history > 2 and history[2].t < ctx.now - Config.GAUSS_AIM_DELAY do
		table.remove(history, 1)
	end

	-- Aim where the target was GAUSS_AIM_DELAY seconds ago.
	local wanted = ctx.now - Config.GAUSS_AIM_DELAY
	local ready = #history >= 2 and history[1].t <= wanted
	if ready then
		local a, b = history[1], history[2]
		local f = if b.t > a.t then math.clamp((wanted - a.t) / (b.t - a.t), 0, 1) else 0
		local ax, ay = a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f
		e.a = math.atan2(ay - e.y, ax - e.x)
	end

	if e.s == 0 then
		if ready and e.cooldown <= 0 then
			e.s = 1
			e.timer = Config.GAUSS_WARN_TIME
		end
	else
		e.timer -= ctx.dt
		if e.timer <= 0 then
			local dx, dy = math.cos(e.a), math.sin(e.a)
			local range = Config.LASER_RANGE_PX * 2
			local x1, y1 = e.x + dx * range, e.y + dy * range
			local hit = Collision.raycast(ctx.grid, e.x, e.y, x1, y1)
			if hit then
				x1, y1 = e.x + dx * range * hit, e.y + dy * range * hit
			end
			ctx.emit("gauss", ctx.now, e.x, e.y, x1, y1)
			e.s = 0
			e.cooldown = Config.GAUSS_COOLDOWN
		end
	end
end

local function stepRocketTurret(e: Enemy, ctx: Ctx)
	e.cooldown -= ctx.dt
	local target = Targeting.nearestVisible(ctx, e.x, e.y)
	if target then
		e.a = Targeting.angleTo(e.x, e.y, target)
		if e.cooldown <= 0 then
			local start = Config.TURRET_RADIUS_PX + Config.ROCKET_RADIUS_PX + 1
			ctx.spawnRocket(e.x + math.cos(e.a) * start, e.y + math.sin(e.a) * start, e.a)
			e.cooldown = Config.ROCKET_COOLDOWN
		end
	end
end

local function turret(obj: Levels.ObjectDef, id: number, kind: string, step: (Enemy, Ctx) -> ()): Enemy
	local x, y = LevelObjects.center(obj)
	return {
		id = id,
		kind = kind,
		x = x,
		y = y,
		a = 0,
		s = 0,
		step = step,
		cooldown = 0.5,
		timer = 0,
		history = {},
	}
end

function Turrets.gauss(obj: Levels.ObjectDef, id: number): Enemy
	return turret(obj, id, "gaussTurret", stepGauss)
end

function Turrets.rocket(obj: Levels.ObjectDef, id: number): Enemy
	return turret(obj, id, "rocketTurret", stepRocketTurret)
end

local function wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- Moves a rocket for one tick. Returns true if it exploded (it then emits the explosion).
function Turrets.stepRocket(r: Rocket, ctx: Ctx): boolean
	r.age += ctx.dt
	if r.age > Config.ROCKET_LIFETIME then
		ctx.emit("explosion", ctx.now, r.x, r.y, r.id)
		return true
	end
	local target = Targeting.nearest(ctx, r.x, r.y)
	if target then
		local turn = Config.ROCKET_TURN * ctx.frames
		r.a += math.clamp(wrapAngle(Targeting.angleTo(r.x, r.y, target) - r.a), -turn, turn)
	end
	local remaining = Config.ROCKET_SPEED * ctx.frames
	local dx, dy = math.cos(r.a), math.sin(r.a)
	while remaining > 0 do
		local move = math.min(remaining, 3)
		r.x += dx * move
		r.y += dy * move
		remaining -= move
		if Collision.pointInTiles(ctx.grid, r.x, r.y) then
			ctx.emit("explosion", ctx.now, r.x, r.y, r.id)
			return true
		end
	end
	return false
end

return Turrets
