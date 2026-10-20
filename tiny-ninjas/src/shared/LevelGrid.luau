--!strict
-- Reads a level's ASCII tile grid and answers "which tile shape is at (x, y)?".
-- x counts columns from 0 at the left, y counts rows from 0 at the top.
-- Anything outside the grid counts as a full block, so every level is walled in.

local TileShapes = require(script.Parent.TileShapes)

export type Grid = {
	levelId: string,
	width: number,
	height: number,
	cells: { { TileShapes.Shape } }, -- cells[y + 1][x + 1]
}

local LevelGrid = {}

function LevelGrid.parse(text: string, levelId: string): Grid
	-- One row per line. Spaces, tabs and blank lines are ignored, so grids can be indented.
	local rows = {}
	for line in string.gmatch(text, "[^\n]+") do
		local row = string.gsub(line, "%s", "")
		if row ~= "" then
			table.insert(rows, row)
		end
	end
	if #rows == 0 then
		error(`Level "{levelId}" has an empty grid`)
	end

	local width = #rows[1]
	local cells = {}
	for y, row in rows do
		if #row ~= width then
			error(`Level "{levelId}": row {y - 1} is {#row} tiles wide but row 0 is {width}`)
		end
		local line = table.create(width)
		for x = 1, width do
			local char = string.sub(row, x, x)
			local s = TileShapes.byChar[char]
			if not s then
				error(`Level "{levelId}": unknown tile '{char}' at column {x - 1}, row {y - 1}`)
			end
			line[x] = s
		end
		cells[y] = line
	end

	return { levelId = levelId, width = width, height = #rows, cells = cells }
end

function LevelGrid.shapeAt(grid: Grid, x: number, y: number): TileShapes.Shape
	if x < 0 or y < 0 or x >= grid.width or y >= grid.height then
		return TileShapes.FULL
	end
	return grid.cells[y + 1][x + 1]
end

return LevelGrid
