--!strict
-- Converts between simulation pixels and Roblox world studs.
-- Pixels work like the original game: (0, 0) is the top-left corner of the level's
-- tile grid and y grows DOWNWARD. In the world, y grows upward and everything sits
-- on the Z = 0 plane, with the grid's top-left corner at (0, WORLD_TOP_Y, 0).

local Config = require(script.Parent.Config)

local S = Config.STUDS_PER_PX
local TOP = Config.WORLD_TOP_Y

local Units = {}

function Units.studs(px: number): number
	return px * S
end

function Units.toWorld(px: number, py: number, z: number?): Vector3
	return Vector3.new(px * S, TOP - py * S, z or 0)
end

function Units.toPx(world: Vector3): (number, number)
	return world.X / S, (TOP - world.Y) / S
end

return Units
