--!strict
-- A weapon's numbers after its upgrades, with every field filled in.

local Config = require(script.Parent.Config)

export type Stats = {
	id: string,
	name: string,
	short: string,
	slot: number,
	kind: string,
	place: string?,
	fireInterval: number,
	maxAmmo: number?, -- nil = infinite
	damage: number,
	range: number,
	pierce: number,
	pellets: number,
	spread: number,
	blastRadius: number,
	speed: number,
	fuse: number,
	throwDistance: number,
	throwStep: number,
	throwMax: number,
	throwComboWindow: number,
	beam: boolean,
	tracerColor: Color3,
	turretFireInterval: number,
}

local WeaponStats = {}

local DEFAULT_TRACER = Color3.fromRGB(255, 226, 64)

-- upgrades: set of upgrade names this weapon has, e.g. { RapidFire = true }
function WeaponStats.get(weaponId: string, upgrades: { [string]: boolean }?): Stats
	local def = Config.WEAPONS[weaponId]
	assert(def, "Unknown weapon " .. weaponId)
	local stats: Stats = {
		id = weaponId,
		name = def.name,
		short = def.short,
		slot = def.slot,
		kind = def.kind,
		place = def.place,
		fireInterval = def.fireInterval,
		maxAmmo = def.maxAmmo,
		damage = def.damage or 0,
		range = def.range or 0,
		pierce = def.pierce or 1,
		pellets = def.pellets or 1,
		spread = def.spread or 0,
		blastRadius = def.blastRadius or 0,
		speed = def.speed or 0,
		fuse = def.fuse or 0,
		throwDistance = def.throwDistance or 0,
		throwStep = def.throwStep or 0,
		throwMax = def.throwMax or 0,
		throwComboWindow = def.throwComboWindow or 0,
		beam = def.beam == true,
		tracerColor = def.tracerColor or DEFAULT_TRACER,
		turretFireInterval = Config.TURRET_FIRE_INTERVAL,
	}
	if not upgrades then
		return stats
	end
	for upgrade in upgrades do
		local effect = Config.UPGRADE_EFFECTS[upgrade]
		if not effect then
			continue
		end
		if upgrade == "UnlimitedAmmo" then
			stats.maxAmmo = nil
		end
		for field, amount in effect do
			if field == "fireInterval" then
				if def.place == "turret" then
					stats.turretFireInterval *= amount
				else
					stats.fireInterval *= amount
				end
			elseif field == "maxAmmo" then
				if stats.maxAmmo then
					stats.maxAmmo = math.floor(stats.maxAmmo * amount)
				end
			elseif field == "damage" then
				stats.damage *= amount
			elseif field == "spread" then
				stats.spread *= amount
			elseif field == "pellets" then
				if stats.pellets > 1 then
					stats.pellets += amount
				end
			elseif field == "range" then
				stats.range *= amount
			elseif field == "blastRadius" then
				stats.blastRadius *= amount
			end
		end
	end
	return stats
end

-- Directions of each bullet in one shot: pellets fan out evenly across the
-- spread, with a little wobble. The seed makes the server and the shooter's
-- client pick the same wobble. Returns { {x, z}, ... } unit vectors.
function WeaponStats.pelletDirections(dirX: number, dirZ: number, stats: Stats, seed: number): { { number } }
	-- Small deterministic random generator (Park-Miller), so both sides agree.
	local state = math.max(1, math.floor(seed) % 2147483647)
	local function random(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	local spread = math.rad(stats.spread)
	local count = math.max(1, stats.pellets)
	local dirs: { { number } } = {}
	for i = 1, count do
		local angle
		if count > 1 then
			angle = -spread / 2 + spread * (i - 1) / (count - 1) + (random() - 0.5) * spread / (count * 2)
		else
			angle = (random() - 0.5) * spread
		end
		local cos, sin = math.cos(angle), math.sin(angle)
		table.insert(dirs, { dirX * cos - dirZ * sin, dirX * sin + dirZ * cos })
	end
	return dirs
end

-- "UZI + RAPID FIRE" style label for an unlock.
function WeaponStats.unlockLabel(weaponId: string, upgrade: string?, upgradeNames: { [string]: string }): string
	local def = Config.WEAPONS[weaponId]
	local name = if def then def.name else string.upper(weaponId)
	if upgrade then
		return name .. " + " .. (upgradeNames[upgrade] or string.upper(upgrade))
	end
	return "NEW WEAPON: " .. name
end

return WeaponStats
