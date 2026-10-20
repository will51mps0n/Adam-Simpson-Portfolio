--!strict
-- Collision against the tile grid and moving solids (doors, thwumps, bounce blocks).
--
-- Everything works with signed distances: for any point we can ask "how far away is the
-- nearest solid surface, and which way is out?". A circle overlaps the level wherever that
-- distance is smaller than its radius, and is pushed out along the "out" direction (the
-- surface normal). Using closest points instead of tile edges means a circle rolls
-- smoothly across the seams between tiles and around rounded corners.
--
-- All coordinates are simulation pixels with y pointing down.

local Config = require(script.Parent.Parent.Config)
local LevelGrid = require(script.Parent.Parent.LevelGrid)
local TileShapes = require(script.Parent.Parent.TileShapes)

local T = Config.TILE_PX
local HALF_SQRT2 = math.sqrt(0.5)
local ONE_WAY_CATCH = 5 -- px: one-way platforms only catch circles this close to fully above them

-- An axis-aligned box that blocks movement. One-way boxes only push things out through
-- the face whose outward normal is (oneWayNx, oneWayNy).
export type Solid = {
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	oneWayNx: number?,
	oneWayNy: number?,
	vx: number?, -- how fast it's moving (px per frame), so it can carry and shove things
	vy: number?,
	tag: any, -- whatever owns it, so collisions can be traced back (a bounce block, a thwump...)
}

export type World = {
	grid: LevelGrid.Grid,
	solids: { Solid },
}

export type Contact = {
	dist: number, -- signed distance from the point to the surface (negative = inside)
	nx: number, -- unit normal pointing out of the solid
	ny: number,
	solid: Solid?, -- nil for level tiles
}

local Collision = {}

local function sign(x: number): number
	return if x < 0 then -1 else 1
end

local function closestOnSegment(px: number, py: number, ax: number, ay: number, bx: number, by: number): (number, number)
	local dx, dy = bx - ax, by - ay
	local t = math.clamp(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0, 1)
	return ax + dx * t, ay + dy * t
end

-- Distance and outward normal from (px, py) to the nearer of two candidate points.
local function fromClosest(px: number, py: number, cx: number, cy: number): (number, number, number)
	local dx, dy = px - cx, py - cy
	local d = math.sqrt(dx * dx + dy * dy)
	if d < 1e-9 then
		return 0, 0, -1
	end
	return d, dx / d, dy / d
end

-- Signed distance from a point to an axis-aligned box.
function Collision.boxDistance(x0: number, y0: number, x1: number, y1: number, px: number, py: number): (number, number, number)
	local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
	local dx, dy = px - cx, py - cy
	local qx, qy = math.abs(dx) - (x1 - x0) / 2, math.abs(dy) - (y1 - y0) / 2
	if qx > 0 or qy > 0 then
		local ox, oy = math.max(qx, 0), math.max(qy, 0)
		local d = math.sqrt(ox * ox + oy * oy)
		return d, sign(dx) * ox / d, sign(dy) * oy / d
	end
	-- Inside: the way out is through the nearest side.
	if qx > qy then
		return qx, sign(dx), 0
	end
	return qy, 0, sign(dy)
end

-- Signed distance from (u, v) to a slope or curve in "corner space": the tile's solid corner
-- sits at (0, 0) and the tile covers (0, 0) to (T, T). Returns distance, normal u, normal v.
local function cornerDistance(kind: TileShapes.Kind, u: number, v: number): (number, number, number)
	if kind == "slope" then
		-- Solid triangle: u >= 0, v >= 0, u + v <= T.
		if u >= 0 and v >= 0 and u + v <= T then
			local diagonal = (T - u - v) * HALF_SQRT2
			if u <= v and u <= diagonal then
				return -u, -1, 0
			elseif v <= diagonal then
				return -v, 0, -1
			end
			return -diagonal, HALF_SQRT2, HALF_SQRT2
		end
		local bu, bv = closestOnSegment(u, v, 0, 0, T, 0)
		local best = (u - bu) ^ 2 + (v - bv) ^ 2
		local cu, cv = closestOnSegment(u, v, T, 0, 0, T)
		local d2 = (u - cu) ^ 2 + (v - cv) ^ 2
		if d2 < best then
			best, bu, bv = d2, cu, cv
		end
		cu, cv = closestOnSegment(u, v, 0, T, 0, 0)
		if (u - cu) ^ 2 + (v - cv) ^ 2 < best then
			bu, bv = cu, cv
		end
		return fromClosest(u, v, bu, bv)
	elseif kind == "convex" then
		-- Solid quarter disc of radius T around the corner.
		local r = math.sqrt(u * u + v * v)
		if u >= 0 and v >= 0 then
			if r <= T then
				local toArc = T - r
				if u <= v and u <= toArc then
					return -u, -1, 0
				elseif v <= toArc then
					return -v, 0, -1
				end
				return -toArc, u / r, v / r
			end
			return r - T, u / r, v / r
		end
		-- Beside one of the flat sides (or past the corner itself).
		local cu = if u < 0 then 0 else math.min(u, T)
		local cv = if v < 0 then 0 else math.min(v, T)
		return fromClosest(u, v, cu, cv)
	end

	-- Concave: the tile minus a disc of radius T around the opposite corner (T, T).
	local ou, ov = u - T, v - T
	local ro = math.sqrt(ou * ou + ov * ov)
	if u >= 0 and v >= 0 and u <= T and v <= T and ro >= T then
		local toArc = ro - T
		if u <= v and u <= toArc then
			return -u, -1, 0
		elseif v <= toArc then
			return -v, 0, -1
		end
		return -toArc, -ou / ro, -ov / ro
	end
	-- Outside: nearest of the two flat sides and the curved face.
	local bu, bv = closestOnSegment(u, v, 0, 0, T, 0)
	local best = (u - bu) ^ 2 + (v - bv) ^ 2
	local cu, cv = closestOnSegment(u, v, 0, 0, 0, T)
	local d2 = (u - cu) ^ 2 + (v - cv) ^ 2
	if d2 < best then
		best, bu, bv = d2, cu, cv
	end
	if ro > 1e-9 then
		local au, av = T + ou / ro * T, T + ov / ro * T
		if au >= 0 and av >= 0 and au <= T and av <= T and (u - au) ^ 2 + (v - av) ^ 2 < best then
			bu, bv = au, av
		end
	end
	return fromClosest(u, v, bu, bv)
end

-- Signed distance from a point to the solid part of tile (tx, ty).
function Collision.tileDistance(s: TileShapes.Shape, tx: number, ty: number, px: number, py: number): (number, number, number)
	if s.kind == "full" then
		return Collision.boxDistance(tx * T, ty * T, (tx + 1) * T, (ty + 1) * T, px, py)
	end
	local cornerX = if s.sx > 0 then T else 0
	local cornerY = if s.sy > 0 then T else 0
	local u = (px - tx * T - cornerX) * -s.sx
	local v = (py - ty * T - cornerY) * -s.sy
	local d, nu, nv = cornerDistance(s.kind, u, v)
	return d, nu * -s.sx, nv * -s.sy
end

-- Every solid surface closer than `reach` to (px, py). Reuses `out` if given.
function Collision.contacts(world: World, px: number, py: number, reach: number, out: { Contact }?): { Contact }
	local result = out or {}
	table.clear(result)
	local grid = world.grid
	for ty = math.floor((py - reach) / T), math.floor((py + reach) / T) do
		for tx = math.floor((px - reach) / T), math.floor((px + reach) / T) do
			local s = LevelGrid.shapeAt(grid, tx, ty)
			if s.kind ~= "empty" then
				local d, nx, ny = Collision.tileDistance(s, tx, ty, px, py)
				if d < reach then
					table.insert(result, { dist = d, nx = nx, ny = ny })
				end
			end
		end
	end
	for _, solid in world.solids do
		local d, nx, ny = Collision.boxDistance(solid.x0, solid.y0, solid.x1, solid.y1, px, py)
		if d < reach then
			local wantX, wantY = solid.oneWayNx, solid.oneWayNy
			if wantX and wantY then
				-- One-way: only the open face blocks, and only things almost fully past it.
				if d >= reach - ONE_WAY_CATCH and nx * wantX + ny * wantY > 0.7 then
					table.insert(result, { dist = d, nx = nx, ny = ny, solid = solid })
				end
			else
				table.insert(result, { dist = d, nx = nx, ny = ny, solid = solid })
			end
		end
	end
	return result
end

-- Signed distance from a point to the nearest level tile (moving solids ignored).
function Collision.gridDistance(grid: LevelGrid.Grid, px: number, py: number): number
	local tx, ty = math.floor(px / T), math.floor(py / T)
	local best = math.huge
	for y = ty - 1, ty + 1 do
		for x = tx - 1, tx + 1 do
			local s = LevelGrid.shapeAt(grid, x, y)
			if s.kind ~= "empty" then
				best = math.min(best, (Collision.tileDistance(s, x, y, px, py)))
			end
		end
	end
	return best
end

function Collision.pointInTiles(grid: LevelGrid.Grid, px: number, py: number): boolean
	local tx, ty = math.floor(px / T), math.floor(py / T)
	local s = LevelGrid.shapeAt(grid, tx, ty)
	if s.kind == "empty" then
		return false
	elseif s.kind == "full" then
		return true
	end
	return (Collision.tileDistance(s, tx, ty, px, py)) <= 0
end

-- Where the segment from (x0, y0) to (x1, y1) first enters a level tile, as a fraction of
-- its length (0 to 1), or nil if the way is clear. Walks the grid cell by cell; only
-- slope and curve cells need a closer look.
function Collision.raycast(grid: LevelGrid.Grid, x0: number, y0: number, x1: number, y1: number): number?
	local dx, dy = x1 - x0, y1 - y0
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 1e-6 then
		return if Collision.pointInTiles(grid, x0, y0) then 0 else nil
	end
	local cx, cy = math.floor(x0 / T), math.floor(y0 / T)
	local endX, endY = math.floor(x1 / T), math.floor(y1 / T)
	local stepX, stepY = if dx > 0 then 1 elseif dx < 0 then -1 else 0, if dy > 0 then 1 elseif dy < 0 then -1 else 0
	-- Fraction of the segment at which we cross the next vertical / horizontal grid line.
	local tMaxX = if stepX > 0 then ((cx + 1) * T - x0) / dx elseif stepX < 0 then (cx * T - x0) / dx else math.huge
	local tMaxY = if stepY > 0 then ((cy + 1) * T - y0) / dy elseif stepY < 0 then (cy * T - y0) / dy else math.huge
	local tDeltaX = if stepX ~= 0 then T / math.abs(dx) else math.huge
	local tDeltaY = if stepY ~= 0 then T / math.abs(dy) else math.huge
	local tEnter = 0
	for _ = 1, 4096 do
		local tExit = math.min(tMaxX, tMaxY, 1)
		local s = LevelGrid.shapeAt(grid, cx, cy)
		if s.kind == "full" then
			return tEnter
		elseif s.kind ~= "empty" then
			-- Sample the part of the segment inside this cell about once per pixel.
			local samples = math.max(2, math.ceil((tExit - tEnter) * length))
			for i = 0, samples do
				local t = tEnter + (tExit - tEnter) * i / samples
				if (Collision.tileDistance(s, cx, cy, x0 + dx * t, y0 + dy * t)) <= 0 then
					return t
				end
			end
		end
		if tExit >= 1 or (cx == endX and cy == endY) then
			return nil
		end
		tEnter = tExit
		if tMaxX < tMaxY then
			cx += stepX
			tMaxX += tDeltaX
		else
			cy += stepY
			tMaxY += tDeltaY
		end
	end
	return nil
end

-- True if nothing solid in the level blocks the straight line between two points.
function Collision.lineOfSight(grid: LevelGrid.Grid, x0: number, y0: number, x1: number, y1: number): boolean
	return Collision.raycast(grid, x0, y0, x1, y1) == nil
end

-- Distance from a point to a line segment.
function Collision.segmentDistance(px: number, py: number, ax: number, ay: number, bx: number, by: number): number
	if ax == bx and ay == by then
		return math.sqrt((px - ax) ^ 2 + (py - ay) ^ 2)
	end
	local cx, cy = closestOnSegment(px, py, ax, ay, bx, by)
	return math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2)
end

return Collision
