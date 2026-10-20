--!strict
-- Owns the arena room being played: builds it and keeps its grid for hit
-- tests, pathfinding and spawns. Clients rebuild the same grid from the
-- RoomId attribute on ReplicatedStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RoomGrid = require(ReplicatedStorage.Shared.RoomGrid)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local RoomBuilder = require(script.Parent.RoomBuilder)

local Arena = {}

Arena.FOLDER = "Arena"

local current: RoomGrid.RoomGrid? = nil

function Arena.load(roomId: string): RoomGrid.RoomGrid
	local def = Rooms.ARENAS[roomId]
	assert(def, "Unknown room: " .. roomId)
	local grid = RoomGrid.new(def, Config.CELL_SIZE)
	local folder = RoomBuilder.build(grid, Arena.FOLDER)
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = folder
	current = grid
	ReplicatedStorage:SetAttribute("RoomId", roomId)
	return grid
end

function Arena.grid(): RoomGrid.RoomGrid
	return assert(current, "No arena loaded")
end

function Arena.loaded(): boolean
	return current ~= nil
end

-- Folder for placeables and ammo crates, cleared with the room.
function Arena.props(): Instance
	local folder = workspace:FindFirstChild(Arena.FOLDER)
	local props = folder and folder:FindFirstChild("Props")
	return assert(props, "No arena loaded")
end

-- World position of a spawn cell for the given player slot.
function Arena.spawnFor(slot: number): CFrame
	local grid = Arena.grid()
	local cells = grid:find("P")
	local cell = cells[(slot - 1) % #cells + 1]
	local x, z = grid:cellCenter(cell.c, cell.r)
	return CFrame.new(x, 3.5, z)
end

return Arena
