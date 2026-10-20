--!strict
-- Draws every enemy from the server's position updates. Models come from a
-- pool per enemy type and are all moved with one BulkMoveTo call per frame.
-- Positions are drawn slightly in the past (ENEMY_INTERP_DELAY) so the
-- renderer can blend smoothly between updates. Legs swing while walking,
-- enemies flash white when hit and burst into blocks and a splat on death.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EnemyModels = require(Shared:WaitForChild("Models"):WaitForChild("EnemyModels"))
local Net = require(Shared:WaitForChild("Net"))
local Snapshot = require(Shared:WaitForChild("Snapshot"))
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)

type PartInfo = {
	part: Part,
	color: Color3,
	rest: CFrame, -- relative to the feet when not animated
	limb: string?,
	joint: CFrame?, -- pivot for limbs
	fromJoint: CFrame?, -- part relative to its pivot
}

type Model = { kind: string, parts: { PartInfo } }

type Sample = { t: number, x: number, z: number, facing: number }

type Rendered = {
	id: number,
	kind: string,
	model: Model,
	samples: { Sample },
	health: number,
	lastSeen: number,
	flashUntil: number,
	flashing: boolean,
	x: number,
	z: number,
	facing: number,
	phase: number,
}

export type Target = { x: number, z: number, radius: number }

local EnemyRenderer = {}

local HIDDEN = CFrame.new(0, -500, 0)
local STALE_AFTER = 1.5 -- seconds without an update before an enemy is dropped
local FLASH_COLOR = Color3.new(1, 1, 1)

local folder: Folder
local pools: { [string]: { Model } } = {}
local rendered: { [number]: Rendered } = {}
local bulkParts: { BasePart } = {}
local bulkFrames: { CFrame } = {}
local groanTimer = 3

local function buildModel(kind: string): Model
	local spec = EnemyModels.SPECS[kind] or EnemyModels.SPECS.Zombie
	local scale = spec.scale
	local parts: { PartInfo } = {}
	for _, partSpec in spec.parts do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = partSpec.size * scale
		part.Color = partSpec.color
		part.Material = if partSpec.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = HIDDEN
		part.Parent = folder
		local rest = CFrame.new(partSpec.offset * scale) * CFrame.Angles(math.rad(partSpec.tilt or 0), 0, 0)
		local info: PartInfo = { part = part, color = partSpec.color, rest = rest, limb = partSpec.limb }
		local joint = partSpec.joint
		if joint then
			local jointFrame = CFrame.new(joint * scale)
			info.joint = jointFrame
			info.fromJoint = jointFrame:Inverse() * rest
		end
		table.insert(parts, info)
	end
	return { kind = kind, parts = parts }
end

local function acquire(kind: string): Model
	local pool = pools[kind]
	local model = pool and table.remove(pool)
	return model or buildModel(kind)
end

local function setColor(model: Model, flash: boolean)
	for _, info in model.parts do
		info.part.Color = if flash then FLASH_COLOR else info.color
	end
end

local function release(entry: Rendered)
	rendered[entry.id] = nil
	if entry.flashing then
		setColor(entry.model, false)
	end
	local parts, frames = {}, {}
	for _, info in entry.model.parts do
		table.insert(parts, info.part)
		table.insert(frames, HIDDEN)
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	local pool = pools[entry.kind]
	if not pool then
		pool = {}
		pools[entry.kind] = pool
	end
	table.insert(pool, entry.model)
end

local function onSnapshot(buf: buffer)
	local now = os.clock()
	local time = Snapshot.time(buf)
	Snapshot.read(buf, function(id: number, kindIndex: number, x: number, z: number, facing: number, health: number)
		local kind = Config.ENEMY_KINDS[kindIndex] or "Zombie"
		local entry: Rendered? = rendered[id]
		if entry and entry.kind ~= kind then
			release(entry) -- id was reused by a new enemy
			entry = nil
		end
		if not entry then
			local created: Rendered = {
				id = id,
				kind = kind,
				model = acquire(kind),
				samples = {},
				health = health,
				lastSeen = now,
				flashUntil = 0,
				flashing = false,
				x = x,
				z = z,
				facing = facing,
				phase = math.random() * 6,
			}
			rendered[id] = created
			entry = created
		end
		local current = entry :: Rendered
		if health < current.health - 1e-3 then
			current.flashUntil = now + Config.HIT_FLASH_TIME
		end
		current.health = health
		current.lastSeen = now
		table.insert(current.samples, { t = time, x = x, z = z, facing = facing })
		if #current.samples > 4 then
			table.remove(current.samples, 1)
		end
	end)
end

local function onDied(list: { number })
	for i = 1, #list - 3, 4 do
		local id, kindIndex, x, z = list[i], list[i + 1], list[i + 2], list[i + 3]
		local entry = rendered[id]
		if entry then
			release(entry)
		end
		local spec = EnemyModels.SPECS[Config.ENEMY_KINDS[kindIndex] or "Zombie"] or EnemyModels.SPECS.Zombie
		Effects.enemyDeath(x, z, spec.debris)
	end
end

local function onEvent(kind: string, id: number?, x0: number?, z0: number?, x1: number?, z1: number?)
	if kind == "clear" then
		for _, entry in rendered do
			release(entry)
		end
		Effects.clearSplats()
	elseif kind == "teleport" and id and x0 and z0 and x1 and z1 then
		Effects.teleportPuff(x0, z0)
		Effects.teleportPuff(x1, z1)
		local entry = rendered[id]
		if entry then
			-- Jump straight there instead of sliding.
			entry.samples = { { t = workspace:GetServerTimeNow(), x = x1, z = z1, facing = entry.facing } }
			entry.x, entry.z = x1, z1
		end
	end
end

local function lerpAngle(a: number, b: number, t: number): number
	local diff = (b - a + math.pi) % (math.pi * 2) - math.pi
	return a + diff * t
end

-- Where an enemy should be drawn at `time`, blending between samples.
local function sample(entry: Rendered, time: number): (number, number, number)
	local samples = entry.samples
	local count = #samples
	if count == 0 then
		return entry.x, entry.z, entry.facing
	end
	if time <= samples[1].t then
		return samples[1].x, samples[1].z, samples[1].facing
	end
	for i = 1, count - 1 do
		local a, b = samples[i], samples[i + 1]
		if time <= b.t then
			local span = b.t - a.t
			local t = if span > 1e-4 then (time - a.t) / span else 1
			return a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t, lerpAngle(a.facing, b.facing, t)
		end
	end
	local last = samples[count]
	return last.x, last.z, last.facing
end

local function update(dt: number)
	local now = os.clock()
	local renderTime = workspace:GetServerTimeNow() - Config.ENEMY_INTERP_DELAY
	table.clear(bulkParts)
	table.clear(bulkFrames)
	local count = 0
	for _, entry in rendered do
		if now - entry.lastSeen > STALE_AFTER then
			release(entry)
			continue
		end
		count += 1
		local x, z, facing = sample(entry, renderTime)
		local moved = math.sqrt((x - entry.x) ^ 2 + (z - entry.z) ^ 2)
		local speed = if dt > 0 then moved / dt else 0
		entry.x, entry.z, entry.facing = x, z, facing
		entry.phase += speed * dt * 0.55
		local swing = math.sin(entry.phase) * math.min(speed / 6, 1) * 0.7

		local flash = now < entry.flashUntil
		if flash ~= entry.flashing then
			entry.flashing = flash
			setColor(entry.model, flash)
		end

		local base = CFrame.new(x, 0, z) * CFrame.Angles(0, facing, 0)
		for _, info in entry.model.parts do
			local limb, joint, fromJoint = info.limb, info.joint, info.fromJoint
			local frame
			if limb and joint and fromJoint then
				local angle = 0
				if limb == "Leg" then
					angle = swing
				elseif limb == "LegOpposite" then
					angle = -swing
				elseif limb == "Arm" then
					angle = -swing * 0.8
				elseif limb == "ArmOpposite" then
					angle = swing * 0.8
				else -- "Bob": zombie arms sway a little
					angle = math.sin(entry.phase * 2) * 0.08
				end
				frame = base * joint * CFrame.Angles(angle, 0, 0) * fromJoint
			else
				frame = base * info.rest
			end
			table.insert(bulkParts, info.part)
			table.insert(bulkFrames, frame)
		end
	end
	if #bulkParts > 0 then
		workspace:BulkMoveTo(bulkParts, bulkFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	groanTimer -= dt
	if groanTimer <= 0 then
		groanTimer = math.random(3, 7)
		if count > 0 then
			Sounds.play("zombieGroan", 0.6)
		end
	end
end

-- Where this client currently draws each enemy, for instant tracer endpoints.
function EnemyRenderer.targets(): { Target }
	local list: { Target } = {}
	for _, entry in rendered do
		local def = Config.ENEMIES[entry.kind]
		table.insert(list, { x = entry.x, z = entry.z, radius = if def then def.radius else 1 })
	end
	return list
end

function EnemyRenderer.start()
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
	Net.unreliable("EnemySnapshot").OnClientEvent:Connect(onSnapshot)
	Net.event("EnemyDied").OnClientEvent:Connect(onDied)
	Net.event("EnemyEvent").OnClientEvent:Connect(onEvent)
	RunService.RenderStepped:Connect(update)
end

return EnemyRenderer
