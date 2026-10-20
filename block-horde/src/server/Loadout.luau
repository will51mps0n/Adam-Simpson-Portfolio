--!strict
-- Which weapons each player owns this run, and their ammo.
-- Everyone starts with only the infinite-ammo pistol.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local WeaponState = Net.event("WeaponState")

type State = {
	owned: { [string]: boolean },
	ammo: { [string]: number },
}

local Loadout = {}

local states: { [Player]: State } = {}

-- Sends the player's owned weapons and ammo to their client.
function Loadout.sync(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local owned = {}
	for id in state.owned do
		table.insert(owned, id)
	end
	WeaponState:FireClient(player, owned, state.ammo)
end

function Loadout.reset(player: Player)
	states[player] = { owned = { pistol = true }, ammo = {} }
	Loadout.sync(player)
end

function Loadout.owns(player: Player, weaponId: string): boolean
	local state = states[player]
	return state ~= nil and state.owned[weaponId] == true
end

-- Spends one shot of ammo. Returns false if the weapon is empty.
function Loadout.useAmmo(player: Player, weaponId: string): boolean
	local weapon = Config.WEAPONS[weaponId]
	local state = states[player]
	if not weapon or not state then
		return false
	end
	if weapon.maxAmmo == nil then
		return true
	end
	local left = state.ammo[weaponId] or 0
	if left <= 0 then
		return false
	end
	state.ammo[weaponId] = left - 1
	return true
end

function Loadout.start()
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return Loadout
