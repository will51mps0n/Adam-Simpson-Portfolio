--!strict
-- Builds the lobby: a regular 3D Roblox hall (normal avatars, normal camera)
-- south of the arena. Six party rooms open off the north wall, each with a
-- doorway and a sign above it. High score boards hang on the side walls,
-- the title over the party rooms, and block statues of the enemies stand
-- along the south wall.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EnemyModels = require(ReplicatedStorage.Shared.Models.EnemyModels)

export type Pad = {
	index: number,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	base: Part, -- glowing floor of the party room
	border: { Part }, -- door frame and ceiling light, recolored with the party's state
	title: TextLabel,
	detail: TextLabel,
}

export type Lobby = {
	folder: Folder,
	pads: { Pad },
	boards: { CFrame }, -- where each score board hangs, facing into the hall
	spawns: { CFrame },
}

local LobbyBuilder = {}

-- Hall interior is HALF_W studs either side of the center (X) and HALF_D (Z).
local HALF_W = 70
local HALF_D = 50
local WALL_H = 28
local WALL_T = 2
local ROOM_W = 18 -- party room interior width
local ROOM_D = 16 -- party room interior depth
local ROOM_H = 14
local DOOR_W = 8
local DOOR_H = 10
local TILE = 10

local STONE = Config.WALL_COLOR
local STONE_DARK = Config.WALL_TOP_COLOR
local ROOM_WALL = Color3.fromRGB(70, 66, 62)
local OPEN_GREEN = Color3.fromRGB(60, 200, 90)

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function deco(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- A flat sign whose front faces `facing` (a unit direction). Returns the SurfaceGui to fill in.
function LobbyBuilder.sign(parent: Instance, at: Vector3, facing: Vector3, width: number, height: number, color: Color3): SurfaceGui
	local board = part(parent, "Sign", Vector3.new(width, height, 0.4), CFrame.lookAt(at, at + facing), color)
	board.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	return gui
end

function LobbyBuilder.label(parent: Instance, text: string, y: number, height: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.04, y)
	label.Size = UDim2.fromScale(0.92, height)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 26)
	label.TextStrokeTransparency = 0
	label.Parent = parent
	return label
end

-- A big block statue of an enemy on a plinth.
local function statue(parent: Instance, kind: string, at: Vector3)
	local spec = EnemyModels.SPECS[kind]
	if not spec then
		return
	end
	local model = Instance.new("Model")
	model.Name = kind .. "Statue"
	part(model, "Plinth", Vector3.new(7, 2, 7), CFrame.new(at + Vector3.new(0, 1, 0)), STONE_DARK)
	local scale = spec.scale * 1.6
	local base = CFrame.new(at + Vector3.new(0, 2, 0))
	for _, piece in spec.parts do
		local p = part(model, "Block", piece.size * scale, base * CFrame.new(piece.offset * scale) * CFrame.Angles(math.rad(piece.tilt or 0), 0, 0), piece.color)
		if piece.neon then
			p.Material = Enum.Material.Neon
		end
	end
	model.Parent = parent
end

function LobbyBuilder.build(): Lobby
	local old = workspace:FindFirstChild("Lobby")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	local center = Vector3.new(0, 0, Config.HUB_CENTER_Z)
	local function at(x: number, y: number, z: number): Vector3
		return center + Vector3.new(x, y, z)
	end

	-- Floor: one slab plus a checker of slightly darker tiles.
	local floor = part(folder, "Floor", Vector3.new(HALF_W * 2 + WALL_T * 2, 1, HALF_D * 2 + WALL_T * 2), CFrame.new(at(0, -0.5, 0)), Config.FLOOR_COLOR_A)
	floor.CastShadow = false
	for ix = 0, HALF_W * 2 / TILE - 1 do
		for iz = 0, HALF_D * 2 / TILE - 1 do
			if (ix + iz) % 2 == 0 then
				local x = -HALF_W + TILE / 2 + ix * TILE
				local z = -HALF_D + TILE / 2 + iz * TILE
				deco(part(folder, "Tile", Vector3.new(TILE, 0.2, TILE), CFrame.new(at(x, -0.06, z)), Config.FLOOR_COLOR_B))
			end
		end
	end

	-- Outer walls (the north wall is built around the doorways below).
	local function wall(name: string, size: Vector3, position: Vector3, color: Color3?)
		part(folder, name, size, CFrame.new(position), color or STONE)
	end
	wall("SouthWall", Vector3.new(HALF_W * 2 + WALL_T * 2, WALL_H, WALL_T), at(0, WALL_H / 2, HALF_D + WALL_T / 2))
	wall("WestWall", Vector3.new(WALL_T, WALL_H, HALF_D * 2 + WALL_T * 2), at(-HALF_W - WALL_T / 2, WALL_H / 2, 0))
	wall("EastWall", Vector3.new(WALL_T, WALL_H, HALF_D * 2 + WALL_T * 2), at(HALF_W + WALL_T / 2, WALL_H / 2, 0))
	for _, side in { -1, 1 } do
		deco(part(folder, "Trim", Vector3.new(WALL_T + 0.6, 1, HALF_D * 2 + WALL_T * 2), CFrame.new(at(side * (HALF_W + WALL_T / 2), WALL_H, 0)), STONE_DARK))
	end
	deco(part(folder, "Trim", Vector3.new(HALF_W * 2 + WALL_T * 2, 1, WALL_T + 0.6), CFrame.new(at(0, WALL_H, HALF_D + WALL_T / 2)), STONE_DARK))

	-- Party rooms along the north wall.
	local northZ = -HALF_D - WALL_T / 2 -- center line of the north wall
	local roomFront = -HALF_D - WALL_T -- where a room's interior begins
	local roomBack = roomFront - ROOM_D
	local span = 6 * ROOM_W + 5 * WALL_T
	local firstX = -span / 2
	local pads: { Pad } = {}
	local doorEdges: { number } = {} -- x ranges of the doorways, for building the north wall
	for index = 1, 6 do
		local x0 = firstX + (index - 1) * (ROOM_W + WALL_T)
		local x1 = x0 + ROOM_W
		local cx = (x0 + x1) / 2
		local roomFolder = Instance.new("Folder")
		roomFolder.Name = "PartyRoom" .. index
		roomFolder.Parent = folder

		-- Room shell: floor, back wall, side walls, ceiling.
		part(roomFolder, "RoomFloor", Vector3.new(ROOM_W + WALL_T * 2, 1, ROOM_D), CFrame.new(at(cx, -0.5, (roomFront + roomBack) / 2)), ROOM_WALL)
		part(roomFolder, "BackWall", Vector3.new(ROOM_W + WALL_T * 2, ROOM_H, WALL_T), CFrame.new(at(cx, ROOM_H / 2, roomBack - WALL_T / 2)), ROOM_WALL)
		for _, side in { x0 - WALL_T / 2, x1 + WALL_T / 2 } do
			part(roomFolder, "SideWall", Vector3.new(WALL_T, ROOM_H, ROOM_D + WALL_T), CFrame.new(at(side, ROOM_H / 2, (roomFront + roomBack) / 2 - WALL_T / 2)), ROOM_WALL)
		end
		part(roomFolder, "Ceiling", Vector3.new(ROOM_W + WALL_T * 2, 1, ROOM_D + WALL_T), CFrame.new(at(cx, ROOM_H + 0.5, (roomFront + roomBack) / 2 - WALL_T / 2)), ROOM_WALL)

		-- Glowing floor pad and lights that change color with the party's state.
		local base = deco(part(roomFolder, "Pad", Vector3.new(ROOM_W - 1, 0.2, ROOM_D - 1), CFrame.new(at(cx, 0.1, (roomFront + roomBack) / 2)), OPEN_GREEN))
		base.Transparency = 0.3
		local border = {
			deco(part(roomFolder, "Light", Vector3.new(ROOM_W - 4, 0.3, 1), CFrame.new(at(cx, ROOM_H - 0.2, (roomFront + roomBack) / 2)), OPEN_GREEN, Enum.Material.Neon)),
			deco(part(roomFolder, "DoorPost", Vector3.new(0.6, DOOR_H, 0.6), CFrame.new(at(cx - DOOR_W / 2 - 0.3, DOOR_H / 2, -HALF_D + 0.3)), OPEN_GREEN, Enum.Material.Neon)),
			deco(part(roomFolder, "DoorPost", Vector3.new(0.6, DOOR_H, 0.6), CFrame.new(at(cx + DOOR_W / 2 + 0.3, DOOR_H / 2, -HALF_D + 0.3)), OPEN_GREEN, Enum.Material.Neon)),
			deco(part(roomFolder, "DoorTop", Vector3.new(DOOR_W + 1.2, 0.6, 0.6), CFrame.new(at(cx, DOOR_H + 0.3, -HALF_D + 0.3)), OPEN_GREEN, Enum.Material.Neon)),
		}
		local light = Instance.new("PointLight")
		light.Range = 18
		light.Brightness = 1.5
		light.Color = OPEN_GREEN
		light.Parent = border[1]

		-- Sign above the doorway, facing the hall.
		local gui = LobbyBuilder.sign(roomFolder, at(cx, DOOR_H + 3.6, -HALF_D + 0.25), Vector3.new(0, 0, 1), ROOM_W - 1, 5, Color3.fromRGB(30, 30, 38))
		local title = LobbyBuilder.label(gui, "PARTY " .. index, 0.05, 0.5)
		local detail = LobbyBuilder.label(gui, "", 0.55, 0.38)

		table.insert(doorEdges, cx - DOOR_W / 2)
		table.insert(doorEdges, cx + DOOR_W / 2)
		table.insert(pads, {
			index = index,
			minX = center.X + x0,
			maxX = center.X + x1,
			minZ = center.Z + roomBack,
			maxZ = center.Z + roomFront + WALL_T, -- includes standing in the doorway
			base = base,
			border = border,
			title = title,
			detail = detail,
		})
	end

	-- North wall: solid between doorways, with lintels over them.
	local edges = { -HALF_W - WALL_T }
	for _, edge in doorEdges do
		table.insert(edges, edge)
	end
	table.insert(edges, HALF_W + WALL_T)
	for i = 1, #edges - 1, 2 do
		local a, b = edges[i], edges[i + 1]
		wall("NorthWall", Vector3.new(b - a, WALL_H, WALL_T), at((a + b) / 2, WALL_H / 2, northZ))
	end
	for i = 2, #edges - 1, 2 do
		local a, b = edges[i], edges[i + 1]
		wall("Lintel", Vector3.new(b - a, WALL_H - DOOR_H, WALL_T), at((a + b) / 2, DOOR_H + (WALL_H - DOOR_H) / 2, northZ))
	end
	deco(part(folder, "Trim", Vector3.new(HALF_W * 2 + WALL_T * 2, 1, WALL_T + 0.6), CFrame.new(at(0, WALL_H, northZ)), STONE_DARK))

	-- Title over the party rooms.
	local titleGui = LobbyBuilder.sign(folder, at(0, 21.5, -HALF_D + 0.25), Vector3.new(0, 0, 1), 64, 9, Color3.fromRGB(30, 30, 38))
	LobbyBuilder.label(titleGui, string.upper(Config.GAME_NAME), 0.04, 0.6, Color3.fromRGB(240, 196, 60))
	LobbyBuilder.label(titleGui, "Walk into a party room to play", 0.66, 0.28)

	-- Score boards: two on each side wall, facing into the hall.
	local boards = {
		CFrame.lookAt(at(-HALF_W + 0.25, 9, -18), at(-HALF_W + 1.25, 9, -18)),
		CFrame.lookAt(at(-HALF_W + 0.25, 9, 18), at(-HALF_W + 1.25, 9, 18)),
		CFrame.lookAt(at(HALF_W - 0.25, 9, -18), at(HALF_W - 1.25, 9, -18)),
		CFrame.lookAt(at(HALF_W - 0.25, 9, 18), at(HALF_W - 1.25, 9, 18)),
	}

	-- Enemy statues along the south wall.
	statue(folder, "Zombie", at(-56, 0, 40))
	statue(folder, "Runner", at(-34, 0, 42))
	statue(folder, "Devil", at(0, 0, 43))
	statue(folder, "Mummy", at(34, 0, 42))
	statue(folder, "Vampire", at(56, 0, 40))

	-- Spawn points in the middle of the hall, facing the party rooms.
	local spawns: { CFrame } = {}
	for row = 0, 1 do
		for column = -3, 3 do
			table.insert(spawns, CFrame.new(at(column * 5, 4, 22 + row * 6)))
		end
	end

	folder.Parent = workspace
	return { folder = folder, pads = pads, boards = boards, spawns = spawns }
end

return LobbyBuilder
