--!strict
-- The tile shapes a level grid can use, and the character that draws each one.
--
--   .  empty
--   #  full block
--
--   45-degree slopes, named by the corner that is solid:
--   /  bottom-right solid   a floor rising to the right
--   \  bottom-left solid    a floor rising to the left
--   F  top-left solid       a ceiling corner (top bar + left stem, like the letter F)
--   7  top-right solid      a ceiling corner (top bar + right stem, like the digit 7)
--
--   Quarter circles, named by their solid corner using the keyboard layout   Q W
--                                                                            A S
--   q w a s   convex: a quarter of a round disc (the rounded corner of a block)
--   Q W A S   concave: a block with a round bite taken out (a quarter-pipe)
--
-- Geometry here is in tile-local pixels: (0, 0) is the tile's top-left corner,
-- (TILE_PX, TILE_PX) its bottom-right, and y grows downward.

local Config = require(script.Parent.Config)

local T = Config.TILE_PX

export type Kind = "empty" | "full" | "slope" | "convex" | "concave"

export type Shape = {
	char: string,
	name: string,
	kind: Kind,
	-- The solid corner: sx is -1 (left) or 1 (right), sy is -1 (top) or 1 (bottom).
	-- Both are 0 for empty and full tiles.
	sx: number,
	sy: number,
}

local TileShapes = {}

local function shape(char: string, name: string, kind: Kind, sx: number, sy: number): Shape
	return { char = char, name = name, kind = kind, sx = sx, sy = sy }
end

-- Every shape in a fixed order (the level editor palette will use this order too).
TileShapes.ALL = {
	shape(".", "empty", "empty", 0, 0),
	shape("#", "full", "full", 0, 0),
	shape("/", "slope bottom-right", "slope", 1, 1),
	shape("\\", "slope bottom-left", "slope", -1, 1),
	shape("F", "slope top-left", "slope", -1, -1),
	shape("7", "slope top-right", "slope", 1, -1),
	shape("q", "convex top-left", "convex", -1, -1),
	shape("w", "convex top-right", "convex", 1, -1),
	shape("a", "convex bottom-left", "convex", -1, 1),
	shape("s", "convex bottom-right", "convex", 1, 1),
	shape("Q", "concave top-left", "concave", -1, -1),
	shape("W", "concave top-right", "concave", 1, -1),
	shape("A", "concave bottom-left", "concave", -1, 1),
	shape("S", "concave bottom-right", "concave", 1, 1),
}

TileShapes.byChar = {} :: { [string]: Shape }
for _, s in TileShapes.ALL do
	TileShapes.byChar[s.char] = s
end

TileShapes.EMPTY = TileShapes.byChar["."]
TileShapes.FULL = TileShapes.byChar["#"]

local function corner(sx: number, sy: number): Vector2
	return Vector2.new(if sx > 0 then T else 0, if sy > 0 then T else 0)
end

-- Points along a quarter circle around `center`, from `from` to `to` (both on the circle).
local function arc(center: Vector2, from: Vector2, to: Vector2, segments: number): { Vector2 }
	local u = (from - center) / T
	local v = (to - center) / T
	local points = {}
	for i = 0, segments do
		local angle = (i / segments) * math.pi / 2
		points[i + 1] = center + (u * math.cos(angle) + v * math.sin(angle)) * T
	end
	return points
end

-- The solid area of a slope or curve tile as a polygon. The first point is always the
-- solid corner and every other point can be seen from it, so the polygon can be cut
-- into a fan of triangles around that first point.
function TileShapes.polygon(s: Shape, segments: number): { Vector2 }
	local solid = corner(s.sx, s.sy)
	local alongX = corner(-s.sx, s.sy) -- the corner beside the solid one, same row
	local alongY = corner(s.sx, -s.sy) -- the corner beside the solid one, same column
	local opposite = corner(-s.sx, -s.sy)

	local points: { Vector2 }
	if s.kind == "slope" then
		points = { alongX, alongY }
	elseif s.kind == "convex" then
		points = arc(solid, alongX, alongY, segments)
	elseif s.kind == "concave" then
		points = arc(opposite, alongX, alongY, segments)
	else
		error(`TileShapes.polygon: '{s.char}' is not a slope or curve`)
	end
	table.insert(points, 1, solid)
	return points
end

-- The polygon cut into triangles, each as three tile-local points.
function TileShapes.triangles(s: Shape, segments: number): { { Vector2 } }
	local poly = TileShapes.polygon(s, segments)
	local tris = {}
	for i = 2, #poly - 1 do
		table.insert(tris, { poly[1], poly[i], poly[i + 1] })
	end
	return tris
end

return TileShapes
