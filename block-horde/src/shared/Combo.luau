--!strict
-- The kill multiplier. Every kill adds 1, several kills from one shot or blast
-- add a bonus point per extra kill, and after MULT_DECAY_DELAY without a kill
-- it drains at MULT_DECAY_RATE per second down to 1.
--
-- The value is stored as (base, graceEnd) so anyone can work out the current
-- value at any time: the server for scoring, clients for the HUD.

local Config = require(script.Parent.Config)
local Unlocks = require(script.Parent.Unlocks)

export type State = {
	base: number, -- multiplier right after the last kill
	graceEnd: number, -- time the drain starts
	nextUnlock: number, -- index into Unlocks.LADDER of the next unlock to earn
}

local Combo = {}

function Combo.new(): State
	return { base = 1, graceEnd = 0, nextUnlock = 1 }
end

function Combo.valueAt(base: number, graceEnd: number, now: number): number
	if now <= graceEnd then
		return base
	end
	return math.max(1, base - Config.MULT_DECAY_RATE * (now - graceEnd))
end

-- Registers the kills from one shot or blast. killValues holds each enemy's
-- base score. Returns the points earned and any ladder entries newly reached.
function Combo.addKills(state: State, now: number, killValues: { number }): (number, { Unlocks.Entry })
	local mult = Combo.valueAt(state.base, state.graceEnd, now)
	local points = 0
	for _, value in killValues do
		mult += 1
		points += value * math.floor(mult)
	end
	mult += math.max(0, #killValues - 1)
	state.base = mult
	state.graceEnd = now + Config.MULT_DECAY_DELAY

	local reached: { Unlocks.Entry } = {}
	while true do
		local entry = Unlocks.LADDER[state.nextUnlock]
		if not entry or math.floor(mult) < entry.mult then
			break
		end
		table.insert(reached, entry)
		state.nextUnlock += 1
	end
	return points, reached
end

-- Moves the drain start later, e.g. after the game was paused.
function Combo.shift(state: State, seconds: number)
	state.graceEnd += seconds
end

return Combo
