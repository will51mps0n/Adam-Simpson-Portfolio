--!strict
-- Builds the lobby: a walled room south of the arena with six party pads,
-- floating score boards and the game's title. Pads are the room's '1'-'6'
-- cells, boards its 'B' cells, spawns its 'P' cells.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RoomGrid = require(ReplicatedStorage.Shared.RoomGrid)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local RoomBuilder = require(script.Parent.RoomBuilder)

export type Pad = {
	index: number,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	base: Part,
	border: { Part },
	title: TextLabel,
	detail: TextLabel,
}

export type Lobby = {
	grid: RoomGrid.RoomGrid,
	pads: { Pad },
	boards: { Vector3 },
	spawns: { CFrame },
}

local LobbyBuilder = {}

local function label(parent: Instance, text: string, size: number, y: number, height: number): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Position = UDim2.fromScale(0, y)
	textLabel.Size = UDim2.fromScale(1, height)
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.Text = text
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeColor3 = Color3.fromRGB(20, 20, 26)
	textLabel.TextStrokeTransparency = 0
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = size
	constraint.Parent = textLabel
	textLabel.Parent = parent
	return textLabel
end

-- An invisible anchor with a sign floating above it that always faces the camera.
function LobbyBuilder.sign(parent: Instance, at: Vector3, widthStuds: number, heightStuds: number): BillboardGui
	local anchor = Instance.new("Part")
	anchor.Name = "SignAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = parent
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(widthStuds, 0, heightStuds, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = anchor
	return gui
end

local function part(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function LobbyBuilder.build(): Lobby
	local grid = RoomGrid.new(Rooms.HUB, Config.CELL_SIZE, 0, Config.HUB_CENTER_Z)
	local folder = RoomBuilder.build(grid, "Lobby")
	local size = grid.cellSize

	local pads: { Pad } = {}
	for index = 1, 6 do
		local cells = grid:find(tostring(index))
		if #cells == 0 then
			continue
		end
		local c0, c1, r0, r1 = math.huge, -math.huge, math.huge, -math.huge
		for _, cell in cells do
			c0, c1 = math.min(c0, cell.c), math.max(c1, cell.c)
			r0, r1 = math.min(r0, cell.r), math.max(r1, cell.r)
		end
		local minX, minZ = grid.originX + (c0 - 1) * size, grid.originZ + (r0 - 1) * size
		local maxX, maxZ = grid.originX + c1 * size, grid.originZ + r1 * size
		local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
		local w, h = maxX - minX, maxZ - minZ
		local padFolder = Instance.new("Folder")
		padFolder.Name = "Pad" .. index
		padFolder.Parent = folder
		local base = part(padFolder, Vector3.new(w - 1, 0.2, h - 1), CFrame.new(cx, 0.1, cz), Color3.fromRGB(60, 200, 90))
		base.Transparency = 0.35
		local border: { Part } = {
			part(padFolder, Vector3.new(w, 0.3, 0.5), CFrame.new(cx, 0.15, minZ + 0.25), Color3.fromRGB(60, 200, 90), Enum.Material.Neon),
			part(padFolder, Vector3.new(w, 0.3, 0.5), CFrame.new(cx, 0.15, maxZ - 0.25), Color3.fromRGB(60, 200, 90), Enum.Material.Neon),
			part(padFolder, Vector3.new(0.5, 0.3, h), CFrame.new(minX + 0.25, 0.15, cz), Color3.fromRGB(60, 200, 90), Enum.Material.Neon),
			part(padFolder, Vector3.new(0.5, 0.3, h), CFrame.new(maxX - 0.25, 0.15, cz), Color3.fromRGB(60, 200, 90), Enum.Material.Neon),
		}
		local gui = LobbyBuilder.sign(padFolder, Vector3.new(cx, 7, cz), 18, 6)
		local title = label(gui, "PARTY " .. index, 40, 0, 0.5)
		local detail = label(gui, "", 26, 0.5, 0.5)
		table.insert(pads, {
			index = index,
			minX = minX,
			maxX = maxX,
			minZ = minZ,
			maxZ = maxZ,
			base = base,
			border = border,
			title = title,
			detail = detail,
		})
	end

	local boards: { Vector3 } = {}
	for _, cell in grid:find("B") do
		local x, z = grid:cellCenter(cell.c, cell.r)
		part(folder, Vector3.new(10, 0.2, 5), CFrame.new(x, 0.1, z), Color3.fromRGB(46, 46, 56))
		table.insert(boards, Vector3.new(x, 9, z))
	end

	for _, cell in grid:find("T") do
		local x, z = grid:cellCenter(cell.c, cell.r)
		local gui = LobbyBuilder.sign(folder, Vector3.new(x, 6, z), 40, 10)
		local title = label(gui, string.upper(Config.GAME_NAME), 90, 0, 0.7)
		title.TextColor3 = Color3.fromRGB(240, 196, 60)
		label(gui, "Step on a pad to start a party", 30, 0.7, 0.3)
	end

	local spawns: { CFrame } = {}
	for _, cell in grid:find("P") do
		local x, z = grid:cellCenter(cell.c, cell.r)
		table.insert(spawns, CFrame.new(x, 3.5, z))
	end

	return { grid = grid, pads = pads, boards = boards, spawns = spawns }
end

return LobbyBuilder
