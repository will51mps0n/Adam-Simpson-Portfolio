--!strict
-- All of a level's moving enemies, simulated on the server and sent to clients as
-- snapshots. (Mines never move, so clients handle them from the level data alone.)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Levels = require(Shared.Levels)
local LevelGrid = require(Shared.LevelGrid)
local LevelObjects = require(Shared.Sim.LevelObjects)
local Protocol = require(Shared.Net.Protocol)
local Types = require(script.Types)
local Drones = require(script.Drones)
local FloorGuard = require(script.FloorGuard)
local Thwump = require(script.Thwump)
local Turrets = require(script.Turrets)

export type State = {
	list: { Types.Enemy },
	rockets: { Turrets.Rocket },
	nextRocketId: number,
	blocked: (cx: number, cy: number) -> boolean,
}

local Enemies = {}

Enemies.FIRST_ROCKET_ID = 1000

function Enemies.create(def: Levels.LevelDef, grid: LevelGrid.Grid): State
	-- Drones stay in open tiles and never path through doorways.
	local doorCells: { [number]: boolean } = {}
	for _, obj in def.objects do
		if LevelObjects.isDoor(obj) then
			doorCells[obj.y * 65536 + obj.x] = true
		end
	end
	local function blocked(cx: number, cy: number): boolean
		return LevelGrid.shapeAt(grid, cx, cy).kind ~= "empty" or doorCells[cy * 65536 + cx] == true
	end

	local list = {}
	for id, obj in def.objects do
		local kind = obj.type
		local enemy: Types.Enemy? = nil
		if kind == "zapDrone" then
			enemy = Drones.zap(obj, id, blocked)
		elseif kind == "laserDrone" then
			enemy = Drones.laser(obj, id, blocked)
		elseif kind == "chaingunDrone" then
			enemy = Drones.chaingun(obj, id, blocked)
		elseif kind == "floorGuard" then
			enemy = FloorGuard.new(obj, id, grid)
		elseif kind == "thwump" then
			enemy = Thwump.new(obj, id)
		elseif kind == "gaussTurret" then
			enemy = Turrets.gauss(obj, id)
		elseif kind == "rocketTurret" then
			enemy = Turrets.rocket(obj, id)
		end
		if enemy then
			table.insert(list, enemy)
		end
	end
	return { list = list, rockets = {}, nextRocketId = Enemies.FIRST_ROCKET_ID, blocked = blocked }
end

-- `ctx` without `blocked` / `spawnRocket`; they're filled in here.
function Enemies.step(state: State, ctx: Types.Ctx)
	ctx.blocked = state.blocked
	ctx.spawnRocket = function(x: number, y: number, angle: number)
		local id = state.nextRocketId
		state.nextRocketId = if id >= 65000 then Enemies.FIRST_ROCKET_ID else id + 1
		table.insert(state.rockets, { id = id, x = x, y = y, a = angle, age = 0 })
	end
	for _, e in state.list do
		e.step(e, ctx)
	end
	local i = 1
	while i <= #state.rockets do
		if Turrets.stepRocket(state.rockets[i], ctx) then
			table.remove(state.rockets, i)
		else
			i += 1
		end
	end
end

-- A client says one of our rockets hit its ninja: blow it up right there.
function Enemies.explodeRocket(state: State, ctx: Types.Ctx, id: number, x: number, y: number): boolean
	for i, r in state.rockets do
		if r.id == id then
			table.remove(state.rockets, i)
			ctx.emit("explosion", ctx.now, x, y, id)
			return true
		end
	end
	return false
end

function Enemies.snapshot(state: State): { Protocol.Entry }
	local entries: { Protocol.Entry } = {}
	for _, e in state.list do
		table.insert(entries, { id = e.id, x = e.x, y = e.y, a = e.a, s = e.s })
	end
	for _, r in state.rockets do
		table.insert(entries, { id = r.id, x = r.x, y = r.y, a = r.a, s = 0 })
	end
	return entries
end

return Enemies
