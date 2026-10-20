--!strict
-- Which weapons and upgrades each player has this run, and their ammo.
-- Everyone starts a run with only the infinite-ammo pistol.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Unlocks = require(ReplicatedStorage.Shared.Unlocks)
local WeaponStats = require(ReplicatedStorage.Shared.WeaponStats)

local WeaponState = Net.event("WeaponState")

type State = {
	owned: { [string]: boolean },
	upgrades: { [string]: { [string]: boolean } },
	ammo: { [string]: number },
	dirty: boolean,
}

local Loadout = {}

local states: { [Player]: State } = {}

-- Sends the player's weapons, upgrades and ammo to their client.
function Loadout.sync(player: Player)
	local state = states[player]
	local owned, upgrades = {}, {}
	if state then
		for id in state.owned do
			table.insert(owned, id)
		end
		for id, set in state.upgrades do
			local names = {}
			for name in set do
				table.insert(names, name)
			end
			upgrades[id] = names
		end
		state.dirty = false
	end
	WeaponState:FireClient(player, owned, if state then state.ammo else {}, upgrades)
end

function Loadout.reset(player: Player)
	states[player] = { owned = { pistol = true }, upgrades = {}, ammo = {}, dirty = false }
	Loadout.sync(player)
end

function Loadout.clear(player: Player)
	states[player] = nil
	Loadout.sync(player)
end

function Loadout.owns(player: Player, weaponId: string): boolean
	local state = states[player]
	return state ~= nil and state.owned[weaponId] == true
end

function Loadout.stats(player: Player, weaponId: string): WeaponStats.Stats
	local state = states[player]
	return WeaponStats.get(weaponId, if state then state.upgrades[weaponId] else nil)
end

-- Spends one shot. Returns false if the weapon is empty.
function Loadout.useAmmo(player: Player, weaponId: string): boolean
	local state = states[player]
	if not state then
		return false
	end
	if Loadout.stats(player, weaponId).maxAmmo == nil then
		return true
	end
	local left = state.ammo[weaponId] or 0
	if left <= 0 then
		return false
	end
	state.ammo[weaponId] = left - 1
	state.dirty = true
	return true
end

-- Asks for a resync, e.g. after the server turned down a shot the client already counted.
function Loadout.markDirty(player: Player)
	local state = states[player]
	if state then
		state.dirty = true
	end
end

-- Gives back a shot that could not be used (e.g. nowhere to place a barrel).
function Loadout.refund(player: Player, weaponId: string)
	local state = states[player]
	if state and Loadout.stats(player, weaponId).maxAmmo ~= nil then
		state.ammo[weaponId] = (state.ammo[weaponId] or 0) + 1
		state.dirty = true
	end
end

function Loadout.unlock(player: Player, entry: Unlocks.Entry)
	local state = states[player]
	if not state then
		return
	end
	if entry.upgrade then
		local set = state.upgrades[entry.weapon] or {}
		set[entry.upgrade] = true
		state.upgrades[entry.weapon] = set
	else
		state.owned[entry.weapon] = true
	end
	-- New weapons and ammo upgrades come fully loaded.
	local maxAmmo = Loadout.stats(player, entry.weapon).maxAmmo
	if maxAmmo and (entry.upgrade == nil or entry.upgrade == "DoubleAmmo" or entry.upgrade == "QuadAmmo") then
		state.ammo[entry.weapon] = maxAmmo
	end
	Loadout.sync(player)
end

-- Ammo box pickup: tops up every owned weapon by a fraction of its max.
function Loadout.refill(player: Player, fraction: number)
	local state = states[player]
	if not state then
		return
	end
	for id in state.owned do
		local maxAmmo = Loadout.stats(player, id).maxAmmo
		if maxAmmo then
			state.ammo[id] = math.min(maxAmmo, (state.ammo[id] or 0) + math.ceil(maxAmmo * fraction))
		end
	end
	Loadout.sync(player)
end

function Loadout.start()
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	-- Correct the client's ammo count now and then; it counts down on its own between syncs.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, state in states do
				if state.dirty and player.Parent then
					Loadout.sync(player)
				end
			end
		end
	end)
end

-- Number key label for a weapon, e.g. "2" or "0".
function Loadout.keyLabel(weaponId: string): string
	local def = Config.WEAPONS[weaponId]
	if not def then
		return "?"
	end
	return tostring(def.slot % 10)
end

return Loadout
