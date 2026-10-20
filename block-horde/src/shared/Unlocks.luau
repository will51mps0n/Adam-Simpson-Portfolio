--!strict
-- The unlock ladder, in the order of the original game.
-- When a player's multiplier first reaches `mult` during a run, they get the entry.
-- An entry with no `upgrade` unlocks the weapon itself; otherwise it upgrades that weapon.

export type Upgrade =
	"FastFire"
	| "RapidFire"
	| "DoubleAmmo"
	| "QuadAmmo"
	| "DoubleDamage"
	| "WideShot"
	| "WiderShot"
	| "LongShot"
	| "BigBang"
	| "BiggerBang"
	| "BigShot"
	| "UnlimitedAmmo"

export type Entry = {
	mult: number,
	weapon: string,
	upgrade: Upgrade?,
}

local Unlocks = {}

Unlocks.LADDER = {
	{ mult = 5, weapon = "uzi" },
	{ mult = 10, weapon = "shotgun" },
	{ mult = 15, weapon = "barrels" },
	{ mult = 20, weapon = "grenades" },
	{ mult = 25, weapon = "uzi", upgrade = "RapidFire" },
	{ mult = 30, weapon = "shotgun", upgrade = "BigShot" },
	{ mult = 35, weapon = "fakewalls" },
	{ mult = 40, weapon = "uzi", upgrade = "UnlimitedAmmo" },
	{ mult = 50, weapon = "mines" },
	{ mult = 55, weapon = "rockets" },
	{ mult = 60, weapon = "barrels", upgrade = "BiggerBang" },
	{ mult = 65, weapon = "grenades", upgrade = "BiggerBang" },
	{ mult = 70, weapon = "shotgun", upgrade = "RapidFire" },
	{ mult = 75, weapon = "railgun" },
	{ mult = 80, weapon = "railgun", upgrade = "RapidFire" },
	{ mult = 85, weapon = "rockets", upgrade = "RapidFire" },
	{ mult = 90, weapon = "turret" },
	{ mult = 100, weapon = "turret", upgrade = "RapidFire" },
} :: { Entry }

-- How each upgrade is written on screen, e.g. "SHOTGUN + WIDE SHOT".
Unlocks.UPGRADE_NAMES = {
	FastFire = "FAST FIRE",
	RapidFire = "RAPID FIRE",
	DoubleAmmo = "DOUBLE AMMO",
	QuadAmmo = "QUAD AMMO",
	DoubleDamage = "DOUBLE DAMAGE",
	WideShot = "WIDE SHOT",
	WiderShot = "WIDER SHOT",
	LongShot = "LONG SHOT",
	BigBang = "BIG BANG",
	BiggerBang = "BIGGER BANG",
	BigShot = "BIG SHOT",
	UnlimitedAmmo = "UNLIMITED AMMO",
} :: { [string]: string }

return Unlocks
