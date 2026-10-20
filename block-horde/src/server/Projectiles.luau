--!strict
-- Things that fly: thrown grenades (land, then go off after their fuse),
-- rockets (explode on the first enemy, barrel or wall they touch) and devil
-- fireballs (hurt players, burn through zombies, set off barrels).
-- The server moves them; clients draw them from the spawn message.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hitscan = require(ReplicatedStorage.Shared.Hitscan)
local Net = require(ReplicatedStorage.Shared.Net)
local WeaponStats = require(ReplicatedStorage.Shared.WeaponStats)
local Arena = require(script.Parent.Arena)
local EnemyService = require(script.Parent.EnemyService)
local Explosions = require(script.Parent.Explosions)
local Placeables = require(script.Parent.Placeables)
local PlayerHealth = require(script.Parent.PlayerHealth)
local RunState = require(script.Parent.RunState)

local ProjectileRemote = Net.event("Projectile")

type Projectile = {
	id: number,
	kind: string, -- grenade, rocket, fireball
	owner: Player?,
	x: number,
	z: number,
	dx: number,
	dz: number,
	speed: number,
	traveled: number,
	maxRange: number,
	damage: number,
	blastRadius: number,
	explodeAt: number,
	burned: { [number]: boolean }, -- enemies a fireball already hurt
}

local Projectiles = {}

local GRENADE_FLIGHT = 0.55 -- seconds in the air (for the client's arc)

local active: { Projectile } = {}
local lastId = 0

local function add(projectile: Projectile)
	table.insert(active, projectile)
end

local function newProjectile(kind: string, owner: Player?, x: number, z: number, dx: number, dz: number): Projectile
	lastId += 1
	return {
		id = lastId,
		kind = kind,
		owner = owner,
		x = x,
		z = z,
		dx = dx,
		dz = dz,
		speed = 0,
		traveled = 0,
		maxRange = 0,
		damage = 0,
		blastRadius = 0,
		explodeAt = math.huge,
		burned = {},
	}
end

function Projectiles.throwGrenade(owner: Player, x: number, z: number, dx: number, dz: number, distance: number, stats: WeaponStats.Stats)
	local grid = Arena.grid()
	local wall = grid:raycast(x, z, dx, dz, distance)
	local land = math.max(0, math.min(distance, wall - 1.2))
	local grenade = newProjectile("grenade", owner, x + dx * land, z + dz * land, dx, dz)
	grenade.explodeAt = RunState.clock + stats.fuse
	grenade.damage = stats.damage
	grenade.blastRadius = stats.blastRadius
	add(grenade)
	ProjectileRemote:FireAllClients("spawn", grenade.id, "grenade", x, z, grenade.x, grenade.z, GRENADE_FLIGHT, stats.fuse)
end

function Projectiles.fireRocket(owner: Player, x: number, z: number, dx: number, dz: number, stats: WeaponStats.Stats)
	local rocket = newProjectile("rocket", owner, x, z, dx, dz)
	rocket.speed = stats.speed
	rocket.maxRange = stats.range
	rocket.damage = stats.damage
	rocket.blastRadius = stats.blastRadius
	add(rocket)
	ProjectileRemote:FireAllClients("spawn", rocket.id, "rocket", x, z, dx, dz, rocket.speed)
end

function Projectiles.fireball(enemy: EnemyService.Enemy, targetX: number, targetZ: number)
	local dx, dz = targetX - enemy.x, targetZ - enemy.z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 1e-3 then
		return
	end
	dx, dz = dx / dist, dz / dist
	local ball = newProjectile("fireball", nil, enemy.x + dx * (enemy.radius + 0.5), enemy.z + dz * (enemy.radius + 0.5), dx, dz)
	ball.speed = Config.FIREBALL_SPEED
	ball.maxRange = (enemy.def.fireballRange or 45) + 15
	ball.burned[enemy.id] = true
	add(ball)
	ProjectileRemote:FireAllClients("spawn", ball.id, "fireball", ball.x, ball.z, dx, dz, ball.speed)
end

local function finish(index: number, x: number, z: number)
	local projectile = active[index]
	table.remove(active, index)
	ProjectileRemote:FireAllClients("end", projectile.id, x, z)
end

local function enemyCircle(enemy: EnemyService.Enemy): (number, number, number)
	return enemy.x, enemy.z, enemy.radius + 0.3
end

local function barrelCircle(barrel: Placeables.Placeable): (number, number, number)
	return barrel.x, barrel.z, Config.BARREL_RADIUS
end

-- Moves a rocket; returns where it blew up, if it did.
local function stepRocket(rocket: Projectile, dt: number): (number?, number?)
	local grid = Arena.grid()
	local stride = rocket.speed * dt
	local wall = grid:raycast(rocket.x, rocket.z, rocket.dx, rocket.dz, stride)
	local reach = math.min(stride, wall)
	local _, enemyAt = Hitscan.cast(rocket.x, rocket.z, rocket.dx, rocket.dz, reach, EnemyService.list(), enemyCircle, 1)
	local _, barrelAt = Hitscan.cast(rocket.x, rocket.z, rocket.dx, rocket.dz, reach, Placeables.barrels(), barrelCircle, 1)
	local stop = math.min(enemyAt, barrelAt)
	if stop < reach or wall < stride then
		local at = math.max(0, stop - 0.4)
		return rocket.x + rocket.dx * at, rocket.z + rocket.dz * at
	end
	rocket.x += rocket.dx * stride
	rocket.z += rocket.dz * stride
	rocket.traveled += stride
	if rocket.traveled >= rocket.maxRange then
		return rocket.x, rocket.z
	end
	return nil, nil
end

-- Moves a fireball; returns true when it is used up.
local function stepFireball(ball: Projectile, dt: number, players: { RunState.Participant }, barrels: { Placeables.Placeable }): boolean
	local grid = Arena.grid()
	local stride = ball.speed * dt
	if grid:raycast(ball.x, ball.z, ball.dx, ball.dz, stride) < stride then
		return true
	end
	ball.x += ball.dx * stride
	ball.z += ball.dz * stride
	ball.traveled += stride

	for _, participant in players do
		local character = participant.player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local dx, dz = root.Position.X - ball.x, root.Position.Z - ball.z
			local reach = Config.FIREBALL_RADIUS + Config.PLAYER_RADIUS
			if dx * dx + dz * dz <= reach * reach then
				PlayerHealth.damage(participant.player, Config.FIREBALL_DAMAGE * (Config.DIFFICULTIES[RunState.difficulty] or Config.DIFFICULTIES.Intermediate).damage)
				return true
			end
		end
	end

	for _, barrel in barrels do
		local dx, dz = barrel.x - ball.x, barrel.z - ball.z
		local reach = Config.FIREBALL_RADIUS + Config.BARREL_RADIUS
		if dx * dx + dz * dz <= reach * reach then
			Placeables.detonate(barrel, 0, nil)
			return true
		end
	end

	-- Burns through zombies (but not other devils). Walks the list backwards
	-- because a kill swaps the last enemy into the dead one's place.
	local enemies = EnemyService.list()
	for i = #enemies, 1, -1 do
		local enemy = enemies[i]
		if enemy and enemy.kind ~= "Devil" and not ball.burned[enemy.id] and not enemy.entering then
			local dx, dz = enemy.x - ball.x, enemy.z - ball.z
			local reach = Config.FIREBALL_RADIUS + enemy.radius
			if dx * dx + dz * dz <= reach * reach then
				ball.burned[enemy.id] = true
				EnemyService.damage(enemy, Config.FIREBALL_ENEMY_DAMAGE, nil)
			end
		end
	end
	return ball.traveled >= ball.maxRange
end

function Projectiles.update(dt: number, clock: number)
	local players: { RunState.Participant }? = nil
	local barrels: { Placeables.Placeable }? = nil
	for i = #active, 1, -1 do
		local projectile = active[i]
		if projectile.kind == "grenade" then
			if clock >= projectile.explodeAt then
				finish(i, projectile.x, projectile.z)
				Explosions.explode(projectile.x, projectile.z, projectile.blastRadius, projectile.damage, projectile.owner, "grenade")
			end
		elseif projectile.kind == "rocket" then
			local bx, bz = stepRocket(projectile, dt)
			if bx and bz then
				finish(i, bx, bz)
				Explosions.explode(bx, bz, projectile.blastRadius, projectile.damage, projectile.owner, "rocket")
			end
		else
			players = players or RunState.alive()
			barrels = barrels or Placeables.barrels()
			if stepFireball(projectile, dt, players :: { RunState.Participant }, barrels :: { Placeables.Placeable }) then
				finish(i, projectile.x, projectile.z)
			end
		end
	end
end

function Projectiles.clear()
	for i = #active, 1, -1 do
		finish(i, active[i].x, active[i].z)
	end
end

function Projectiles.start()
	EnemyService.hooks.shootFireball = Projectiles.fireball
end

return Projectiles
