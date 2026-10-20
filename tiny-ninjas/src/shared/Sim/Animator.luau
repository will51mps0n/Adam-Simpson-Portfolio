--!strict
-- Procedural animation: turns the ninja's movement state into a stick-figure pose.
-- A target pose is built in the ninja's own frame (x forward, y up, origin at the
-- collision circle's center), eased toward every frame, then flipped to face the right
-- way. Arms and legs use two-bone IK so hands and feet land exactly where they should.
-- The headband tails follow behind the head with a little lag.

local Config = require(script.Parent.Parent.Config)
local Rig = require(script.Parent.Rig)

-- What the animator needs to know about a ninja (a NinjaSim.Ninja has all of these).
export type View = {
	x: number,
	y: number,
	vx: number,
	vy: number,
	state: string,
	facing: number,
	h: number,
	onFloor: boolean,
	wallNormal: number,
	landFrames: number,
	landSpeed: number,
	spinFrames: number,
	spinDir: number,
}

type P = Rig.Point

export type Animator = {
	smoothed: { [string]: P }, -- local pose, eased
	runPhase: number,
	time: number,
	drawFacing: number,
	pose: Rig.Pose, -- the output, in simulation px
	tailsReady: boolean,
}

local Animator = {}

local MAX = Config.MAX_X_SPEED
local HEAD_GAP = Rig.NECK -- head center sits this far beyond the neck

function Animator.new(): Animator
	return {
		smoothed = {},
		runPhase = 0,
		time = 0,
		drawFacing = 1,
		pose = Rig.newPose(0, 0),
		tailsReady = false,
	}
end

-- Two-bone IK: where the middle joint goes for a limb from (ax, ay) reaching for (tx, ty).
-- bend = 1 bends toward +x when the limb points down (knees), -1 the other way (elbows).
local function ik(ax: number, ay: number, tx: number, ty: number, l1: number, l2: number, bend: number): (number, number, number, number)
	local dx, dy = tx - ax, ty - ay
	local d = math.sqrt(dx * dx + dy * dy)
	if d < 1e-6 then
		dx, dy, d = 0, -1, 1e-6
	end
	local ux, uy = dx / d, dy / d
	local reach = l1 + l2 - 0.01
	if d > reach then
		d = reach
		tx, ty = ax + ux * d, ay + uy * d
	end
	d = math.max(d, math.abs(l1 - l2) + 0.01)
	local along = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
	local out = math.sqrt(math.max(0, l1 * l1 - along * along)) * bend
	return ax + ux * along - uy * out, ay + uy * along + ux * out, tx, ty
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

type Targets = {
	lean: number, -- torso tilt forward, radians
	hipY: number,
	hipX: number,
	handL: P,
	handR: P,
	footL: P,
	footR: P,
}

local function idle(t: number): Targets
	local breathe = math.sin(t * 2.2) * 0.15
	return {
		lean = 0.05,
		hipX = 0,
		hipY = -1.0 + breathe * 0.5,
		handL = { x = -1.6, y = -2.2 + breathe },
		handR = { x = 2.2, y = -1.9 + breathe },
		footL = { x = -1.9, y = -10 },
		footR = { x = 1.8, y = -10 },
	}
end

local function run(phase: number, speed: number): Targets
	local s = math.clamp(speed / MAX, 0, 1.4)
	local a, b = phase, phase + math.pi
	local stride, lift = 4.8 * s, 3.6 * s
	return {
		lean = 0.12 + 0.22 * s,
		hipX = 0.3 * s,
		hipY = -0.8 - math.abs(math.sin(phase)) * 0.8 * s,
		handL = { x = -math.sin(a) * 5.2 * s + 1.0, y = -1.0 + math.cos(a) * 1.6 * s },
		handR = { x = -math.sin(b) * 5.2 * s + 1.0, y = -1.0 + math.cos(b) * 1.6 * s },
		footL = { x = math.sin(a) * stride + 0.5, y = -10 + math.max(0, math.cos(a)) * lift },
		footR = { x = math.sin(b) * stride + 0.5, y = -10 + math.max(0, math.cos(b)) * lift },
	}
end

local function skid(): Targets
	return {
		lean = -0.3,
		hipX = -0.6,
		hipY = -1.8,
		handL = { x = -4.5, y = 2.5 },
		handR = { x = -2.5, y = 4.5 },
		footL = { x = 3.0, y = -10 },
		footR = { x = 5.4, y = -9.6 },
	}
end

local function air(vy: number): Targets
	-- Rising: knees tucked, arms up. Falling: legs dangle and arms go out to the sides.
	local f = math.clamp((vy + 0.6) / 1.2, 0, 1)
	return {
		lean = lerp(0.12, 0.0, f),
		hipX = 0,
		hipY = -1.0,
		handL = { x = lerp(-3.4, -7.0, f), y = lerp(3.2, 6.2, f) },
		handR = { x = lerp(4.0, 6.8, f), y = lerp(6.4, 6.8, f) },
		footL = { x = lerp(-1.2, -2.4, f), y = lerp(-7.6, -10.4, f) },
		footR = { x = lerp(3.0, 2.5, f), y = lerp(-6.4, -9.8, f) },
	}
end

local function wallSlide(): Targets
	-- Facing the wall: a hand and a foot pressed against it, leaning back a little.
	return {
		lean = -0.18,
		hipX = -0.6,
		hipY = -0.9,
		handL = { x = 4.6, y = -1.2 },
		handR = { x = 9.4, y = 2.6 },
		footL = { x = 3.0, y = -9.4 },
		footR = { x = 8.9, y = -6.0 },
	}
end

local function targetsFor(anim: Animator, v: View): Targets
	if v.state == "wall" then
		return wallSlide()
	elseif v.onFloor then
		local speed = math.abs(v.vx)
		if v.h ~= 0 and v.h * v.vx < 0 and speed > 0.6 then
			return skid()
		elseif speed > 0.15 then
			return run(anim.runPhase, speed)
		end
		return idle(anim.time)
	end
	return air(v.vy)
end

local LOCAL_JOINTS = { "hip", "neck", "head", "elbowL", "handL", "elbowR", "handR", "kneeL", "footL", "kneeR", "footR" }

-- Builds this frame's pose for `v`, `dt` seconds after the last one. Returns anim.pose.
function Animator.update(anim: Animator, v: View, dt: number): Rig.Pose
	anim.time += dt
	local frames = dt * 60
	if v.onFloor then
		anim.runPhase += math.abs(v.vx) * 0.13 * frames
	end

	if v.state == "wall" then
		anim.drawFacing = -v.wallNormal
	elseif v.onFloor and math.abs(v.vx) > 0.5 then
		anim.drawFacing = if v.vx > 0 then 1 else -1
	elseif v.h ~= 0 then
		anim.drawFacing = v.h
	end

	local t = targetsFor(anim, v)

	-- Landing crouch: dip down for a few frames, more after a harder landing.
	if v.onFloor and v.landFrames < Config.LANDING_CROUCH_FRAMES then
		local c = (1 - v.landFrames / Config.LANDING_CROUCH_FRAMES) * math.min(1, 0.35 + v.landSpeed / 3)
		t.hipY -= c * 3.4
		t.lean += c * 0.35
		t.handL.y -= c * 2
		t.handR.y -= c * 2
	end

	-- Torso and head from the hip and lean; then IK for the limbs.
	local hipX, hipY = t.hipX, t.hipY
	local neckX, neckY = hipX + math.sin(t.lean) * Rig.TORSO, hipY + math.cos(t.lean) * Rig.TORSO
	local headLean = t.lean * 0.6
	local headX, headY = neckX + math.sin(headLean) * HEAD_GAP, neckY + math.cos(headLean) * HEAD_GAP

	local target: { [string]: P } = {
		hip = { x = hipX, y = hipY },
		neck = { x = neckX, y = neckY },
		head = { x = headX, y = headY },
	}
	local ex, ey, hx, hy = ik(neckX, neckY, t.handL.x, t.handL.y, Rig.UPPER_ARM, Rig.LOWER_ARM, -1)
	target.elbowL, target.handL = { x = ex, y = ey }, { x = hx, y = hy }
	ex, ey, hx, hy = ik(neckX, neckY, t.handR.x, t.handR.y, Rig.UPPER_ARM, Rig.LOWER_ARM, -1)
	target.elbowR, target.handR = { x = ex, y = ey }, { x = hx, y = hy }
	local kx, ky, fx, fy = ik(hipX, hipY, t.footL.x, t.footL.y, Rig.UPPER_LEG, Rig.LOWER_LEG, 1)
	target.kneeL, target.footL = { x = kx, y = ky }, { x = fx, y = fy }
	kx, ky, fx, fy = ik(hipX, hipY, t.footR.x, t.footR.y, Rig.UPPER_LEG, Rig.LOWER_LEG, 1)
	target.kneeR, target.footR = { x = kx, y = ky }, { x = fx, y = fy }

	-- Ease toward the target so changes of state blend instead of snapping.
	local ease = 1 - math.exp(-dt * 22)
	local smoothed = anim.smoothed
	for _, name in LOCAL_JOINTS do
		local goal = target[name]
		local cur = smoothed[name]
		if cur then
			cur.x = lerp(cur.x, goal.x, ease)
			cur.y = lerp(cur.y, goal.y, ease)
		else
			smoothed[name] = { x = goal.x, y = goal.y }
		end
	end

	-- Wall-jump spin: a quick forward flip around the body's center.
	local spin = 0
	if v.spinFrames > 0 then
		spin = -2 * math.pi * (1 - v.spinFrames / Config.WALL_JUMP_SPIN_FRAMES)
	end
	local cs, sn = math.cos(spin), math.sin(spin)

	-- Into simulation pixels: flip x to the facing direction, flip y (pixels grow downward).
	local facing = anim.drawFacing
	local pose = anim.pose
	for _, name in LOCAL_JOINTS do
		local p = smoothed[name]
		local lx, ly = p.x * cs - p.y * sn, p.x * sn + p.y * cs
		local out = pose[name]
		out.x = v.x + lx * facing
		out.y = v.y - ly
	end

	-- Headband tails: trail behind the head, swept back by motion, drooping a little.
	local head = pose.head
	local bx, by = -facing * 1.0 - v.vx * 0.4, 0.3 - v.vy * 0.4
	local blen = math.sqrt(bx * bx + by * by)
	bx, by = bx / blen, by / blen
	local follow = 1 - (1 - 0.45) ^ frames
	-- Drags `to` toward its resting spot behind `from`, keeping the piece's length.
	local function pull(from: P, to: P, k: number, length: number, dx: number, dy: number)
		to.x = lerp(to.x, from.x + dx * length, k)
		to.y = lerp(to.y, from.y + dy * length, k)
		local ox, oy = to.x - from.x, to.y - from.y
		local ol = math.max(math.sqrt(ox * ox + oy * oy), 1e-6)
		to.x, to.y = from.x + ox / ol * length, from.y + oy / ol * length
	end
	local function chain(first: string, last: string, length: number, droop: number)
		local dx, dy = bx, by + droop
		local dl = math.sqrt(dx * dx + dy * dy)
		dx, dy = dx / dl, dy / dl
		local p1, p2 = pose[first], pose[last]
		if not anim.tailsReady then
			p1.x, p1.y = head.x + dx * length, head.y + dy * length
			p2.x, p2.y = p1.x + dx * length, p1.y + dy * length
		end
		pull(head, p1, follow, length, dx, dy)
		pull(p1, p2, follow * 0.75, length, dx, dy)
	end
	chain("tail1", "tail1End", Rig.TAIL, 0)
	chain("tail2", "tail2End", Rig.TAIL * 0.85, 0.45)
	anim.tailsReady = true

	return pose
end

-- Forget the tails' trailing positions (after a teleport, such as a respawn).
function Animator.snap(anim: Animator)
	anim.tailsReady = false
	table.clear(anim.smoothed)
end

return Animator
