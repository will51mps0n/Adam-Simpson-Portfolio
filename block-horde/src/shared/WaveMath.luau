--!strict
-- Wave sizes, enemy speed and which enemy types appear in which wave.

local Config = require(script.Parent.Config)

local WaveMath = {}

function WaveMath.count(wave: number, players: number, difficulty: Config.DifficultyDef): number
	local base = Config.WAVE_BASE + Config.WAVE_PER_WAVE * wave
	local crowd = 1 + Config.WAVE_PER_EXTRA_PLAYER * math.max(0, players - 1)
	return math.max(1, math.floor(base * crowd * difficulty.count))
end

function WaveMath.speedMultiplier(wave: number, difficulty: Config.DifficultyDef): number
	return math.min(1 + Config.WAVE_SPEED_PER_WAVE * wave, Config.WAVE_SPEED_CAP) * difficulty.speed
end

-- Fraction of the wave that is each special enemy type.
function WaveMath.shares(wave: number): { [string]: number }
	local shares: { [string]: number } = {}
	for kind, mix in Config.ENEMY_MIX do
		if wave >= mix.fromWave then
			shares[kind] = math.min(mix.share + mix.growth * (wave - mix.fromWave), mix.max)
		end
	end
	return shares
end

-- Picks an enemy type for one spawn; roll is a random number in [0, 1).
function WaveMath.pickKind(wave: number, roll: number): string
	local acc = 0
	-- Fixed order so the same roll always gives the same answer.
	for _, kind in Config.ENEMY_KINDS do
		local share = WaveMath.shares(wave)[kind]
		if share then
			acc += share
			if roll < acc then
				return kind
			end
		end
	end
	return "Zombie"
end

return WaveMath
