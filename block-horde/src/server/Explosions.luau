--!strict
-- Every blast in the game: grenades, rockets, barrels and mines. Damages
-- enemies (full in the middle, less at the edge), the player who caused it
-- (if SELF_DAMAGE) but never teammates (unless TEAM_DAMAGE), and sets off
-- barrels and mines in range so they chain. Clients draw the fireball.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local EnemyService = require(script.Parent.EnemyService)
local KillContext = require(script.Parent.KillContext)
local Placeables = require(script.Parent.Placeables)
local PlayerHealth = require(script.Parent.PlayerHealth)
local RunState = require(script.Parent.RunState)
local Scoring = require(script.Parent.Scoring)

local ExplosionRemote = Net.event("Explosion")

local Explosions = {}

local function falloff(dist: number, radius: number): number
	local t = math.clamp(dist / math.max(radius, 1e-3), 0, 1)
	return 1 - (1 - Config.EXPLOSION_EDGE_DAMAGE) * t
end

function Explosions.explode(x: number, z: number, radius: number, damage: number, owner: Player?, cause: string)
	local context = KillContext.new(owner)
	for _, enemy in table.clone(EnemyService.list()) do
		local dx, dz = enemy.x - x, enemy.z - z
		local dist = math.sqrt(dx * dx + dz * dz)
		if dist <= radius + enemy.radius then
			EnemyService.damage(enemy, damage * falloff(math.max(0, dist - enemy.radius), radius), context)
		end
	end

	for _, participant in RunState.alive() do
		local player = participant.player
		local isOwner = player == owner
		local hurts = if isOwner then Config.SELF_DAMAGE else (owner == nil or Config.TEAM_DAMAGE)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if hurts and root and root:IsA("BasePart") then
			local dx, dz = root.Position.X - x, root.Position.Z - z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist <= radius then
				local scale = if isOwner then Config.SELF_DAMAGE_SCALE else 1
				PlayerHealth.damage(player, damage * falloff(dist, radius) * scale)
			end
		end
	end

	for _, placeable in table.clone(Placeables.list()) do
		if placeable.alive and (placeable.kind == "barrel" or placeable.kind == "mine") then
			local dx, dz = placeable.x - x, placeable.z - z
			if dx * dx + dz * dz <= radius * radius then
				Placeables.detonate(placeable, Config.BARREL_CHAIN_DELAY, owner)
			end
		end
	end

	Scoring.flush(context)
	EnemyService.flush()
	ExplosionRemote:FireAllClients(x, z, radius, cause)
end

function Explosions.start()
	Placeables.onExplode = function(placeable: Placeables.Placeable, by: Player?)
		Explosions.explode(placeable.x, placeable.z, placeable.blastRadius, placeable.blastDamage, by or placeable.owner, placeable.kind)
	end
end

return Explosions
