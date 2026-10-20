--!strict
-- A room as a grid of cells, read from an ASCII map. Pure data and math (no
-- Instances), so the server and every client can build the same grid.
--
-- Map characters: '#' wall, '.' floor, 'S' enemy entry, 'P' player spawn,
-- 'A' ammo box spot, 'T' practice target. Row 1 is the north edge (-Z),
-- column 1 the west edge (-X).

export type RoomDef = {
	name: string,
	map: { string },
}

export type Cell = { c: number, r: number }

local RoomGrid = {}
RoomGrid.__index = RoomGrid

export type RoomGrid = typeof(setmetatable(
	{} :: {
		name: string,
		width: number,
		height: number,
		cellSize: number,
		originX: number, -- world X of the west edge
		originZ: number, -- world Z of the north edge
		cells: { { string } }, -- cells[row][column]
		blocked: { { boolean } },
	},
	RoomGrid
))

-- Builds the grid centered on (centerX, centerZ), which defaults to the world origin.
function RoomGrid.new(def: RoomDef, cellSize: number, centerX: number?, centerZ: number?): RoomGrid
	local height = #def.map
	local width = 0
	for _, line in def.map do
		width = math.max(width, #line)
	end

	local cells: { { string } } = {}
	local blocked: { { boolean } } = {}
	for r = 1, height do
		local line = def.map[r]
		cells[r] = {}
		blocked[r] = {}
		for c = 1, width do
			local char = string.sub(line, c, c)
			if char == "" or char == " " then
				char = "#" -- short lines are padded with wall
			end
			cells[r][c] = char
			blocked[r][c] = char == "#"
		end
	end

	return setmetatable({
		name = def.name,
		width = width,
		height = height,
		cellSize = cellSize,
		originX = (centerX or 0) - width * cellSize / 2,
		originZ = (centerZ or 0) - height * cellSize / 2,
		cells = cells,
		blocked = blocked,
	}, RoomGrid)
end

function RoomGrid.inBounds(self: RoomGrid, c: number, r: number): boolean
	return c >= 1 and c <= self.width and r >= 1 and r <= self.height
end

-- The map character at a cell; outside the map counts as wall.
function RoomGrid.cell(self: RoomGrid, c: number, r: number): string
	if not self:inBounds(c, r) then
		return "#"
	end
	return self.cells[r][c]
end

-- Whether bullets and walkers are stopped by this cell. Outside the map is blocked.
function RoomGrid.isBlocked(self: RoomGrid, c: number, r: number): boolean
	if not self:inBounds(c, r) then
		return true
	end
	return self.blocked[r][c]
end

function RoomGrid.setBlocked(self: RoomGrid, c: number, r: number, value: boolean)
	if self:inBounds(c, r) then
		self.blocked[r][c] = value
	end
end

function RoomGrid.worldToCell(self: RoomGrid, x: number, z: number): (number, number)
	return math.floor((x - self.originX) / self.cellSize) + 1, math.floor((z - self.originZ) / self.cellSize) + 1
end

-- World X and Z of a cell's center.
function RoomGrid.cellCenter(self: RoomGrid, c: number, r: number): (number, number)
	return self.originX + (c - 0.5) * self.cellSize, self.originZ + (r - 0.5) * self.cellSize
end

-- Every cell holding the given map character, in reading order.
function RoomGrid.find(self: RoomGrid, char: string): { Cell }
	local found: { Cell } = {}
	for r = 1, self.height do
		for c = 1, self.width do
			if self.cells[r][c] == char then
				table.insert(found, { c = c, r = r })
			end
		end
	end
	return found
end

-- Walks the grid from (ox, oz) along the unit direction (dx, dz) and returns the
-- distance to the first blocked cell, or maxDist if nothing is in the way.
function RoomGrid.raycast(self: RoomGrid, ox: number, oz: number, dx: number, dz: number, maxDist: number): number
	local size = self.cellSize
	local gx = (ox - self.originX) / size
	local gz = (oz - self.originZ) / size
	local c = math.floor(gx) + 1
	local r = math.floor(gz) + 1
	if self:isBlocked(c, r) then
		return 0
	end
	if dx == 0 and dz == 0 then
		return maxDist
	end

	local stepC = if dx > 0 then 1 elseif dx < 0 then -1 else 0
	local stepR = if dz > 0 then 1 elseif dz < 0 then -1 else 0
	local deltaC = if dx ~= 0 then size / math.abs(dx) else math.huge
	local deltaR = if dz ~= 0 then size / math.abs(dz) else math.huge
	-- Distance along the ray to the next column / row boundary.
	local nextC = if dx > 0 then (c - gx) * size / dx elseif dx < 0 then (gx - (c - 1)) * size / -dx else math.huge
	local nextR = if dz > 0 then (r - gz) * size / dz elseif dz < 0 then (gz - (r - 1)) * size / -dz else math.huge

	while true do
		local t
		if nextC < nextR then
			t = nextC
			c += stepC
			nextC += deltaC
		else
			t = nextR
			r += stepR
			nextR += deltaR
		end
		if t >= maxDist then
			return maxDist
		end
		if self:isBlocked(c, r) then
			return t
		end
	end
end

return RoomGrid
