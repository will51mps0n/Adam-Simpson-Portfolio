--!strict
-- Draws the enemies the server simulates and checks whether any of them hits our ninja.
--
-- The server sends a snapshot of every moving enemy 30 times a second. We draw them
-- INTERP_DELAY seconds in the past, smoothly blended between the two snapshots around
-- that moment, and test our ninja against exactly what is drawn: if it looks like it hit
-- you, it did. Shots (bullets, gauss shots, explosions) arrive as timed events and play
-- out on that same delayed clock. Mines never move, so they come straight from the level.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local LevelBuilder = require(Shared.LevelBuilder)
local LevelGrid = require(Shared.LevelGrid)
local LevelObjects = require(Shared.Sim.LevelObjects)
local Collision = require(Shared.Sim.Collision)
local Protocol = require(Shared.Net.Protocol)
local Effects = require(script.Parent.Parent.Effects)

local C = Config.COLORS
local S = Config.STUDS_PER_PX
local R = Config.NINJA_RADIUS
local FIRST_ROCKET_ID = 1000
local Z_ENEMY = 0.15
local Z_SHOT = 0.25
local SHOT_SHOW_TIME = 0.25
local KEEP_SNAPSHOTS = 1.0 -- seconds of history kept

type Sample = { x: number, y: number, a: number, s: number }

type Snapshot = { time: number, entries: { [number]: Protocol.Entry } }

type Visual = {
	model: Model,
	update: (Visual, Sample, number) -> (),
	[string]: any,
}

type Static = { id: number, kind: string, x: number, y: number, dx: number, dy: number, seeker: boolean }

type Bullet = { t0: number, x0: number, y0: number, vx: number, vy: number, x: number, y: number, alive: boolean, part: Part }
type Shot = { t0: number, x0: number, y0: number, x1: number, y1: number, checked: boolean, part: Part }
type Blast = { t0: number, x: number, y: number, rocketId: number?, shown: boolean, checked: boolean }

export type EnemyView = {
	model: Model,
	grid: LevelGrid.Grid,
	z: number,
	epoch: number,
	waitingForReset: boolean,
	snapshots: { Snapshot },
	statics: { [number]: Static },
	visuals: { [number]: Visual },
	mines: { { id: number, x: number, y: number } },
	current: { [number]: Sample },
	previous: { [number]: Sample },
	thwumps: { [number]: Collision.Solid },
	bullets: { Bullet },
	shots: { Shot },
	blasts: { Blast },
	exploded: { [number]: boolean }, -- rockets we already blew up ourselves
	renderTime: number,
}

local EnemyView = {}

--------------------------------------------------------------------------------
-- Building parts
--------------------------------------------------------------------------------

local function part(parent: Instance, shape: Enum.PartType, color: Color3, size: Vector3): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function ball(parent: Instance, color: Color3, diameterPx: number): Part
	return part(parent, Enum.PartType.Ball, color, Vector3.one * diameterPx * S)
end

local function block(parent: Instance, color: Color3, wPx: number, hPx: number): Part
	return part(parent, Enum.PartType.Block, color, Vector3.new(wPx * S, hPx * S, 0.1))
end

-- A regular octagon `widthPx` across, built from a cross of two blocks plus a wedge in
-- each corner. Returns the parts and where each sits relative to the octagon's center.
local function octagon(parent: Instance, color: Color3, widthPx: number): ({ BasePart }, { CFrame })
	local w = widthPx * S
	local side = w / (1 + math.sqrt(2))
	local parts: { BasePart } = {
		part(parent, Enum.PartType.Block, color, Vector3.new(w, side, 0.1)),
		part(parent, Enum.PartType.Block, color, Vector3.new(side, w, 0.1)),
	}
	local offsets = { CFrame.identity, CFrame.identity }
	for _, c in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		local sx, sy = c[1], c[2]
		-- Right angle at the inner corner, legs out along the cross's arms.
		local r = Vector3.new(sx * side / 2, sy * side / 2, 0)
		local p = Vector3.new(sx * w / 2, sy * side / 2, 0)
		local q = Vector3.new(sx * side / 2, sy * w / 2, 0)
		local zAxis, yAxis = (r - p).Unit, (q - r).Unit
		local wedge = Instance.new("WedgePart")
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanQuery = false
		wedge.CanTouch = false
		wedge.CastShadow = false
		wedge.Material = Enum.Material.SmoothPlastic
		wedge.Color = color
		wedge.Size = Vector3.new(0.1, (q - r).Magnitude, (r - p).Magnitude)
		wedge.Parent = parent
		table.insert(parts, wedge)
		table.insert(offsets, CFrame.fromMatrix((p + q) / 2, yAxis:Cross(zAxis), yAxis, zAxis))
	end
	return parts, offsets
end

local function rod(parent: Instance, color: Color3, lengthPx: number, thickPx: number): Part
	return part(parent, Enum.PartType.Cylinder, color, Vector3.new(lengthPx * S, thickPx * S, thickPx * S))
end

-- CFrame for a flat piece centered at px (x, y), turned by angle a (radians, y down).
local function at(x: number, y: number, z: number, a: number?): CFrame
	local cf = CFrame.new(Units.toWorld(x, y, z))
	if a and a ~= 0 then
		cf *= CFrame.Angles(0, 0, -a)
	end
	return cf
end

-- A rod from (x0, y0) to (x1, y1) px.
local function between(p: BasePart, x0: number, y0: number, x1: number, y1: number, z: number)
	local a, b = Units.toWorld(x0, y0, z), Units.toWorld(x1, y1, z)
	local d = b - a
	local len = d.Magnitude
	if len < 1e-4 then
		p.Transparency = 1
		return
	end
	local xAxis = d / len
	p.Size = Vector3.new(len, p.Size.Y, p.Size.Z)
	p.CFrame = CFrame.fromMatrix((a + b) / 2, xAxis, Vector3.zAxis:Cross(xAxis))
end

local function eye(parent: Instance, sizePx: number): (Part, Part)
	return ball(parent, C.EYE, sizePx), ball(parent, C.PUPIL, sizePx * 0.5)
end

-- Balls are real spheres, so anything drawn on top of one has to sit in front of its
-- surface (its center plus its radius), or the sphere hides it.
local function inFront(ballPart: BasePart): number
	return ballPart.Size.X / 2 + 0.02
end

local function placeEye(white: BasePart, pupil: BasePart, x: number, y: number, z: number, a: number, lookPx: number)
	white.CFrame = at(x, y, z)
	pupil.CFrame = at(x + math.cos(a) * lookPx, y + math.sin(a) * lookPx, z + inFront(white))
end

local function newVisual(view: EnemyView, st: Static): Visual?
	local model = Instance.new("Model")
	model.Name = st.kind
	local z = view.z
	local d = Config.DRONE_RADIUS_PX * 2
	local vis: Visual

	if st.kind == "zapDrone" then
		-- A blue octagon with an eye; seekers have an antenna.
		local shell, offsets = octagon(model, C.ZAP_DRONE, d)
		local white, pupil = eye(model, d * 0.5)
		local antenna = if st.seeker then rod(model, C.PUPIL, 5, 1) else nil
		local tip = if st.seeker then ball(model, C.LASER, 2.6) else nil
		vis = {
			model = model,
			update = function(v: Visual, s: Sample)
				local center = at(s.x, s.y, z)
				for i, piece in shell do
					piece.CFrame = center * offsets[i]
				end
				placeEye(white, pupil, s.x, s.y, z + 0.03, s.a, d * 0.12)
				white.Color = if s.s == 1 then C.LASER else C.EYE
				if antenna and tip then
					between(antenna, s.x, s.y - d * 0.4, s.x, s.y - d * 0.4 - 4, z)
					tip.CFrame = at(s.x, s.y - d * 0.4 - 5, z)
				end
			end,
		}
	elseif st.kind == "laserDrone" then
		local body = ball(model, C.LASER_DRONE, d)
		body.Transparency = 0.45
		local pupil = ball(model, C.PUPIL, d * 0.3)
		local beam = rod(model, C.LASER, 1, 2)
		beam.Material = Enum.Material.Neon
		vis = {
			model = model,
			update = function(v: Visual, s: Sample)
				body.CFrame = at(s.x, s.y, z)
				body.Color = if s.s == 1 or s.s == 2 then C.LASER else C.LASER_DRONE
				pupil.CFrame = at(s.x + math.cos(s.a) * d * 0.2, s.y + math.sin(s.a) * d * 0.2, z)
				if s.s == 2 then
					local ex, ey = EnemyView.beamEnd(view, s.x, s.y, s.a)
					beam.Transparency = 0
					between(beam, s.x, s.y, ex, ey, view.z - Z_ENEMY + Z_SHOT)
				else
					beam.Transparency = 1
				end
			end,
		}
	elseif st.kind == "chaingunDrone" then
		local body = ball(model, C.CHAINGUN_DRONE, d)
		local barrel = rod(model, C.PUPIL, 7, 2.4)
		vis = {
			model = model,
			update = function(v: Visual, s: Sample)
				body.CFrame = at(s.x, s.y, z)
				between(barrel, s.x, s.y, s.x + math.cos(s.a) * 10, s.y + math.sin(s.a) * 10, z - 0.03)
				barrel.Color = if s.s == 1 then C.BULLET else C.PUPIL
			end,
		}
	elseif st.kind == "floorGuard" then
		local w, h = Config.FLOOR_GUARD_W_PX, Config.FLOOR_GUARD_H_PX
		local body = block(model, C.FLOOR_GUARD, w, h)
		local e1, p1 = eye(model, 3.4)
		local e2, p2 = eye(model, 3.4)
		vis = {
			model = model,
			update = function(v: Visual, s: Sample)
				body.CFrame = at(s.x, s.y, z)
				local look = if v.lastX and s.x < v.lastX - 0.01 then math.pi else 0
				v.lastX = s.x
				placeEye(e1, p1, s.x - 2.5, s.y - 1.5, z + 0.03, look, 0.8)
				placeEye(e2, p2, s.x + 2.5, s.y - 1.5, z + 0.03, look, 0.8)
			end,
		}
	elseif st.kind == "thwump" then
		local size = Config.THWUMP_SIZE_PX
		local body = block(model, C.THWUMP, size, size)
		local faceW = if st.dx ~= 0 then 4 else size
		local faceH = if st.dy ~= 0 then 4 else size
		local face = block(model, C.THWUMP_FACE, faceW, faceH)
		vis = {
			model = model,
			update = function(v: Visual, s: Sample)
				body.CFrame = at(s.x, s.y, z)
				face.CFrame = at(s.x + st.dx * (size / 2 - 2), s.y + st.dy * (size / 2 - 2), z + 0.03)
			end,
		}
	elseif st.kind == "gaussTurret" or st.kind == "rocketTurret" then
		local gauss = st.kind == "gaussTurret"
		local body = ball(model, if gauss then C.GAUSS_TURRET else C.ROCKET_TURRET, Config.TURRET_RADIUS_PX * 2)
		local barrel = rod(model, if gauss then C.GAUSS_SHOT else C.ROCKET, 6, 2.6)
		vis = {
			model = model,
			update = function(v: Visual, s: Sample)
				body.CFrame = at(s.x, s.y, z + 0.03)
				between(barrel, s.x, s.y, s.x + math.cos(s.a) * 12, s.y + math.sin(s.a) * 12, z)
				if gauss then
					body.Color = if s.s == 1 then C.GAUSS_SHOT else C.GAUSS_TURRET
				end
			end,
		}
	elseif st.kind == "rocket" then
		local body = rod(model, C.ROCKET, 7, Config.ROCKET_RADIUS_PX * 2)
		body.Material = Enum.Material.Neon
		vis = {
			model = model,
			update = function(v: Visual, s: Sample)
				between(body, s.x - math.cos(s.a) * 3.5, s.y - math.sin(s.a) * 3.5, s.x + math.cos(s.a) * 3.5, s.y + math.sin(s.a) * 3.5, z)
			end,
		}
	else
		return nil
	end
	model.Parent = view.model
	return vis
end

local function makeMine(parent: Instance, x: number, y: number, z: number)
	local model = Instance.new("Model")
	model.Name = "mine"
	local body = ball(model, C.MINE, Config.MINE_RADIUS_PX * 2)
	body.CFrame = at(x, y, z)
	for i = 0, 3 do
		local a = i * math.pi / 4
		local spike = rod(model, C.MINE, Config.MINE_RADIUS_PX * 2 + 4, 1.2)
		local dx, dy = math.cos(a) * (Config.MINE_RADIUS_PX + 2), math.sin(a) * (Config.MINE_RADIUS_PX + 2)
		between(spike, x - dx, y - dy, x + dx, y + dy, z - 0.02)
	end
	ball(model, C.MINE_CORE, Config.MINE_RADIUS_PX * 0.9).CFrame = at(x, y, z + inFront(body))
	model.Parent = parent
end

--------------------------------------------------------------------------------
-- Life cycle
--------------------------------------------------------------------------------

function EnemyView.new(built: LevelBuilder.BuiltLevel): EnemyView
	local model = Instance.new("Model")
	model.Name = "Enemies"
	local view: EnemyView = {
		model = model,
		grid = built.grid,
		z = built.frontZ + Z_ENEMY,
		epoch = 0,
		waitingForReset = false,
		snapshots = {},
		statics = {},
		visuals = {},
		mines = {},
		current = {},
		previous = {},
		thwumps = {},
		bullets = {},
		shots = {},
		blasts = {},
		exploded = {},
		renderTime = 0,
	}
	for id, obj in built.def.objects do
		local x, y = LevelObjects.center(obj)
		if obj.type == "mine" then
			table.insert(view.mines, { id = id, x = x, y = y })
			makeMine(model, x, y, view.z)
		else
			local dx, dy = LevelObjects.direction(obj.dir, if obj.type == "thwump" then "left" else "right")
			if obj.type == "thwump" then
				dx, dy = math.sign(math.round(dx)), math.sign(math.round(dy))
				if dx ~= 0 then
					dy = 0
				end
			end
			if obj.type == "floorGuard" then
				y = (obj.y + 1) * Config.TILE_PX - Config.FLOOR_GUARD_H_PX / 2
			end
			local st: Static = { id = id, kind = obj.type, x = x, y = y, dx = dx, dy = dy, seeker = obj.seeker == true }
			local vis = newVisual(view, st)
			if vis then
				view.statics[id] = st
				view.visuals[id] = vis
				vis.update(vis, { x = x, y = y, a = math.atan2(dy, dx), s = 0 }, 0)
				if obj.type == "thwump" then
					local h = Config.THWUMP_SIZE_PX / 2
					view.thwumps[id] = { x0 = x - h, y0 = y - h, x1 = x + h, y1 = y + h, vx = 0, vy = 0, tag = "thwump" }
				end
			end
		end
	end
	model.Parent = built.model
	return view
end

local function clearShots(view: EnemyView)
	for _, b in view.bullets do
		b.part:Destroy()
	end
	for _, s in view.shots do
		s.part:Destroy()
	end
	table.clear(view.bullets)
	table.clear(view.shots)
	table.clear(view.blasts)
	table.clear(view.exploded)
end

-- Our player restarted: ignore enemy news until the server confirms the reset.
function EnemyView.expectReset(view: EnemyView)
	view.waitingForReset = true
	clearShots(view)
end

-- The server reset the level (new `epoch`): forget the old enemy motion.
function EnemyView.reset(view: EnemyView, epoch: number)
	view.epoch = epoch
	view.waitingForReset = false
	table.clear(view.snapshots)
	table.clear(view.current)
	table.clear(view.previous)
	clearShots(view)
	for id, vis in view.visuals do
		local st = view.statics[id]
		if st then
			vis.update(vis, { x = st.x, y = st.y, a = math.atan2(st.dy, st.dx), s = 0 }, 0)
			local t = view.thwumps[id]
			if t then
				local h = Config.THWUMP_SIZE_PX / 2
				t.x0, t.y0, t.x1, t.y1, t.vx, t.vy = st.x - h, st.y - h, st.x + h, st.y + h, 0, 0
			end
		else
			vis.model:Destroy()
			view.visuals[id] = nil
		end
	end
end

function EnemyView.onSnapshot(view: EnemyView, snap: Protocol.Snapshot)
	if view.waitingForReset or snap.epoch ~= view.epoch then
		return
	end
	-- Big snapshots come in several packets with the same time: merge them.
	local list = view.snapshots
	local target: Snapshot? = nil
	for i = #list, math.max(1, #list - 3), -1 do
		if list[i].time == snap.time then
			target = list[i]
			break
		end
	end
	if not target then
		local fresh = { time = snap.time, entries = {} }
		local i = #list
		while i >= 1 and list[i].time > snap.time do
			i -= 1
		end
		table.insert(list, i + 1, fresh)
		target = fresh
	end
	for _, e in snap.entries do
		(target :: Snapshot).entries[e.id] = e
	end
	while #list > 2 and list[1].time < snap.time - KEEP_SNAPSHOTS do
		table.remove(list, 1)
	end
end

function EnemyView.onEvent(view: EnemyView, kind: string, ...: any)
	if view.waitingForReset then
		return
	end
	local args = { ... }
	if kind == "bullet" then
		local t0, x0, y0, vx, vy = args[1], args[2], args[3], args[4], args[5]
		if type(t0) == "number" and type(x0) == "number" and type(y0) == "number" and type(vx) == "number" and type(vy) == "number" then
			local p = ball(view.model, C.BULLET, Config.BULLET_RADIUS_PX * 2)
			p.Material = Enum.Material.Neon
			p.Transparency = 1
			table.insert(view.bullets, { t0 = t0, x0 = x0, y0 = y0, vx = vx, vy = vy, x = x0, y = y0, alive = true, part = p })
		end
	elseif kind == "gauss" then
		local t0, x0, y0, x1, y1 = args[1], args[2], args[3], args[4], args[5]
		if type(t0) == "number" and type(x0) == "number" and type(y0) == "number" and type(x1) == "number" and type(y1) == "number" then
			local p = rod(view.model, C.GAUSS_SHOT, 1, 1.6)
			p.Material = Enum.Material.Neon
			p.Transparency = 1
			table.insert(view.shots, { t0 = t0, x0 = x0, y0 = y0, x1 = x1, y1 = y1, checked = false, part = p })
		end
	elseif kind == "explosion" then
		local t0, x, y, id = args[1], args[2], args[3], args[4]
		if type(id) == "number" and view.exploded[id] then
			return -- we already showed this rocket's explosion when it hit us
		end
		if type(t0) == "number" and type(x) == "number" and type(y) == "number" then
			table.insert(view.blasts, { t0 = t0, x = x, y = y, rocketId = if type(id) == "number" then id else nil, shown = false, checked = false })
		end
	end
	-- "beep" and "thud" are for sounds and camera shake (polish milestone).
end

--------------------------------------------------------------------------------
-- Each frame
--------------------------------------------------------------------------------

local function lerpAngle(a: number, b: number, t: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * t
end

function EnemyView.beamEnd(view: EnemyView, x: number, y: number, a: number): (number, number)
	local range = Config.LASER_RANGE_PX
	local ex, ey = x + math.cos(a) * range, y + math.sin(a) * range
	local hit = Collision.raycast(view.grid, x, y, ex, ey)
	if hit then
		return x + (ex - x) * hit, y + (ey - y) * hit
	end
	return ex, ey
end

-- Moves everything to where it was at `renderTime` (server time) and plays out shots.
function EnemyView.update(view: EnemyView, renderTime: number, dt: number)
	view.renderTime = renderTime
	local list = view.snapshots

	-- The snapshots just before and after renderTime.
	local before: Snapshot?, after: Snapshot? = nil, nil
	for i = #list, 1, -1 do
		if list[i].time <= renderTime then
			before, after = list[i], list[i + 1]
			break
		end
	end
	if not before and #list > 0 then
		before = list[1]
	end

	local previous, current = view.previous, view.current
	for id, sample in current do
		previous[id] = sample
	end
	local seen: { [number]: boolean } = {}
	if before then
		local f = if after then math.clamp((renderTime - before.time) / (after.time - before.time), 0, 1) else 0
		for id, e0 in before.entries do
			local e1 = if after then after.entries[id] else nil
			local sample: Sample
			if e1 then
				sample = { x = e0.x + (e1.x - e0.x) * f, y = e0.y + (e1.y - e0.y) * f, a = lerpAngle(e0.a, e1.a, f), s = e0.s }
			else
				sample = { x = e0.x, y = e0.y, a = e0.a, s = e0.s }
			end
			current[id] = sample
			seen[id] = true
		end
	end

	for id, sample in current do
		if not seen[id] then
			current[id] = nil -- a rocket that's gone
			local vis = view.visuals[id]
			if vis and not view.statics[id] then
				vis.model:Destroy()
				view.visuals[id] = nil
			end
			continue
		end
		local vis = view.visuals[id]
		if not vis and id >= FIRST_ROCKET_ID then
			local made = newVisual(view, { id = id, kind = "rocket", x = sample.x, y = sample.y, dx = 1, dy = 0, seeker = false })
			if made then
				view.visuals[id] = made
				vis = made
			end
		end
		if vis then
			vis.update(vis, sample, dt)
		end
		local t = view.thwumps[id]
		if t then
			local h = Config.THWUMP_SIZE_PX / 2
			local last = previous[id]
			local frames = math.max(dt * 60, 1e-3)
			t.vx = if last then (sample.x - last.x) / frames else 0
			t.vy = if last then (sample.y - last.y) / frames else 0
			t.x0, t.y0, t.x1, t.y1 = sample.x - h, sample.y - h, sample.x + h, sample.y + h
		end
	end

	-- Bullets fly in straight lines from when they were fired until they hit a wall.
	local i = 1
	while i <= #view.bullets do
		local b = view.bullets[i]
		if renderTime >= b.t0 and b.alive then
			local age = (renderTime - b.t0) * 60
			local nx, ny = b.x0 + b.vx * age, b.y0 + b.vy * age
			if Collision.raycast(view.grid, b.x, b.y, nx, ny) or age > 60 * 6 then
				b.alive = false
			else
				b.x, b.y = nx, ny
				b.part.Transparency = 0
				b.part.CFrame = at(nx, ny, view.z - Z_ENEMY + Z_SHOT)
			end
		end
		if not b.alive then
			b.part:Destroy()
			table.remove(view.bullets, i)
		else
			i += 1
		end
	end

	i = 1
	while i <= #view.shots do
		local s = view.shots[i]
		local age = renderTime - s.t0
		if age >= 0 then
			s.part.Transparency = math.clamp(age / SHOT_SHOW_TIME, 0, 1)
			between(s.part, s.x0, s.y0, s.x1, s.y1, view.z - Z_ENEMY + Z_SHOT)
		end
		if age > SHOT_SHOW_TIME and s.checked then
			s.part:Destroy()
			table.remove(view.shots, i)
		else
			i += 1
		end
	end

	i = 1
	while i <= #view.blasts do
		local b = view.blasts[i]
		if renderTime >= b.t0 and not b.shown then
			b.shown = true
			Effects.explosion(view.model, b.x, b.y, Config.EXPLOSION_RADIUS_PX, view.z - Z_ENEMY + Z_SHOT)
		end
		if b.shown and b.checked then
			table.remove(view.blasts, i)
		else
			i += 1
		end
	end
end

-- A rocket hit our ninja and we've shown the explosion ourselves.
function EnemyView.markExploded(view: EnemyView, rocketId: number)
	view.exploded[rocketId] = true
end

-- Adds the thwumps (solid, and they can shove and crush) to `out`.
function EnemyView.solids(view: EnemyView, out: { Collision.Solid })
	for _, t in view.thwumps do
		table.insert(out, t)
	end
end

-- Marks every shot and explosion that has already happened as checked (call while our
-- ninja can't be hurt, so old shots don't hit it later).
function EnemyView.ignorePastShots(view: EnemyView)
	for _, s in view.shots do
		if s.t0 <= view.renderTime then
			s.checked = true
		end
	end
	for _, b in view.blasts do
		if b.t0 <= view.renderTime then
			b.checked = true
		end
	end
end

-- Is our ninja (center x, y) touching anything deadly? Returns what killed it, the enemy's
-- id (if any) and, for explosions, where the blast was.
function EnemyView.hazard(view: EnemyView, x: number, y: number): (string?, number?, number?, number?)
	for _, m in view.mines do
		if (m.x - x) ^ 2 + (m.y - y) ^ 2 < (R + Config.MINE_RADIUS_PX) ^ 2 then
			return "mine", m.id, m.x, m.y
		end
	end

	for id, s in view.current do
		local st = view.statics[id]
		local kind = if st then st.kind else "rocket"
		local d2 = (s.x - x) ^ 2 + (s.y - y) ^ 2
		if kind == "zapDrone" or kind == "laserDrone" or kind == "chaingunDrone" then
			if d2 < (R + Config.DRONE_RADIUS_PX) ^ 2 then
				return kind, id
			end
			if kind == "laserDrone" and s.s == 2 then
				local ex, ey = EnemyView.beamEnd(view, s.x, s.y, s.a)
				if Collision.segmentDistance(x, y, s.x, s.y, ex, ey) < R then
					return "laser", id
				end
			end
		elseif kind == "floorGuard" then
			local w, h = Config.FLOOR_GUARD_W_PX / 2, Config.FLOOR_GUARD_H_PX / 2
			if LevelObjects.circleTouchesBox(x, y, R, s.x - w, s.y - h, s.x + w, s.y + h) then
				return kind, id
			end
		elseif kind == "thwump" and st then
			local h = Config.THWUMP_SIZE_PX / 2
			local d, nx, ny = Collision.boxDistance(s.x - h, s.y - h, s.x + h, s.y + h, x, y)
			if d < R + 0.6 and nx * st.dx + ny * st.dy > 0.7 then
				return kind, id
			end
		elseif kind == "gaussTurret" or kind == "rocketTurret" then
			if d2 < (R + Config.TURRET_RADIUS_PX) ^ 2 then
				return kind, id
			end
		elseif kind == "rocket" then
			if d2 < (R + Config.ROCKET_RADIUS_PX) ^ 2 then
				return "rocket", id, s.x, s.y
			end
		end
	end

	for _, b in view.bullets do
		if b.alive and view.renderTime >= b.t0 and (b.x - x) ^ 2 + (b.y - y) ^ 2 < (R + Config.BULLET_RADIUS_PX) ^ 2 then
			return "bullet", nil
		end
	end
	for _, s in view.shots do
		if not s.checked and s.t0 <= view.renderTime then
			s.checked = true
			if Collision.segmentDistance(x, y, s.x0, s.y0, s.x1, s.y1) < R then
				return "gauss", nil
			end
		end
	end
	for _, b in view.blasts do
		if not b.checked and b.t0 <= view.renderTime then
			b.checked = true
			if (b.x - x) ^ 2 + (b.y - y) ^ 2 < (R + Config.EXPLOSION_RADIUS_PX) ^ 2 then
				return "explosion", b.rocketId, b.x, b.y
			end
		end
	end
	return nil
end

return EnemyView
