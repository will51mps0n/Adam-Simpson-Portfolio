--!strict
-- Each run player's multiplier, score and kills. Kills arrive in batches
-- (one shot, blast or turret burst) so several at once earn the bonus.
-- Values are mirrored onto Player attributes for the HUD and teammate list.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combo = require(ReplicatedStorage.Shared.Combo)
local Net = require(ReplicatedStorage.Shared.Net)
local Unlocks = require(ReplicatedStorage.Shared.Unlocks)
local WeaponStats = require(ReplicatedStorage.Shared.WeaponStats)
local KillContext = require(script.Parent.KillContext)
local Loadout = require(script.Parent.Loadout)

local Announce = Net.event("Announce")

type Entry = { combo: Combo.State, score: number, kills: number }

export type Result = { userId: number, name: string, score: number, kills: number }

local Scoring = {}

local entries: { [Player]: Entry } = {}

local function publish(player: Player, entry: Entry?)
	player:SetAttribute("Mult", if entry then entry.combo.base else nil)
	player:SetAttribute("MultGraceEnd", if entry then entry.combo.graceEnd else nil)
	player:SetAttribute("Score", if entry then entry.score else nil)
	player:SetAttribute("Kills", if entry then entry.kills else nil)
end

function Scoring.reset(players: { Player })
	Scoring.clear()
	for _, player in players do
		local entry = { combo = Combo.new(), score = 0, kills = 0 }
		entries[player] = entry
		publish(player, entry)
	end
end

function Scoring.add(player: Player)
	if not entries[player] then
		local entry = { combo = Combo.new(), score = 0, kills = 0 }
		entries[player] = entry
		publish(player, entry)
	end
end

function Scoring.clear()
	for player in entries do
		publish(player, nil)
	end
	table.clear(entries)
end

function Scoring.remove(player: Player)
	entries[player] = nil
	publish(player, nil)
end

-- Scores the kills collected in a context and hands out any unlocks earned.
function Scoring.flush(context: KillContext.KillContext)
	local owner = context.owner
	if #context.kills == 0 or not owner then
		return
	end
	local entry = entries[owner]
	if not entry then
		return
	end
	local points, reached = Combo.addKills(entry.combo, workspace:GetServerTimeNow(), context.kills)
	entry.score += points
	entry.kills += #context.kills
	table.clear(context.kills)
	publish(owner, entry)

	for _, unlock in reached do
		Loadout.unlock(owner, unlock)
		local label = WeaponStats.unlockLabel(unlock.weapon, unlock.upgrade, Unlocks.UPGRADE_NAMES)
		if not unlock.upgrade then
			label ..= "  [" .. Loadout.keyLabel(unlock.weapon) .. "]"
		end
		Announce:FireClient(owner, label, "unlock")
	end
end

-- Pushes every drain timer back, e.g. after a pause.
function Scoring.shiftAll(seconds: number)
	for player, entry in entries do
		Combo.shift(entry.combo, seconds)
		publish(player, entry)
	end
end

function Scoring.results(): { Result }
	local list: { Result } = {}
	for player, entry in entries do
		table.insert(list, { userId = player.UserId, name = player.DisplayName, score = entry.score, kills = entry.kills })
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	return list
end

return Scoring
