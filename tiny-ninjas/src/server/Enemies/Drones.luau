--!strict
-- The three drones. All patrol the grid with a DroneMover (options: move, dir, path).
--
-- Zap drone: kills on touch. With `seeker = true` it has an antenna: when a ninja is
--   lined up with it in a row or column it beeps and charges that way until it hits a wall.
--   Snapshot: a = heading, s = 0 patrolling / 1 charging.
-- Laser drone: when it sees a ninja it stops, turns red and aims for LASER_AIM_TIME, then
--   fires a beam along that aim for LASER_FIRE_TIME. Snapshot: a = aim, s = 0 patrol,
--   1 aiming, 2 firing, 3 cooling down.
-- Chaingun drone: when it sees a ninja it stops and powers up, then fires a burst of
--   CHAINGUN_BULLETS bullets at it. Snapshot: a = aim, s = 0 patrol, 1 powering up,
--   2 firing, 3 cooling down.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local DroneMover = require(script.Parent.DroneMover)
local Targeting = require(script.Parent.Targeting)
local Types = require(script.Parent.Types)

type Enemy = Types.Enemy
type Ctx = Types.Ctx

local Drones = {}

local function base(obj: Levels.ObjectDef, id: number, kind: string, blocked: DroneMover.Blocked, step: (Enemy, Ctx) -> ()): Enemy
	local mover = DroneMover.new(obj, blocked)
	return {
		id = id,
		kind = kind,
		x = mover.x,
		y = mover.y,
		a = math.atan2(mover.dy, mover.dx),
		s = 0,
		step = step,
		mover = mover,
		timer = 0,
		shots = 0,
		seeker = obj.seeker == true,
	}
end

local function patrol(e: Enemy, ctx: Ctx, speed: number): boolean
	local m: DroneMover.Mover = e.mover
	local arrived = DroneMover.step(m, speed * ctx.frames, ctx.blocked)
	e.x, e.y = m.x, m.y
	return arrived
end

local function stepZap(e: Enemy, ctx: Ctx)
	local m: DroneMover.Mover = e.mover
	local arrived = patrol(e, ctx, if m.charging then Config.ZAP_CHARGE_SPEED else Config.ZAP_SPEED)
	if e.seeker and not m.charging and arrived then
		local target, dx, dy = Targeting.inLine(ctx, e.x, e.y)
		if target and not ctx.blocked(m.cx + dx, m.cy + dy) then
			DroneMover.charge(m, dx, dy)
			e.x, e.y = (m.cx + 0.5) * Config.TILE_PX, (m.cy + 0.5) * Config.TILE_PX
			ctx.emit("beep", e.id)
		end
	end
	e.s = if m.charging then 1 else 0
	if m.dx ~= 0 or m.dy ~= 0 then
		e.a = math.atan2(m.dy, m.dx)
	end
end

local function stepLaser(e: Enemy, ctx: Ctx)
	if e.s == 0 or e.s == 3 then
		patrol(e, ctx, Config.ZAP_SPEED)
		if e.s == 3 then
			e.timer -= ctx.dt
			if e.timer <= 0 then
				e.s = 0
			end
		end
		if e.s == 0 then
			local target = Targeting.nearestVisible(ctx, e.x, e.y)
			if target then
				e.s = 1
				e.timer = Config.LASER_AIM_TIME
				e.a = Targeting.angleTo(e.x, e.y, target)
			end
		end
	elseif e.s == 1 then
		local target = Targeting.nearestVisible(ctx, e.x, e.y)
		if target then
			e.a = Targeting.angleTo(e.x, e.y, target)
		end
		e.timer -= ctx.dt
		if e.timer <= 0 then
			e.s = 2
			e.timer = Config.LASER_FIRE_TIME
		end
	else
		e.timer -= ctx.dt
		if e.timer <= 0 then
			e.s = 3
			e.timer = Config.LASER_COOLDOWN
		end
	end
end

local function stepChaingun(e: Enemy, ctx: Ctx)
	if e.s == 0 or e.s == 3 then
		patrol(e, ctx, Config.ZAP_SPEED)
		if e.s == 3 then
			e.timer -= ctx.dt
			if e.timer <= 0 then
				e.s = 0
			end
		end
		if e.s == 0 then
			local target = Targeting.nearestVisible(ctx, e.x, e.y)
			if target then
				e.s = 1
				e.timer = Config.CHAINGUN_POWER_UP_TIME
				e.a = Targeting.angleTo(e.x, e.y, target)
			end
		end
		return
	end
	local target = Targeting.nearestVisible(ctx, e.x, e.y)
	if target then
		e.a = Targeting.angleTo(e.x, e.y, target)
	end
	e.timer -= ctx.dt
	if e.s == 1 then
		if e.timer <= 0 then
			e.s = 2
			e.shots = 0
		end
		return
	end
	while e.timer <= 0 and e.shots < Config.CHAINGUN_BULLETS do
		local dx, dy = math.cos(e.a), math.sin(e.a)
		local start = Config.DRONE_RADIUS_PX + 1
		local speed = Config.BULLET_SPEED
		ctx.emit("bullet", ctx.now, e.x + dx * start, e.y + dy * start, dx * speed, dy * speed)
		e.shots += 1
		e.timer += Config.CHAINGUN_INTERVAL
	end
	if e.shots >= Config.CHAINGUN_BULLETS then
		e.s = 3
		e.timer = Config.CHAINGUN_COOLDOWN
	end
end

function Drones.zap(obj: Levels.ObjectDef, id: number, blocked: DroneMover.Blocked): Enemy
	return base(obj, id, "zapDrone", blocked, stepZap)
end

function Drones.laser(obj: Levels.ObjectDef, id: number, blocked: DroneMover.Blocked): Enemy
	return base(obj, id, "laserDrone", blocked, stepLaser)
end

function Drones.chaingun(obj: Levels.ObjectDef, id: number, blocked: DroneMover.Blocked): Enemy
	return base(obj, id, "chaingunDrone", blocked, stepChaingun)
end

return Drones
