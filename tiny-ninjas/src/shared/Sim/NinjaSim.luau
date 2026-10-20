--!strict
-- The ninja's movement rules, run 60 times a second with the original game's numbers.
--
-- The ninja is a circle moved by its velocity, gravity and drag, then pushed out of
-- whatever it overlaps. The surfaces it touches decide what it can do next: stand and
-- run on floors (anything flatter than 60 degrees), slide down and jump off walls, or
-- fly through the air. Hitting a surface too fast kills, and so does being squashed.
--
-- This is pure simulation with no Roblox objects, so the same code runs on every client
-- (and in offline tests). Units: pixels and frames, y pointing down.

local Config = require(script.Parent.Parent.Config)
local Collision = require(script.Parent.Collision)

local R = Config.NINJA_RADIUS
local PROBE = 1 -- px: surfaces this close still count as touched
local MAX_SUBSTEP = R * 0.4 -- move at most this far between collision checks
local FLOOR_NY = -0.5 -- surface normals pointing up more than this are floors (up to 60 degrees)
local CEILING_NY = 0.5

export type State = "ground" | "air" | "wall" | "dead" | "done"

export type Input = {
	left: boolean,
	right: boolean,
	jump: boolean,
}

export type Event = {
	kind: string, -- "jump", "wallJump", "land", "death", "launch"
	speed: number?, -- landing: how hard; death: impact speed
	cause: string?, -- death: what killed the ninja
}

export type Ninja = {
	x: number,
	y: number,
	vx: number,
	vy: number,
	state: State,
	facing: number, -- -1 left, 1 right
	h: number, -- horizontal input this frame (-1, 0, 1)

	onFloor: boolean,
	floorNx: number, -- normal of the floor being stood on
	floorNy: number,
	touchingWall: boolean,
	wallNormal: number, -- 1 if the touched wall is on the left (jumps go right), -1 if on the right
	contactSolid: Collision.Solid?, -- moving solid stood on, if any

	jumpHeld: boolean,
	jumping: boolean, -- in a jump that still gets the lighter "held" gravity
	jumpFrames: number,
	jumpBuffer: number, -- frames since jump was pressed (-1: none pending)
	floorBuffer: number, -- frames since last on a floor (-1: too long ago)
	wallBuffer: number, -- frames since last touching a wall (-1: too long ago)

	frame: number,
	airFrames: number,
	landFrames: number, -- frames since the last landing
	landSpeed: number,
	spinFrames: number, -- frames left of the wall-jump spin
	spinDir: number,

	deathCause: string?,
	deathVx: number,
	deathVy: number,
}

local NinjaSim = {}

NinjaSim.RADIUS = R

function NinjaSim.new(x: number, y: number): Ninja
	return {
		x = x,
		y = y,
		vx = 0,
		vy = 0,
		state = "air",
		facing = 1,
		h = 0,
		onFloor = false,
		floorNx = 0,
		floorNy = -1,
		touchingWall = false,
		wallNormal = 1,
		contactSolid = nil,
		jumpHeld = false,
		jumping = false,
		jumpFrames = 0,
		jumpBuffer = -1,
		floorBuffer = -1,
		wallBuffer = -1,
		frame = 0,
		airFrames = 0,
		landFrames = 999,
		landSpeed = 0,
		spinFrames = 0,
		spinDir = 1,
		deathCause = nil,
		deathVx = 0,
		deathVy = 0,
	}
end

function NinjaSim.isAlive(n: Ninja): boolean
	return n.state ~= "dead" and n.state ~= "done"
end

-- Ends the ninja's run. Returns false if it was already over.
function NinjaSim.kill(n: Ninja, cause: string, vx: number?, vy: number?): boolean
	if not NinjaSim.isAlive(n) then
		return false
	end
	n.state = "dead"
	n.deathCause = cause
	n.deathVx = vx or n.vx
	n.deathVy = vy or n.vy
	return true
end

-- Launch pads: sets the speed along (dx, dy) to `speed`, keeping sideways motion.
function NinjaSim.launch(n: Ninja, dx: number, dy: number, speed: number)
	local along = n.vx * dx + n.vy * dy
	n.vx += dx * (speed - along)
	n.vy += dy * (speed - along)
	n.state = "air"
	n.onFloor = false
	n.jumping = false
	n.floorBuffer = -1
	n.wallBuffer = -1
	n.jumpBuffer = -1
end

local function startJump(n: Ninja, jx: number, jy: number)
	if n.vy > 0 then
		n.vy = 0
	end
	n.vx += jx
	n.vy += jy
	-- Nudge off the surface right away so the next frame doesn't still count as touching it.
	n.x += jx
	n.y += jy
	n.jumping = true
	n.jumpFrames = 0
	n.jumpBuffer = -1
	n.floorBuffer = -1
	n.wallBuffer = -1
	n.onFloor = false
	n.state = "air"
end

-- Jumping off a floor. Flat floors kick straight up. On slopes the kick depends on which
-- way you're going: downhill (or jumping back off an uphill slope) pushes away from the
-- slope, while jumping forward up a slope kicks straight up so you keep your run.
local function floorJump(n: Ninja)
	local nx, ny = n.floorNx, n.floorNy
	if math.abs(nx) < 0.01 then
		startJump(n, 0, -Config.JUMP_VELOCITY)
		return
	end
	local downhill = n.vx * nx >= 0
	local pushingForward = n.vx * n.h > 0
	local awayFromSlope = Config.SLOPE_JUMP_NORMAL_X * nx
	local up = Config.SLOPE_JUMP_NORMAL_Y * ny
	if downhill then
		if n.vx * n.h >= 0 then
			startJump(n, awayFromSlope, up)
		else
			startJump(n, 0, -Config.SLOPE_JUMP_UPHILL)
		end
	elseif pushingForward then
		startJump(n, 0, -Config.SLOPE_JUMP_UPHILL)
	else
		n.vx = 0
		startJump(n, awayFromSlope, up)
	end
end

-- Jumping off a wall: up and away. Sliding down a wall while still pressing into it gives
-- a smaller hop, which is how you climb a single wall.
local function wallJump(n: Ninja)
	local w = n.wallNormal
	local jx, jy = Config.WALL_JUMP_X, Config.WALL_JUMP_Y
	if n.state == "wall" and n.h * w < 0 then
		jx, jy = Config.WALL_SLIDE_JUMP_X, Config.WALL_SLIDE_JUMP_Y
	end
	if n.vx * w < 0 then
		n.vx = 0
	end
	startJump(n, jx * w, -jy)
	n.spinFrames = Config.WALL_JUMP_SPIN_FRAMES
	n.spinDir = w
end

-- Pushes the ninja out of everything it overlaps (deepest overlap first) and removes the
-- part of its velocity going into those surfaces. `oldVx, oldVy` is the velocity from
-- before this frame's collisions, used to judge how hard an impact was.
local scratch: { Collision.Contact } = {}
local function resolve(n: Ninja, world: Collision.World, oldVx: number, oldVy: number, events: { Event })
	for _ = 1, 4 do
		local contacts = Collision.contacts(world, n.x, n.y, R, scratch)
		local deepest: Collision.Contact? = nil
		for _, c in contacts do
			local solid = c.solid
			-- One-way platforms let you pass while moving away from their solid side.
			if solid and solid.oneWayNx and n.vx * c.nx + n.vy * c.ny > 0 then
				continue
			end
			if not deepest or c.dist < deepest.dist then
				deepest = c
			end
		end
		if not deepest then
			return
		end
		local push = R - deepest.dist
		n.x += deepest.nx * push
		n.y += deepest.ny * push
		-- Speeds are measured against the surface, so moving solids carry and shove the ninja.
		local solid = deepest.solid
		local svx = if solid then solid.vx or 0 else 0
		local svy = if solid then solid.vy or 0 else 0
		local into = (n.vx - svx) * deepest.nx + (n.vy - svy) * deepest.ny
		if into < 0 then
			local impact = -((oldVx - svx) * deepest.nx + (oldVy - svy) * deepest.ny)
			local limit = Config.MAX_SURVIVABLE_IMPACT - Config.IMPACT_FLAT_PENALTY * math.abs(deepest.ny)
			if impact > limit then
				NinjaSim.kill(n, "impact", oldVx, oldVy)
				table.insert(events, { kind = "death", cause = "impact", speed = impact })
				return
			end
			local bounce = if solid then solid.tag else nil
			if type(bounce) == "table" and bounce.onHit then
				-- Springy things (bounce blocks) take some of the push and give it back later.
				into = bounce.onHit(bounce, deepest.nx, deepest.ny, into, push)
			end
			n.vx -= deepest.nx * into
			n.vy -= deepest.ny * into
		end
	end
	-- Still deep inside something after every push: squashed between two solids.
	for _, c in Collision.contacts(world, n.x, n.y, R - Config.CRUSH_DEPTH_PX, scratch) do
		if not (c.solid and c.solid.oneWayNx) then
			NinjaSim.kill(n, "crushed", n.vx, n.vy)
			table.insert(events, { kind = "death", cause = "crushed" })
			return
		end
	end
end

-- Looks at the surfaces right around the ninja to decide floor / wall contact.
-- `oldVx, oldVy` is the velocity from before this frame's collisions (for landing speed).
local function probe(n: Ninja, world: Collision.World, oldVx: number, oldVy: number, events: { Event })
	local floor: Collision.Contact? = nil
	local wall: Collision.Contact? = nil
	for _, c in Collision.contacts(world, n.x, n.y, R + PROBE, scratch) do
		local solid = c.solid
		if solid and solid.oneWayNx and n.vx * c.nx + n.vy * c.ny > 0.05 then
			continue
		end
		if c.ny < FLOOR_NY then
			if not floor or c.ny < floor.ny then
				floor = c
			end
		elseif c.ny <= CEILING_NY then
			if not wall or c.dist < wall.dist then
				wall = c
			end
		end
	end

	local wasOnFloor = n.onFloor
	if floor then
		if not wasOnFloor then
			n.landFrames = 0
			n.landSpeed = math.max(0, -(oldVx * floor.nx + oldVy * floor.ny))
			table.insert(events, { kind = "land", speed = n.landSpeed })
		end
		n.onFloor = true
		n.floorNx, n.floorNy = floor.nx, floor.ny
		n.contactSolid = floor.solid
		n.floorBuffer = 0
		n.jumping = false
	else
		n.onFloor = false
		n.contactSolid = nil
		if n.floorBuffer >= 0 then
			n.floorBuffer += 1
			if n.floorBuffer > Config.COYOTE_FRAMES then
				n.floorBuffer = -1
			end
		end
	end

	if wall then
		n.touchingWall = true
		n.wallNormal = if wall.nx > 0 then 1 else -1
		n.wallBuffer = 0
	else
		n.touchingWall = false
		if n.wallBuffer >= 0 then
			n.wallBuffer += 1
			if n.wallBuffer > Config.COYOTE_FRAMES then
				n.wallBuffer = -1
			end
		end
	end

	if n.onFloor then
		n.state = "ground"
	elseif n.touchingWall and n.vy > 0 and n.h == -n.wallNormal then
		n.state = "wall"
	else
		n.state = "air"
	end
end

-- One frame (1/60 s). Returns what happened, for sounds and animation.
function NinjaSim.step(n: Ninja, input: Input, world: Collision.World): { Event }
	local events: { Event } = {}
	if not NinjaSim.isAlive(n) then
		return events
	end
	n.frame += 1

	local h = (if input.right then 1 else 0) - (if input.left then 1 else 0)
	n.h = h
	if h ~= 0 then
		n.facing = h
	end
	local jumpPressed = input.jump and not n.jumpHeld
	n.jumpHeld = input.jump
	if jumpPressed then
		n.jumpBuffer = 0
	elseif n.jumpBuffer >= 0 then
		n.jumpBuffer += 1
		if n.jumpBuffer > Config.JUMP_BUFFER_FRAMES then
			n.jumpBuffer = -1
		end
	end

	-- Running: accelerate toward the input. Input alone never pushes past max speed, but
	-- speed gained from slopes or launch pads isn't taken away either.
	if h ~= 0 then
		local accel = if n.onFloor then Config.GROUND_ACCEL else Config.AIR_ACCEL
		local nvx = n.vx + accel * h
		if math.abs(nvx) < Config.MAX_X_SPEED or math.abs(nvx) < math.abs(n.vx) then
			n.vx = nvx
		end
	end

	-- Ground friction when not pushing along the motion (stopping, or turning around).
	local standingStill = false
	if n.onFloor and (h == 0 or h * n.vx < 0) then
		local tx, ty = -n.floorNy, n.floorNx -- along the floor
		local along = (n.vx * tx + n.vy * ty) * Config.GROUND_FRICTION
		local into = n.vx * n.floorNx + n.vy * n.floorNy
		if h == 0 and math.abs(along) < Config.STOP_SPEED then
			along = 0
			standingStill = true -- and don't let gravity slide the ninja down a slope
		end
		n.vx = tx * along + n.floorNx * into
		n.vy = ty * along + n.floorNy * into
	end

	-- Jumping, with a short grace period after leaving a floor or wall.
	if n.jumpBuffer >= 0 then
		if n.floorBuffer >= 0 then
			floorJump(n)
			table.insert(events, { kind = "jump" })
		elseif n.wallBuffer >= 0 then
			wallJump(n)
			table.insert(events, { kind = "wallJump" })
		end
	end

	-- Holding jump keeps gravity light for a while: tap for a hop, hold for a high jump.
	if n.jumping and (not n.jumpHeld or n.jumpFrames >= Config.MAX_JUMP_FRAMES) then
		n.jumping = false
	end
	n.jumpFrames += 1
	local gravity = if n.jumping then Config.GRAVITY_JUMP_HELD else Config.GRAVITY_FALL

	-- Wall slide: falling while pressing into a wall slows the fall a lot.
	if not n.onFloor and n.touchingWall and n.vy > 0 and h == -n.wallNormal then
		n.vy *= Config.WALL_FRICTION
	end

	n.vx *= Config.AIR_DRAG
	n.vy *= Config.AIR_DRAG
	if not standingStill then
		n.vy += gravity
	end

	-- Move in small steps so fast movement can't skip through thin walls.
	local oldVx, oldVy = n.vx, n.vy
	local steps = math.max(1, math.ceil(math.sqrt(n.vx * n.vx + n.vy * n.vy) / MAX_SUBSTEP))
	for _ = 1, steps do
		n.x += n.vx / steps
		n.y += n.vy / steps
		resolve(n, world, oldVx, oldVy, events)
		if n.state == "dead" then
			return events
		end
	end

	probe(n, world, oldVx, oldVy, events)
	if n.onFloor then
		n.airFrames = 0
	else
		n.airFrames += 1
	end
	n.landFrames += 1
	if n.spinFrames > 0 then
		n.spinFrames -= 1
	end
	return events
end

return NinjaSim
