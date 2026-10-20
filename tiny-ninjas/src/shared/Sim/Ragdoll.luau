--!strict
-- The floppy stick-figure ragdoll a ninja turns into when it dies.
--
-- Every bone of the rig becomes its own stick with a point at each end (verlet physics:
-- each point remembers where it was last frame, and the difference is its velocity).
-- Points where bones meet are pinned together, so the body stays in one piece until an
-- explosion tears some pins apart. Points bounce off the level using the same collision
-- as the ninja, so the ragdoll tumbles down slopes, off walls and around curves.
-- It all happens in the flat plane of the level, so it can never fall out of it.

local Config = require(script.Parent.Parent.Config)
local Collision = require(script.Parent.Collision)
local Rig = require(script.Parent.Rig)

type Link = { a: number, b: number, length: number }

export type Ragdoll = {
	x: { number }, -- point positions
	y: { number },
	ox: { number }, -- positions last frame
	oy: { number },
	radius: { number },
	sticks: { Link }, -- one per bone, keeps its length
	pins: { Link }, -- joins bones at shared joints
	stillFrames: number,
	asleep: boolean,
}

local Ragdoll = {}

local SOLVE_ROUNDS = 3
local SLEEP_SPEED = 0.03
local SLEEP_FRAMES = 45

-- A ragdoll in `pose`, moving at (vx, vy) px per frame. An explosion at (ex, ey) throws
-- it outward and may tear it apart.
function Ragdoll.new(pose: Rig.Pose, vx: number, vy: number, explosion: { x: number, y: number }?): Ragdoll
	local rd: Ragdoll = { x = {}, y = {}, ox = {}, oy = {}, radius = {}, sticks = {}, pins = {}, stillFrames = 0, asleep = false }

	-- The body's center, for a little random spin.
	local cx, cy, count = 0, 0, 0
	for _, p in pose do
		cx += p.x
		cy += p.y
		count += 1
	end
	cx, cy = cx / count, cy / count
	local spin = (math.random() - 0.5) * 0.12

	local firstAt: { [string]: number } = {}
	for i, bone in Rig.BONES do
		for k, name in { bone.a, bone.b } do
			local index = 2 * (i - 1) + k
			local p = pose[name]
			local pvx = vx - (p.y - cy) * spin
			local pvy = vy + (p.x - cx) * spin
			if explosion then
				local dx, dy = p.x - explosion.x, p.y - explosion.y
				local d = math.max(math.sqrt(dx * dx + dy * dy), 1)
				local push = Config.EXPLOSION_PUSH * math.clamp(1.4 - d / (Config.EXPLOSION_RADIUS_PX * 2), 0.4, 1.2)
				pvx += dx / d * push + (math.random() - 0.5) * 2
				pvy += dy / d * push + (math.random() - 0.5) * 2 - 1
			end
			rd.x[index], rd.y[index] = p.x, p.y
			rd.ox[index], rd.oy[index] = p.x - pvx, p.y - pvy
			rd.radius[index] = if bone.kind == "neck" and name == "head" then Config.HEAD_RADIUS_PX else 1
			-- Pin every bone end to the first bone that used the same joint.
			local first = firstAt[name]
			if first then
				if not (explosion and math.random() < Config.EXPLOSION_SPLIT_CHANCE) then
					table.insert(rd.pins, { a = first, b = index, length = 0 })
				end
			else
				firstAt[name] = index
			end
		end
		table.insert(rd.sticks, { a = 2 * i - 1, b = 2 * i, length = bone.length })
	end
	return rd
end

local function solveLinks(rd: Ragdoll, links: { Link })
	local x, y = rd.x, rd.y
	for _, link in links do
		local a, b = link.a, link.b
		local dx, dy = x[b] - x[a], y[b] - y[a]
		local d = math.sqrt(dx * dx + dy * dy)
		if d > 1e-6 then
			local diff = (d - link.length) / d * 0.5
			x[a] += dx * diff
			y[a] += dy * diff
			x[b] -= dx * diff
			y[b] -= dy * diff
		end
	end
end

local scratch: { Collision.Contact } = {}

local function collide(rd: Ragdoll, world: Collision.World)
	local x, y, ox, oy = rd.x, rd.y, rd.ox, rd.oy
	for i = 1, #x do
		local r = rd.radius[i]
		local deepest: Collision.Contact? = nil
		for _, c in Collision.contacts(world, x[i], y[i], r, scratch) do
			if not deepest or c.dist < deepest.dist then
				deepest = c
			end
		end
		if deepest then
			local push = r - deepest.dist
			x[i] += deepest.nx * push
			y[i] += deepest.ny * push
			-- Bounce: reflect part of the speed into the surface, rub off some speed along it.
			local vx, vy = x[i] - ox[i], y[i] - oy[i]
			local into = vx * deepest.nx + vy * deepest.ny
			if into < 0 then
				local tx, ty = vx - deepest.nx * into, vy - deepest.ny * into
				vx = tx * Config.RAGDOLL_FRICTION - deepest.nx * into * Config.RAGDOLL_BOUNCE
				vy = ty * Config.RAGDOLL_FRICTION - deepest.ny * into * Config.RAGDOLL_BOUNCE
				ox[i], oy[i] = x[i] - vx, y[i] - vy
			end
		end
	end
end

-- One frame (1/60 s).
function Ragdoll.step(rd: Ragdoll, world: Collision.World)
	if rd.asleep then
		return
	end
	local x, y, ox, oy = rd.x, rd.y, rd.ox, rd.oy
	local fastest = 0
	for i = 1, #x do
		local vx = (x[i] - ox[i]) * Config.RAGDOLL_DRAG
		local vy = (y[i] - oy[i]) * Config.RAGDOLL_DRAG + Config.RAGDOLL_GRAVITY
		ox[i], oy[i] = x[i], y[i]
		x[i] += vx
		y[i] += vy
		fastest = math.max(fastest, vx * vx + vy * vy)
	end
	for _ = 1, SOLVE_ROUNDS do
		solveLinks(rd, rd.sticks)
		solveLinks(rd, rd.pins)
		collide(rd, world)
	end

	if fastest < SLEEP_SPEED * SLEEP_SPEED then
		rd.stillFrames += 1
		rd.asleep = rd.stillFrames > SLEEP_FRAMES
	else
		rd.stillFrames = 0
	end
end

-- Bone endpoints in Rig.BONES order: { ax, ay, bx, by } each.
function Ragdoll.bones(rd: Ragdoll, out: { { number } }?): { { number } }
	local result = out or {}
	for i = 1, #Rig.BONES do
		local a, b = 2 * i - 1, 2 * i
		local seg = result[i]
		if seg then
			seg[1], seg[2], seg[3], seg[4] = rd.x[a], rd.y[a], rd.x[b], rd.y[b]
		else
			result[i] = { rd.x[a], rd.y[a], rd.x[b], rd.y[b] }
		end
	end
	return result
end

return Ragdoll
