--!strict
-- Types shared by the enemy modules.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local LevelGrid = require(Shared.LevelGrid)

-- A living ninja, as last reported by its player.
export type NinjaInfo = {
	x: number,
	y: number,
	vx: number,
	vy: number,
	grounded: boolean,
}

-- Everything an enemy can see and do during one server tick.
export type Ctx = {
	grid: LevelGrid.Grid,
	frames: number, -- how many 60 Hz frames this tick covers
	dt: number, -- seconds this tick covers
	now: number, -- server time (workspace:GetServerTimeNow())
	ninjas: { NinjaInfo },
	emit: (kind: string, ...any) -> (), -- tells clients about shots, explosions, beeps
	blocked: (cx: number, cy: number) -> boolean, -- cells drones can't enter
	spawnRocket: (x: number, y: number, angle: number) -> (),
}

-- id: position in the level's object list. x, y: px. a and s go into snapshots: an angle
-- (or other number) and a small state code each enemy type defines.
export type Enemy = {
	id: number,
	kind: string,
	x: number,
	y: number,
	a: number,
	s: number,
	step: (Enemy, Ctx) -> (),
	[string]: any,
}

return {}
