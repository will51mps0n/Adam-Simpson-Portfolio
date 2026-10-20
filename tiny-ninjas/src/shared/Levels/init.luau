--!strict
-- All built-in levels. Each level is a ModuleScript in this folder that returns a LevelDef.
--
-- A level is an ASCII tile grid (see TileShapes for the characters) plus a list of
-- objects. Object positions are in tiles: x = 4, y = 7 is the middle of column 4,
-- row 7 (counting from 0 at the top-left); halves like x = 4.5 sit between two tiles.

export type ObjectDef = {
	type: string, -- "spawn", "gold", "exitSwitch", "exitDoor", ... (more in later milestones)
	x: number,
	y: number,
	[string]: any, -- extra options, such as a direction or a patrol path
}

export type LevelDef = {
	id: string,
	name: string,
	mode: string, -- "solo", "coop", "race", "goldrush", "hunters" or "test"
	order: number?, -- sort position in level lists
	camera: ("fixed" | "follow")?, -- default: fixed if it fits one 31 x 23 screen, else follow
	grid: string,
	objects: { ObjectDef },
}

local Levels = {}

local byId: { [string]: LevelDef } = {}
local all: { LevelDef } = {}

for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		local def = (require :: any)(child) :: LevelDef
		if byId[def.id] then
			error(`Two levels use the id "{def.id}"`)
		end
		byId[def.id] = def
		table.insert(all, def)
	end
end

table.sort(all, function(a, b)
	local ao, bo = a.order or math.huge, b.order or math.huge
	if ao ~= bo then
		return ao < bo
	end
	return a.id < b.id
end)

function Levels.get(id: string): LevelDef
	local def = byId[id]
	if not def then
		error(`No level with id "{id}"`)
	end
	return def
end

function Levels.list(mode: string?): { LevelDef }
	local result = {}
	for _, def in all do
		if mode == nil or def.mode == mode then
			table.insert(result, def)
		end
	end
	return result
end

return Levels
