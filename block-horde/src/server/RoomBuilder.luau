--!strict
-- Turns a RoomGrid into parts: a checkered tile floor and block walls.
-- Neighbouring wall cells are merged into large rectangles to keep part count low.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RoomGrid = require(ReplicatedStorage.Shared.RoomGrid)

local RoomBuilder = {}

local FLOOR_THICKNESS = 1
local TILE_RAISE = 0.04 -- the darker tiles sit a hair above the base floor to avoid flicker
local WALL_CAP = 0.4 -- thickness of the darker top of each wall

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
		return grid:cell(c, r) == "#" and grid:inBounds(c, r) and not used[key(c, r)]
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
				local footprint = Vector2.new(runW * size, runH * size)
				local bodyHeight = Config.WALL_HEIGHT - WALL_CAP
				block("Wall", Vector3.new(footprint.X, bodyHeight, footprint.Y), CFrame.new(cx, bodyHeight / 2, cz), Config.WALL_COLOR, folder)
				local cap = block(
					"WallTop",
					Vector3.new(footprint.X, WALL_CAP, footprint.Y),
					CFrame.new(cx, bodyHeight + WALL_CAP / 2, cz),
					Config.WALL_TOP_COLOR,
					folder
				)
				cap.CastShadow = false
			end
		end
	end
end

-- Builds the room into workspace.Arena, replacing whatever room was there.
function RoomBuilder.build(grid: RoomGrid.RoomGrid): Folder
	local old = workspace:FindFirstChild("Arena")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	buildFloor(grid, folder)
	buildWalls(grid, folder)
	folder.Parent = workspace
	return folder
end

return RoomBuilder
