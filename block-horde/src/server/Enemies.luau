--!strict
-- The server's enemy table. Enemies are plain data (no Humanoids), so the
-- server can run hundreds of them. Hit tests treat each one as a circle.
-- Milestone 1 only holds practice dummies; Milestone 3 adds movement and
-- replication to clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

export type Enemy = {
	id: number,
	kind: string,
	x: number,
	z: number,
	radius: number,
	health: number,
	maxHealth: number,
	alive: boolean,
}

local Enemies = {}

Enemies.Hit = Signal.new() -- (enemy: Enemy, attacker: Player?)
Enemies.Killed = Signal.new() -- (enemy: Enemy, attacker: Player?)

local living: { Enemy } = {}
local lastId = 0

function Enemies.spawn(kind: string, x: number, z: number, health: number, radius: number): Enemy
	lastId += 1
	local enemy: Enemy = {
		id = lastId,
		kind = kind,
		x = x,
		z = z,
		radius = radius,
		health = health,
		maxHealth = health,
		alive = true,
	}
	table.insert(living, enemy)
	return enemy
end

-- All living enemies. Do not modify the returned list.
function Enemies.list(): { Enemy }
	return living
end

-- Applies damage and returns true if this killed the enemy.
function Enemies.damage(enemy: Enemy, amount: number, attacker: Player?): boolean
	if not enemy.alive then
		return false
	end
	enemy.health -= amount
	if enemy.health > 0 then
		Enemies.Hit:Fire(enemy, attacker)
		return false
	end
	enemy.alive = false
	local index = table.find(living, enemy)
	if index then
		living[index] = living[#living]
		living[#living] = nil
	end
	Enemies.Killed:Fire(enemy, attacker)
	return true
end

return Enemies
