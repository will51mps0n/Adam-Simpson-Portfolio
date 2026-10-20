--!strict
-- Damage to run players and their health regeneration
-- (HEALTH_REGEN_PER_SEC after HEALTH_REGEN_DELAY seconds without damage).
-- Roblox's own slow regen is switched off by the empty Health script in
-- StarterCharacterScripts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RunState = require(script.Parent.RunState)

local PlayerHurt = Net.event("PlayerHurt")

local PlayerHealth = {}

local lastHurt: { [Player]: number } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function PlayerHealth.damage(player: Player, amount: number)
	local participant = RunState.participants[player]
	local humanoid = humanoidOf(player)
	if not participant or not participant.alive or not humanoid or humanoid.Health <= 0 or amount <= 0 then
		return
	end
	humanoid:TakeDamage(amount)
	lastHurt[player] = RunState.clock
	PlayerHurt:FireClient(player, amount)
end

function PlayerHealth.heal(player: Player)
	local humanoid = humanoidOf(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end
	lastHurt[player] = nil
end

function PlayerHealth.update(dt: number)
	for _, participant in RunState.alive() do
		local humanoid = humanoidOf(participant.player)
		if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
			local since = RunState.clock - (lastHurt[participant.player] or -math.huge)
			if since >= Config.HEALTH_REGEN_DELAY then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.HEALTH_REGEN_PER_SEC * dt)
			end
		end
	end
end

function PlayerHealth.forget(player: Player)
	lastHurt[player] = nil
end

return PlayerHealth
