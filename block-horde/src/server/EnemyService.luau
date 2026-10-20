--!strict
-- The server's enemy table and simulation. Enemies are plain data (no
-- Humanoids) so the server can run hundreds of them. Each frame they follow
-- the flow field toward the nearest player, push apart from each other, slide
-- along walls, and attack players or placeables they bump into. Positions go
-- to clients as compact snapshots 15 times a second; clients draw the models.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FlowField = require(ReplicatedStorage.Shared.FlowField)
local Net = require(ReplicatedStorage.Shared.Net)
local RoomGrid = require(ReplicatedStorage.Shared.RoomGrid)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Snapshot = require(ReplicatedStorage.Shared.Snapshot)
local KillContext = require(script.Parent.KillContext)
local RoomBuilder = require(script.Parent.RoomBuilder)

local SnapshotRemote = Net.unreliable("EnemySnapshot")
local EnemyDied = Net.event("EnemyDied")
local EnemyEvent = Net.event("EnemyEvent")

export type Enemy = {
	id: number,
	kind: string,
	kindIndex: number,
	def: Config.EnemyDef,
	x: number,
	z: number,
	facing: number, -- radians; 0 faces north (-Z)
	health: number,
	maxHealth: number,
	radius: number,
	speed: number,
	damage: number,
	entering: boolean, -- still walking in through an entry gap
	enterX: number,
	enterZ: number,
	attackReadyAt: number,
	fireReadyAt: number,
	teleportReadyAt: number,
	alive: boolean,
}

export type Target = { player: Player, x: number, z: number }

local EnemyService = {}

EnemyService.Killed = Signal.new() -- (enemy: Enemy)

-- Other systems plug in here at startup (avoids modules requiring each other in a loop).
EnemyService.hooks = {
	-- The placeable blocking this cell, if any.
	blockingPlaceableAt = function(_c: number, _r: number): any
		return nil
	end,
	attackPlayer = function(_player: Player, _damage: number) end,
	attackPlaceable = function(_placeable: any, _damage: number) end,
	shootFireball = function(_enemy: Enemy, _targetX: number, _targetZ: number) end,
}

local KIND_INDEX: { [string]: number } = {}
for index, kind in Config.ENEMY_KINDS do
	KIND_INDEX[kind] = index
end

local BUCKET = 4 -- spatial hash cell size for separation
local DIRECT_CHASE = 10 -- with a clear line this close, walk straight at the player

local grid: RoomGrid.RoomGrid? = nil
local living: { Enemy } = {}
local byId: { [number]: Enemy } = {}
local lastId = 0
local field: FlowField.Field? = nil
local fieldTimer = 0
local fieldDirty = true
local snapshotTimer = 0
local pendingDeaths: { number } = {}
local buckets: { [number]: { Enemy } } = {}
local rng = Random.new()
local lastClock = 0 -- run clock at the latest update, for new enemies' timers

local function angleOf(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end

local function nextId(): number
	for _ = 1, 65535 do
		lastId = lastId % 65535 + 1
		if not byId[lastId] then
			return lastId
		end
	end
	return lastId
end

local function isBlocked(g: RoomGrid.RoomGrid, c: number, r: number): (boolean, any)
	local placeable = EnemyService.hooks.blockingPlaceableAt(c, r)
	if placeable then
		return true, placeable
	end
	return g:isBlocked(c, r), nil
end

-- Whether a circle overlaps a blocked cell, and the placeable it touches (if any).
local function overlaps(g: RoomGrid.RoomGrid, x: number, z: number, radius: number): (boolean, any)
	local size = g.cellSize
	local c0 = math.floor((x - radius - g.originX) / size) + 1
	local c1 = math.floor((x + radius - g.originX) / size) + 1
	local r0 = math.floor((z - radius - g.originZ) / size) + 1
	local r1 = math.floor((z + radius - g.originZ) / size) + 1
	for r = r0, r1 do
		for c = c0, c1 do
			local blocked, placeable = isBlocked(g, c, r)
			if blocked then
				local minX = g.originX + (c - 1) * size
				local minZ = g.originZ + (r - 1) * size
				local px = math.clamp(x, minX, minX + size)
				local pz = math.clamp(z, minZ, minZ + size)
				local dx, dz = x - px, z - pz
				if dx * dx + dz * dz < radius * radius then
					return true, placeable
				end
			end
		end
	end
	return false, nil
end

-- Moves one axis at a time so enemies slide along walls. Returns the placeable
-- that stopped them, if any.
local function move(g: RoomGrid.RoomGrid, enemy: Enemy, mx: number, mz: number): any
	if overlaps(g, enemy.x, enemy.z, enemy.radius) then
		-- Already inside something (e.g. after being pushed): move freely to get out.
		enemy.x += mx
		enemy.z += mz
		return nil
	end
	local hit: any = nil
	if mx ~= 0 then
		local blocked, placeable = overlaps(g, enemy.x + mx, enemy.z, enemy.radius)
		if blocked then
			hit = placeable or hit
		else
			enemy.x += mx
		end
	end
	if mz ~= 0 then
		local blocked, placeable = overlaps(g, enemy.x, enemy.z + mz, enemy.radius)
		if blocked then
			hit = placeable or hit
		else
			enemy.z += mz
		end
	end
	return hit
end

local function bucketKey(x: number, z: number): number
	return math.floor(x / BUCKET) * 4096 + math.floor(z / BUCKET)
end

local function rebuildBuckets()
	table.clear(buckets)
	for _, enemy in living do
		local key = bucketKey(enemy.x, enemy.z)
		local bucket = buckets[key]
		if bucket then
			table.insert(bucket, enemy)
		else
			buckets[key] = { enemy }
		end
	end
end

-- Push away from overlapping neighbours.
local function separation(enemy: Enemy): (number, number)
	local sx, sz = 0, 0
	local bx, bz = math.floor(enemy.x / BUCKET), math.floor(enemy.z / BUCKET)
	for ix = bx - 1, bx + 1 do
		for iz = bz - 1, bz + 1 do
			local bucket = buckets[ix * 4096 + iz]
			if not bucket then
				continue
			end
			for _, other in bucket do
				if other == enemy then
					continue
				end
				local dx, dz = enemy.x - other.x, enemy.z - other.z
				local minDist = enemy.radius + other.radius
				local distSq = dx * dx + dz * dz
				if distSq < minDist * minDist then
					if distSq < 1e-6 then
						dx, dz = rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)
						distSq = dx * dx + dz * dz + 1e-6
					end
					local dist = math.sqrt(distSq)
					local push = (minDist - dist) / minDist
					sx += dx / dist * push
					sz += dz / dist * push
				end
			end
		end
	end
	local strength = Config.ENEMY_SEPARATION * 2
	return sx * strength, sz * strength
end

local function rebuildField(g: RoomGrid.RoomGrid, targets: { Target })
	local sources: { FlowField.CellRef } = {}
	for _, target in targets do
		local c, r = g:worldToCell(target.x, target.z)
		table.insert(sources, { c = c, r = r })
	end
	if #sources == 0 then
		field = nil
		return
	end
	field = FlowField.compute(g.width, g.height, function(c: number, r: number): number?
		if EnemyService.hooks.blockingPlaceableAt(c, r) then
			return 1 + Config.PLACEABLE_PATH_COST
		end
		if g:isBlocked(c, r) then
			return nil
		end
		return 1
	end, sources)
end

local function nearestTarget(enemy: Enemy, targets: { Target }): (Target?, number)
	local best: Target? = nil
	local bestSq = math.huge
	for _, target in targets do
		local dx, dz = target.x - enemy.x, target.z - enemy.z
		local distSq = dx * dx + dz * dz
		if distSq < bestSq then
			best, bestSq = target, distSq
		end
	end
	return best, math.sqrt(bestSq)
end

-- Vampires blink a short way toward their target.
local function teleport(g: RoomGrid.RoomGrid, enemy: Enemy, dirX: number, dirZ: number, dist: number)
	local want = math.min(enemy.def.teleportDistance or 14, dist - 3)
	if want < 3 then
		return
	end
	local wall = g:raycast(enemy.x, enemy.z, dirX, dirZ, want)
	local jump = math.min(want, wall - enemy.radius - 0.5)
	if jump < 3 then
		return
	end
	local nx, nz = enemy.x + dirX * jump, enemy.z + dirZ * jump
	if overlaps(g, nx, nz, enemy.radius) then
		return
	end
	EnemyEvent:FireAllClients("teleport", enemy.id, enemy.x, enemy.z, nx, nz)
	enemy.x, enemy.z = nx, nz
end

local function step(g: RoomGrid.RoomGrid, enemy: Enemy, dt: number, clock: number, targets: { Target })
	if enemy.entering then
		local dx, dz = enemy.enterX - enemy.x, enemy.enterZ - enemy.z
		local dist = math.sqrt(dx * dx + dz * dz)
		local stride = enemy.speed * dt
		if dist <= stride then
			enemy.x, enemy.z = enemy.enterX, enemy.enterZ
			enemy.entering = false
		else
			enemy.x += dx / dist * stride
			enemy.z += dz / dist * stride
		end
		enemy.facing = angleOf(dx, dz)
		return
	end

	local target, dist = nearestTarget(enemy, targets)
	if not target then
		return
	end
	local toX, toZ = 0, 0
	if dist > 1e-3 then
		toX, toZ = (target.x - enemy.x) / dist, (target.z - enemy.z) / dist
	end
	local clearLine = dist < 1e-3 or g:raycast(enemy.x, enemy.z, toX, toZ, dist) >= dist - 0.1

	-- Melee
	local reach = enemy.radius + Config.PLAYER_RADIUS + 0.4
	if dist <= reach and clock >= enemy.attackReadyAt then
		enemy.attackReadyAt = clock + enemy.def.attackCooldown
		EnemyService.hooks.attackPlayer(target.player, enemy.damage)
	end

	local hold = dist <= reach * 0.8 -- already touching: don't shove into the player
	if enemy.kind == "Devil" then
		if clearLine and dist <= (enemy.def.keepDistance or 0) then
			hold = true
		end
		if clearLine and dist <= (enemy.def.fireballRange or 0) and clock >= enemy.fireReadyAt then
			enemy.fireReadyAt = clock + (enemy.def.fireballInterval or 2.5) * rng:NextNumber(0.8, 1.2)
			EnemyService.hooks.shootFireball(enemy, target.x, target.z)
		end
	elseif enemy.kind == "Vampire" then
		if clock >= enemy.teleportReadyAt and dist > 7 then
			enemy.teleportReadyAt = clock + (enemy.def.teleportInterval or 4) * rng:NextNumber(0.8, 1.2)
			teleport(g, enemy, toX, toZ, dist)
		end
	end

	-- Which way to walk: straight at a nearby visible player, otherwise follow the flow field.
	local dirX, dirZ = toX, toZ
	if not (clearLine and dist < DIRECT_CHASE) and field then
		local c, r = g:worldToCell(enemy.x, enemy.z)
		local nc, nr = FlowField.next(field, c, r)
		if nc and nr then
			local cx, cz = g:cellCenter(nc, nr)
			local dx, dz = cx - enemy.x, cz - enemy.z
			local d = math.sqrt(dx * dx + dz * dz)
			if d > 1e-3 then
				dirX, dirZ = dx / d, dz / d
			end
		end
	end

	local sx, sz = separation(enemy)
	local vx = (if hold then 0 else dirX * enemy.speed) + sx
	local vz = (if hold then 0 else dirZ * enemy.speed) + sz
	local blocker = move(g, enemy, vx * dt, vz * dt)
	if blocker ~= nil and clock >= enemy.attackReadyAt then
		enemy.attackReadyAt = clock + enemy.def.attackCooldown
		EnemyService.hooks.attackPlaceable(blocker, enemy.damage)
	end

	if hold or (clearLine and dist < DIRECT_CHASE) then
		enemy.facing = angleOf(toX, toZ)
	elseif math.abs(vx) + math.abs(vz) > 0.05 then
		enemy.facing = angleOf(vx, vz)
	end
end

local function broadcast()
	local total = #living
	if total == 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	local first = 1
	while first <= total do
		local count = math.min(Snapshot.MAX_PER_PACKET, total - first + 1)
		local buf = Snapshot.create(count, now)
		for slot = 0, count - 1 do
			local enemy = living[first + slot]
			Snapshot.write(buf, slot, enemy.id, enemy.kindIndex, enemy.x, enemy.z, enemy.facing, enemy.health / enemy.maxHealth)
		end
		SnapshotRemote:FireAllClients(buf)
		first += count
	end
end

-- Sends this frame's deaths to clients in one message.
function EnemyService.flush()
	if #pendingDeaths > 0 then
		EnemyDied:FireAllClients(pendingDeaths)
		pendingDeaths = {}
	end
end

function EnemyService.start(g: RoomGrid.RoomGrid)
	EnemyService.clear()
	grid = g
	lastClock = 0
end

function EnemyService.clear()
	table.clear(living)
	table.clear(byId)
	table.clear(buckets)
	pendingDeaths = {}
	field = nil
	fieldDirty = true
	EnemyEvent:FireAllClients("clear")
end

function EnemyService.markDirty()
	fieldDirty = true
end

function EnemyService.list(): { Enemy }
	return living
end

function EnemyService.count(): number
	return #living
end

-- Spawns an enemy just outside an entry gap; it walks in by itself.
function EnemyService.spawn(kind: string, cell: RoomGrid.Cell, speedMultiplier: number, damageMultiplier: number): Enemy?
	local g = grid
	local def = Config.ENEMIES[kind]
	if not g or not def then
		return nil
	end
	local cx, cz = g:cellCenter(cell.c, cell.r)
	local ox, oz = RoomBuilder.outward(g, cell.c, cell.r)
	local back = Config.ENEMY_ENTER_DISTANCE + rng:NextNumber(0, 3)
	local side = rng:NextNumber(-0.8, 0.8)
	local enemy: Enemy = {
		id = nextId(),
		kind = kind,
		kindIndex = KIND_INDEX[kind] or 1,
		def = def,
		x = cx + ox * back + (if oz ~= 0 then side else 0),
		z = cz + oz * back + (if ox ~= 0 then side else 0),
		facing = angleOf(-ox, -oz),
		health = def.health,
		maxHealth = def.health,
		radius = def.radius,
		speed = def.speed * speedMultiplier * rng:NextNumber(0.92, 1.08),
		damage = def.damage * damageMultiplier,
		entering = true,
		enterX = cx,
		enterZ = cz,
		attackReadyAt = 0,
		fireReadyAt = 0,
		teleportReadyAt = 0,
		alive = true,
	}
	enemy.fireReadyAt = lastClock + rng:NextNumber(1, 2.5)
	enemy.teleportReadyAt = lastClock + rng:NextNumber(2, 4)
	table.insert(living, enemy)
	byId[enemy.id] = enemy
	return enemy
end

-- Applies damage; returns true if this killed the enemy. Kills are added to
-- the context so the shooter gets the points.
function EnemyService.damage(enemy: Enemy, amount: number, context: KillContext.KillContext?): boolean
	if not enemy.alive then
		return false
	end
	enemy.health -= amount
	if enemy.health > 0 then
		return false
	end
	enemy.alive = false
	local index = table.find(living, enemy)
	if index then
		living[index] = living[#living]
		living[#living] = nil
	end
	byId[enemy.id] = nil
	if context then
		table.insert(context.kills, enemy.def.score)
	end
	table.insert(pendingDeaths, enemy.id)
	table.insert(pendingDeaths, enemy.kindIndex)
	table.insert(pendingDeaths, math.round(enemy.x * 10) / 10)
	table.insert(pendingDeaths, math.round(enemy.z * 10) / 10)
	EnemyService.Killed:Fire(enemy)
	return true
end

-- One simulation step. targets are the living run players' positions.
function EnemyService.update(dt: number, clock: number, targets: { Target })
	local g = grid
	if not g then
		return
	end
	lastClock = clock
	fieldTimer -= dt
	if fieldDirty or fieldTimer <= 0 then
		rebuildField(g, targets)
		fieldTimer = Config.FLOW_FIELD_INTERVAL
		fieldDirty = false
	end
	rebuildBuckets()
	for _, enemy in living do
		step(g, enemy, dt, clock, targets)
	end
	snapshotTimer -= dt
	if snapshotTimer <= 0 then
		snapshotTimer = 1 / Config.SNAPSHOT_RATE
		broadcast()
	end
	EnemyService.flush()
end

return EnemyService
