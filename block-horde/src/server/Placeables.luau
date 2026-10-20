--!strict
-- Things players drop on the cell in front of them: barrels (block enemies,
-- explode when shot or caught in a blast, chaining into other barrels), fake
-- walls (only block), mines (explode when an enemy steps on them) and
-- machine-gun turrets (shoot the nearest enemy until out of ammo).
-- Blocking placeables are obstacles for enemy pathing; enemies that can't get
-- around them attack them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hitscan = require(ReplicatedStorage.Shared.Hitscan)
local Net = require(ReplicatedStorage.Shared.Net)
local PropModels = require(ReplicatedStorage.Shared.Models.PropModels)
local RoomGrid = require(ReplicatedStorage.Shared.RoomGrid)
local WeaponStats = require(ReplicatedStorage.Shared.WeaponStats)
local Arena = require(script.Parent.Arena)
local EnemyService = require(script.Parent.EnemyService)
local KillContext = require(script.Parent.KillContext)
local RunState = require(script.Parent.RunState)
local Scoring = require(script.Parent.Scoring)

local ShotFired = Net.event("ShotFired")
local ExplosionRemote = Net.event("Explosion")

export type Placeable = {
	id: number,
	kind: string, -- barrel, wall, mine, turret
	owner: Player?,
	c: number,
	r: number,
	x: number,
	z: number,
	health: number,
	alive: boolean,
	detonating: boolean,
	model: Model,
	head: Model?,
	blastRadius: number,
	blastDamage: number,
	ammo: number,
	fireInterval: number,
	fireReadyAt: number,
}

local Placeables = {}

-- Set by Explosions at startup: makes a barrel or mine go off.
Placeables.onExplode = function(_placeable: Placeable, _by: Player?) end

local BLOCKS_ENEMIES: { [string]: boolean } = { barrel = true, wall = true, turret = true }
local HEALTH: { [string]: number } = {
	barrel = Config.BARREL_HEALTH,
	wall = Config.WALL_HEALTH,
	mine = 1,
	turret = Config.TURRET_HEALTH,
}

local grid: RoomGrid.RoomGrid? = nil
local all: { Placeable } = {}
local byCell: { [number]: Placeable } = {}
local lastId = 0

local function key(c: number, r: number): number
	return r * 10000 + c
end

function Placeables.start(g: RoomGrid.RoomGrid)
	Placeables.clear()
	grid = g
	EnemyService.hooks.blockingPlaceableAt = function(c: number, r: number): any
		local placeable = byCell[key(c, r)]
		if placeable and BLOCKS_ENEMIES[placeable.kind] then
			return placeable
		end
		return nil
	end
	EnemyService.hooks.attackPlaceable = function(placeable: any, damage: number)
		Placeables.damage(placeable :: Placeable, damage, nil)
	end
end

function Placeables.clear()
	for _, placeable in all do
		placeable.alive = false
		placeable.model:Destroy()
	end
	table.clear(all)
	table.clear(byCell)
end

function Placeables.list(): { Placeable }
	return all
end

-- Living barrels, for bullets to hit.
function Placeables.barrels(): { Placeable }
	local list = {}
	for _, placeable in all do
		if placeable.kind == "barrel" and placeable.alive and not placeable.detonating then
			table.insert(list, placeable)
		end
	end
	return list
end

function Placeables.canPlace(c: number, r: number): boolean
	local g = grid
	if not g or not g:inBounds(c, r) then
		return false
	end
	local char = g:cell(c, r)
	if char == "#" or char == "S" or g:isBlocked(c, r) or byCell[key(c, r)] then
		return false
	end
	-- Not on top of a player.
	for _, participant in RunState.alive() do
		local character = participant.player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local pc, pr = g:worldToCell(root.Position.X, root.Position.Z)
			if pc == c and pr == r then
				return false
			end
		end
	end
	return true
end

function Placeables.place(owner: Player, kind: string, c: number, r: number, stats: WeaponStats.Stats): boolean
	local g = grid
	if not g or not Placeables.canPlace(c, r) then
		return false
	end
	local x, z = g:cellCenter(c, r)
	local at = CFrame.new(x, 0, z)
	local model: Model
	local head: Model? = nil
	if kind == "barrel" then
		model = PropModels.barrel(at)
	elseif kind == "wall" then
		model = PropModels.wall(at)
	elseif kind == "mine" then
		model = PropModels.mine(at)
	elseif kind == "turret" then
		model, head = PropModels.turret(at)
	else
		return false
	end
	lastId += 1
	model:SetAttribute("Kind", kind)
	model:SetAttribute("CellC", c)
	model:SetAttribute("CellR", r)
	model.Parent = Arena.props()

	local placeable: Placeable = {
		id = lastId,
		kind = kind,
		owner = owner,
		c = c,
		r = r,
		x = x,
		z = z,
		health = HEALTH[kind] or 50,
		alive = true,
		detonating = false,
		model = model,
		head = head,
		blastRadius = stats.blastRadius,
		blastDamage = stats.damage,
		ammo = Config.TURRET_AMMO,
		fireInterval = stats.turretFireInterval,
		fireReadyAt = 0,
	}
	table.insert(all, placeable)
	byCell[key(c, r)] = placeable
	if kind == "wall" then
		g:setBlocked(c, r, true) -- fake walls stop bullets too
	end
	EnemyService.markDirty()
	return true
end

function Placeables.remove(placeable: Placeable)
	if not placeable.alive then
		return
	end
	placeable.alive = false
	local index = table.find(all, placeable)
	if index then
		table.remove(all, index)
	end
	if byCell[key(placeable.c, placeable.r)] == placeable then
		byCell[key(placeable.c, placeable.r)] = nil
	end
	local g = grid
	if placeable.kind == "wall" and g then
		g:setBlocked(placeable.c, placeable.r, false)
	end
	placeable.model:Destroy()
	EnemyService.markDirty()
end

-- Barrels and mines go off after `delay` seconds; `by` gets the credit
-- (defaults to whoever placed it).
function Placeables.detonate(placeable: Placeable, delay: number, by: Player?)
	if placeable.detonating or not placeable.alive then
		return
	end
	placeable.detonating = true
	task.delay(delay, function()
		if not placeable.alive then
			return
		end
		Placeables.remove(placeable)
		Placeables.onExplode(placeable, by)
	end)
end

function Placeables.damage(placeable: Placeable, amount: number, by: Player?)
	if not placeable.alive or placeable.detonating then
		return
	end
	placeable.health -= amount
	if placeable.health > 0 then
		return
	end
	if placeable.kind == "barrel" or placeable.kind == "mine" then
		Placeables.detonate(placeable, 0, by)
	else
		Placeables.remove(placeable)
		ExplosionRemote:FireAllClients(placeable.x, placeable.z, 0, "break")
	end
end

local function enemyCircle(enemy: EnemyService.Enemy): (number, number, number)
	return enemy.x, enemy.z, enemy.radius
end

local function updateTurret(g: RoomGrid.RoomGrid, turret: Placeable, clock: number)
	if clock < turret.fireReadyAt then
		return
	end
	-- Nearest enemy in range with a clear line of fire.
	local target: EnemyService.Enemy? = nil
	local bestSq = Config.TURRET_RANGE * Config.TURRET_RANGE
	for _, enemy in EnemyService.list() do
		local dx, dz = enemy.x - turret.x, enemy.z - turret.z
		local distSq = dx * dx + dz * dz
		if distSq < bestSq and not enemy.entering then
			local dist = math.sqrt(distSq)
			if dist < 0.5 or g:raycast(turret.x, turret.z, dx / dist, dz / dist, dist) >= dist - 0.5 then
				target, bestSq = enemy, distSq
			end
		end
	end
	if not target then
		return
	end
	local dist = math.sqrt(bestSq)
	local dx, dz = (target.x - turret.x) / math.max(dist, 1e-3), (target.z - turret.z) / math.max(dist, 1e-3)

	local context = KillContext.new(turret.owner)
	local wall = g:raycast(turret.x, turret.z, dx, dz, Config.TURRET_RANGE)
	local hits, travel = Hitscan.cast(turret.x, turret.z, dx, dz, wall, EnemyService.list(), enemyCircle, 1)
	for _, enemy in hits do
		EnemyService.damage(enemy, Config.TURRET_DAMAGE, context)
	end
	Scoring.flush(context)

	local facing = math.atan2(-dx, -dz)
	local head = turret.head
	if head then
		head:PivotTo(CFrame.new(turret.x, 3, turret.z) * CFrame.Angles(0, facing, 0))
	end
	local muzzle = Vector3.new(turret.x + dx * 2.4, 3.05, turret.z + dz * 2.4)
	local finish = Vector3.new(turret.x + dx * math.max(travel, 2.5), 3.05, turret.z + dz * math.max(travel, 2.5))
	ShotFired:FireAllClients(nil, "turret", muzzle, { finish }, 0)

	turret.fireReadyAt = clock + turret.fireInterval
	turret.ammo -= 1
	if turret.ammo <= 0 then
		Placeables.remove(turret)
		ExplosionRemote:FireAllClients(turret.x, turret.z, 0, "break")
	end
end

local function updateMine(mine: Placeable)
	local reach = Config.MINE_TRIGGER_RADIUS
	for _, enemy in EnemyService.list() do
		if not enemy.entering then
			local dx, dz = enemy.x - mine.x, enemy.z - mine.z
			local r = reach + enemy.radius
			if dx * dx + dz * dz <= r * r then
				Placeables.detonate(mine, 0, nil)
				return
			end
		end
	end
end

function Placeables.update(clock: number)
	local g = grid
	if not g then
		return
	end
	for _, placeable in table.clone(all) do
		if not placeable.alive or placeable.detonating then
			continue
		end
		if placeable.kind == "turret" then
			updateTurret(g, placeable, clock)
		elseif placeable.kind == "mine" then
			updateMine(placeable)
		end
	end
end

return Placeables
