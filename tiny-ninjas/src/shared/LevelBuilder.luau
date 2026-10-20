--!strict
-- Turns a level definition into Parts on the Z = 0 plane:
--  * a light grey background panel behind the level,
--  * dark grey blocks, with neighboring full tiles (and the 1-tile wall around the
--    grid) merged into as few rectangles as possible,
--  * slopes as WedgeParts and quarter circles as fans of thin wedge slices.
-- Works on the server or a client; each client builds its own copy of the level.

local Config = require(script.Parent.Config)
local Units = require(script.Parent.Units)
local TileShapes = require(script.Parent.TileShapes)
local LevelGrid = require(script.Parent.LevelGrid)
local Levels = require(script.Parent.Levels)

local T = Config.TILE_PX
local DEPTH = Config.TILE_DEPTH_STUDS
local OVERLAP = Config.SEAM_OVERLAP_STUDS
local MAX_GROWTH = 0.03 -- studs; the most any corner of a curve slice may move outward

export type CameraMode = "fixed" | "follow"

export type BuiltLevel = {
	def: Levels.LevelDef,
	grid: LevelGrid.Grid,
	model: Model,
	cameraMode: CameraMode,
	-- World-space box (studs, x and y) around the level including its 1-tile outer wall
	boundsMin: Vector2,
	boundsMax: Vector2,
	-- Z of the blocks' front faces: the plane the camera frames
	frontZ: number,
}

local LevelBuilder = {}

local function styleTile(part: BasePart, color: Color3)
	part.Anchored = true
	part.CanCollide = true -- ragdolls (milestone 2) tumble against the level
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

-- A box covering pixels (x0, y0) to (x1, y1), centered on depth z.
local function addRect(
	parent: Instance,
	name: string,
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	z: number,
	depth: number,
	color: Color3
): Part
	local part = Instance.new("Part")
	styleTile(part, color)
	part.Name = name
	part.Size = Vector3.new(Units.studs(x1 - x0) + OVERLAP, Units.studs(y1 - y0) + OVERLAP, depth)
	part.CFrame = CFrame.new(Units.toWorld((x0 + x1) / 2, (y0 + y1) / 2, z))
	part.Parent = parent
	return part
end

-- One WedgePart showing the right triangle with its right angle at `r` and its other
-- corners at `p` and `q` (world points on Z = 0), extruded DEPTH studs into the screen.
-- A WedgePart's right angle runs along its local (-Y, +Z) edge, so: local +Z points from
-- p toward r, local +Y points from r toward q, and local X is the extrusion axis.
local function addRightTriangle(parent: Instance, name: string, r: Vector3, p: Vector3, q: Vector3, color: Color3)
	local alongZ = r - p
	local alongY = q - r
	local lengthZ, lengthY = alongZ.Magnitude, alongY.Magnitude
	if lengthZ < 1e-4 or lengthY < 1e-4 then
		return -- a sliver with no area
	end
	local zAxis = alongZ / lengthZ
	local yAxis = alongY / lengthY

	-- Grow the triangle a hair on every side (scaling it about its incenter) so it overlaps
	-- its neighbors and no hairline cracks show. Capped so needle-thin slivers can't sprout
	-- visible spikes at their sharp corners.
	local hypotenuse = math.sqrt(lengthY * lengthY + lengthZ * lengthZ)
	local inradius = (lengthY + lengthZ - hypotenuse) / 2
	local incenter = r + (yAxis - zAxis) * inradius
	local scale = 1 + math.min((OVERLAP / 2) / inradius, MAX_GROWTH / hypotenuse)
	p = incenter + (p - incenter) * scale
	q = incenter + (q - incenter) * scale

	local wedge = Instance.new("WedgePart")
	styleTile(wedge, color)
	wedge.Name = name
	wedge.Size = Vector3.new(DEPTH, lengthY * scale, lengthZ * scale)
	wedge.CFrame = CFrame.fromMatrix((p + q) / 2, yAxis:Cross(zAxis), yAxis, zAxis)
	wedge.Parent = parent
end

-- Any triangle, as two right triangles: drop a line from the corner opposite the
-- longest side straight onto that side, and draw each half as a wedge.
local function addTriangle(parent: Instance, name: string, a: Vector3, b: Vector3, c: Vector3, color: Color3)
	local ab, ac, bc = (b - a).Magnitude, (c - a).Magnitude, (c - b).Magnitude
	if ab >= ac and ab >= bc then
		a, c = c, a
	elseif ac >= bc then
		a, b = b, a
	end
	-- Now b-c is the longest side and a is the corner opposite it.
	local side = (c - b).Unit
	local foot = b + side * (a - b):Dot(side)
	addRightTriangle(parent, name, foot, b, a, color)
	addRightTriangle(parent, name, foot, c, a, color)
end

type TileRect = { x0: number, y0: number, x1: number, y1: number }

-- Full tiles grouped into rectangles (tile coordinates, inclusive). The 1-tile wall around
-- the grid is included, so x and y run from -1 to width / height.
local function fullTileRects(grid: LevelGrid.Grid): { TileRect }
	local function isFull(x: number, y: number): boolean
		return LevelGrid.shapeAt(grid, x, y).kind == "full"
	end

	local rects: { TileRect } = {}
	local growing: { [string]: TileRect } = {} -- rectangles still growing downward, by column span
	for y = -1, grid.height do
		local stillGrowing: { [string]: TileRect } = {}
		local x = -1
		while x <= grid.width do
			if isFull(x, y) then
				local x0 = x
				while x + 1 <= grid.width and isFull(x + 1, y) do
					x += 1
				end
				-- A run of full tiles from x0 to x. Stack it under an identical run above, if any.
				local key = `{x0}:{x}`
				local rect = growing[key]
				if rect then
					rect.y1 = y
					stillGrowing[key] = rect
				else
					local fresh = { x0 = x0, y0 = y, x1 = x, y1 = y }
					table.insert(rects, fresh)
					stillGrowing[key] = fresh
				end
			end
			x += 1
		end
		growing = stillGrowing
	end
	return rects
end

local function pickCameraMode(def: Levels.LevelDef, grid: LevelGrid.Grid): CameraMode
	if def.camera then
		return def.camera
	end
	local fits = grid.width <= Config.LEVEL_GRID_W and grid.height <= Config.LEVEL_GRID_H
	return if fits then "fixed" else "follow"
end

function LevelBuilder.build(def: Levels.LevelDef, parent: Instance): BuiltLevel
	local grid = LevelGrid.parse(def.grid, def.id)
	local colors = Config.COLORS
	local widthPx, heightPx = grid.width * T, grid.height * T

	local model = Instance.new("Model")
	model.Name = "Level"

	-- Light background just behind the blocks, and a huge backdrop behind that so the
	-- area outside the level looks like solid wall.
	local backZ = -DEPTH / 2
	local background = addRect(model, "Background", 0, 0, widthPx, heightPx, backZ - 0.05, 0.1, colors.BACKGROUND)
	background.CanCollide = false
	-- (Roblox parts can be at most 2048 studs long, so the backdrop's reach is capped.)
	local cx, cy, reach = widthPx / 2, heightPx / 2, math.min(math.max(widthPx, heightPx) * 4, 8000)
	local void = addRect(model, "Void", cx - reach, cy - reach, cx + reach, cy + reach, backZ - 0.6, 0.1, colors.VOID)
	void.CanCollide = false

	local blocks = Instance.new("Folder")
	blocks.Name = "Blocks"
	for _, rect in fullTileRects(grid) do
		addRect(
			blocks,
			`Block ({rect.x0},{rect.y0})-({rect.x1},{rect.y1})`,
			rect.x0 * T,
			rect.y0 * T,
			(rect.x1 + 1) * T,
			(rect.y1 + 1) * T,
			0,
			DEPTH,
			colors.TILE
		)
	end
	blocks.Parent = model

	local shapes = Instance.new("Folder")
	shapes.Name = "Shapes"
	for y = 0, grid.height - 1 do
		for x = 0, grid.width - 1 do
			local s = LevelGrid.shapeAt(grid, x, y)
			if s.kind ~= "empty" and s.kind ~= "full" then
				local name = `{s.name} ({x},{y})`
				local ox, oy = x * T, y * T
				for _, tri in TileShapes.triangles(s, Config.CURVE_SEGMENTS) do
					addTriangle(
						shapes,
						name,
						Units.toWorld(ox + tri[1].X, oy + tri[1].Y),
						Units.toWorld(ox + tri[2].X, oy + tri[2].Y),
						Units.toWorld(ox + tri[3].X, oy + tri[3].Y),
						colors.TILE
					)
				end
			end
		end
	end
	shapes.Parent = model

	model.Parent = parent

	local topLeft = Units.toWorld(-T, -T)
	local bottomRight = Units.toWorld(widthPx + T, heightPx + T)
	return {
		def = def,
		grid = grid,
		model = model,
		cameraMode = pickCameraMode(def, grid),
		boundsMin = Vector2.new(topLeft.X, bottomRight.Y),
		boundsMax = Vector2.new(bottomRight.X, topLeft.Y),
		frontZ = DEPTH / 2,
	}
end

return LevelBuilder
