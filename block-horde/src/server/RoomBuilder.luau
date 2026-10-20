--!strict
-- Turns a RoomGrid into parts: a checkered tile floor and block walls.
-- Neighbouring wall cells are merged into large rectangles to keep part count
-- low. Entry gaps get a short dark tunnel outside them for enemies to walk in
-- from, and an invisible barrier so players can't walk out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RoomGrid = require(ReplicatedStorage.Shared.RoomGrid)

local RoomBuilder = {}

local FLOOR_THICKNESS = 1
local TILE_RAISE = 0.04 -- the darker tiles sit a hair above the base floor to avoid flicker
local WALL_CAP = 0.4 -- thickness of the darker top of each wall
local TUNNEL_COLOR = Color3.fromRGB(58, 56, 54)

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildFloor(grid: RoomGrid.RoomGrid, folder: Instance)
	local size = grid.cellSize
	local w, h = grid.width * size, grid.height * size
	local base = block(
		"Floor",
		Vector3.new(w, FLOOR_THICKNESS, h),
		CFrame.new(grid.originX + w / 2, -FLOOR_THICKNESS / 2, grid.originZ + h / 2),
		Config.FLOOR_COLOR_A,
		folder
	)
	base.CastShadow = false

	for r = 1, grid.height do
		for c = 1, grid.width do
			if (c + r) % 2 == 0 and grid:cell(c, r) ~= "#" then
				local x, z = grid:cellCenter(c, r)
				local tile = block("Tile", Vector3.new(size, 0.2, size), CFrame.new(x, TILE_RAISE - 0.1, z), Config.FLOOR_COLOR_B, folder)
				tile.CanCollide = false
				tile.CanQuery = false
				tile.CanTouch = false
				tile.CastShadow = false
			end
		end
	end
end

local function buildWalls(grid: RoomGrid.RoomGrid, folder: Instance)
	local size = grid.cellSize
	local used: { [number]: boolean } = {}
	local function key(c: number, r: number): number
		return r * 10000 + c
	end
	local function free(c: number, r: number): boolean
		return grid:inBounds(c, r) and grid:cell(c, r) == "#" and not used[key(c, r)]
	end

	for r = 1, grid.height do
		for c = 1, grid.width do
			if free(c, r) then
				-- Grow the widest run on this row, then extend it down while every cell matches.
				local runW = 1
				while free(c + runW, r) do
					runW += 1
				end
				local runH = 1
				while true do
					local rowOk = true
					for cc = c, c + runW - 1 do
						if not free(cc, r + runH) then
							rowOk = false
							break
						end
					end
					if not rowOk then
						break
					end
					runH += 1
				end
				for rr = r, r + runH - 1 do
					for cc = c, c + runW - 1 do
						used[key(cc, rr)] = true
					end
				end

				local x0, z0 = grid:cellCenter(c, r)
				local cx = x0 + (runW - 1) * size / 2
				local cz = z0 + (runH - 1) * size / 2
				local footW, footH = runW * size, runH * size
				local bodyHeight = Config.WALL_HEIGHT - WALL_CAP
				block("Wall", Vector3.new(footW, bodyHeight, footH), CFrame.new(cx, bodyHeight / 2, cz), Config.WALL_COLOR, folder)
				local cap = block("WallTop", Vector3.new(footW, WALL_CAP, footH), CFrame.new(cx, bodyHeight + WALL_CAP / 2, cz), Config.WALL_TOP_COLOR, folder)
				cap.CastShadow = false
			end
		end
	end
end

-- Direction pointing out of the room from an edge cell, or (0, 0) for inner cells.
function RoomBuilder.outward(grid: RoomGrid.RoomGrid, c: number, r: number): (number, number)
	if r == 1 then
		return 0, -1
	elseif r == grid.height then
		return 0, 1
	elseif c == 1 then
		return -1, 0
	elseif c == grid.width then
		return 1, 0
	end
	return 0, 0
end

local function buildEntries(grid: RoomGrid.RoomGrid, folder: Instance)
	local size = grid.cellSize
	for _, cell in grid:find("S") do
		local x, z = grid:cellCenter(cell.c, cell.r)
		local ox, oz = RoomBuilder.outward(grid, cell.c, cell.r)
		-- Dark tunnel floor outside the gap.
		local length = Config.ENEMY_ENTER_DISTANCE + size
		local tunnel = block(
			"Tunnel",
			Vector3.new(if ox ~= 0 then length else size, 0.4, if oz ~= 0 then length else size),
			CFrame.new(x + ox * (size / 2 + length / 2), -0.2, z + oz * (size / 2 + length / 2)),
			TUNNEL_COLOR,
			folder
		)
		tunnel.CastShadow = false
		-- Invisible barrier across the outer edge of the gap.
		local barrier = block(
			"Barrier",
			Vector3.new(if ox ~= 0 then 1 else size, 12, if oz ~= 0 then 1 else size),
			CFrame.new(x + ox * (size / 2 + 0.5), 6, z + oz * (size / 2 + 0.5)),
			Color3.new(0, 0, 0),
			folder
		)
		barrier.Transparency = 1
		barrier.CanQuery = false
	end
end

-- Builds the room into workspace[folderName], replacing whatever was there.
function RoomBuilder.build(grid: RoomGrid.RoomGrid, folderName: string): Folder
	local old = workspace:FindFirstChild(folderName)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = folderName
	buildFloor(grid, folder)
	buildWalls(grid, folder)
	buildEntries(grid, folder)
	folder.Parent = workspace
	return folder
end

return RoomBuilder
