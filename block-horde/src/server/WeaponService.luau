--!strict
-- Checks every shot a client asks for (in a run, alive, owns the weapon, fire
-- rate, ammo) and carries it out: hitscan bullets against the enemy table and
-- barrels, thrown grenades, rockets, or dropping a placeable on the cell in
-- front. Hitscan shots are echoed to every client so they can draw tracers;
-- the shooter already drew theirs instantly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hitscan = require(ReplicatedStorage.Shared.Hitscan)
local Net = require(ReplicatedStorage.Shared.Net)
local WeaponStats = require(ReplicatedStorage.Shared.WeaponStats)
local Arena = require(script.Parent.Arena)
local EnemyService = require(script.Parent.EnemyService)
local KillContext = require(script.Parent.KillContext)
local Loadout = require(script.Parent.Loadout)
local Placeables = require(script.Parent.Placeables)
local Projectiles = require(script.Parent.Projectiles)
local RunState = require(script.Parent.RunState)
local Scoring = require(script.Parent.Scoring)

local Fire = Net.event("Fire")
local ShotFired = Net.event("ShotFired")

local WeaponService = {}

-- Per player, per weapon: the earliest time the next shot is allowed.
local nextShotAt: { [Player]: { [string]: number } } = {}
-- Grenades thrown in quick succession fly further.
local lastThrow: { [Player]: { at: number, distance: number } } = {}

local function enemyCircle(enemy: EnemyService.Enemy): (number, number, number)
	return enemy.x, enemy.z, enemy.radius
end

local function barrelCircle(barrel: Placeables.Placeable): (number, number, number)
	return barrel.x, barrel.z, Config.BARREL_RADIUS
end

-- Fires every pellet of a hitscan shot. Returns where each visible bullet stopped.
local function fireHitscan(player: Player, stats: WeaponStats.Stats, pos: Vector3, dirX: number, dirZ: number, seed: number, context: KillContext.KillContext): { Vector3 }
	local grid = Arena.grid()
	local y = pos.Y + Config.MUZZLE_HEIGHT
	local endpoints: { Vector3 } = {}
	for _, dir in WeaponStats.pelletDirections(dirX, dirZ, stats, seed) do
		local dx, dz = dir[1], dir[2]
		local wall = grid:raycast(pos.X, pos.Z, dx, dz, stats.range)
		local enemies, _, enemyDists = Hitscan.cast(pos.X, pos.Z, dx, dz, wall, EnemyService.list(), enemyCircle, math.huge)
		local barrels, _, barrelDists = Hitscan.cast(pos.X, pos.Z, dx, dz, wall, Placeables.barrels(), barrelCircle, math.huge)

		-- Walk the hits nearest first until the bullet has gone through `pierce` things.
		local ei, bi, taken = 1, 1, 0
		local travel = wall
		while taken < stats.pierce do
			local enemyDist, barrelDist = enemyDists[ei], barrelDists[bi]
			if enemyDist == nil and barrelDist == nil then
				break
			end
			if barrelDist == nil or (enemyDist ~= nil and enemyDist <= barrelDist) then
				EnemyService.damage(enemies[ei], stats.damage, context)
				travel = enemyDist
				ei += 1
			else
				Placeables.detonate(barrels[bi], 0, player)
				travel = barrelDist
				bi += 1
			end
			taken += 1
		end
		if taken < stats.pierce then
			travel = wall
		end
		if travel > Config.MUZZLE_FORWARD then
			table.insert(endpoints, Vector3.new(pos.X + dx * travel, y, pos.Z + dz * travel))
		end
	end
	return endpoints
end

local function onFire(player: Player, weaponId: unknown, dirX: unknown, dirZ: unknown, seed: unknown)
	if typeof(weaponId) ~= "string" or typeof(dirX) ~= "number" or typeof(dirZ) ~= "number" then
		return
	end
	if not Config.WEAPONS[weaponId] or not RunState.canAct(player) or not Loadout.owns(player, weaponId) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local length = math.sqrt(dirX * dirX + dirZ * dirZ)
	if length ~= length or length < 0.01 then
		return -- NaN or zero direction
	end
	local dx, dz = dirX / length, dirZ / length
	local shotSeed = if typeof(seed) == "number" and seed == seed then math.floor(math.abs(seed)) % 1073741824 else 1

	local stats = Loadout.stats(player, weaponId)

	-- Fire rate check, with half an interval of slack for network jitter.
	local now = os.clock()
	local times = nextShotAt[player]
	if not times then
		times = {}
		nextShotAt[player] = times
	end
	local allowedAt = times[weaponId] or 0
	if now < allowedAt - stats.fireInterval * 0.5 then
		return
	end
	times[weaponId] = math.max(allowedAt, now) + stats.fireInterval

	if not Loadout.useAmmo(player, weaponId) then
		return
	end

	local pos = root.Position
	if stats.kind == "hitscan" then
		local context = KillContext.new(player)
		local endpoints = fireHitscan(player, stats, pos, dx, dz, shotSeed, context)
		Scoring.flush(context)
		EnemyService.flush()
		local muzzle = Vector3.new(pos.X + dx * Config.MUZZLE_FORWARD, pos.Y + Config.MUZZLE_HEIGHT, pos.Z + dz * Config.MUZZLE_FORWARD)
		ShotFired:FireAllClients(player, weaponId, muzzle, endpoints, shotSeed)
	elseif stats.kind == "grenade" then
		local last = lastThrow[player]
		local distance = stats.throwDistance
		if last and now - last.at <= stats.throwComboWindow then
			distance = math.min(last.distance + stats.throwStep, stats.throwMax)
		end
		lastThrow[player] = { at = now, distance = distance }
		Projectiles.throwGrenade(player, pos.X, pos.Z, dx, dz, distance, stats)
	elseif stats.kind == "rocket" then
		Projectiles.fireRocket(player, pos.X, pos.Z, dx, dz, stats)
	elseif stats.kind == "place" then
		local grid = Arena.grid()
		local ahead = grid.cellSize * 1.1
		local c, r = grid:worldToCell(pos.X + dx * ahead, pos.Z + dz * ahead)
		if not Placeables.place(player, stats.place or "", c, r, stats) then
			Loadout.refund(player, weaponId)
		end
	end
end

function WeaponService.start()
	Fire.OnServerEvent:Connect(onFire)
	Players.PlayerRemoving:Connect(function(player)
		nextShotAt[player] = nil
		lastThrow[player] = nil
	end)
end

return WeaponService
