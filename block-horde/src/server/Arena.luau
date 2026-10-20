--!strict
-- Owns the room being played: builds it and keeps its grid for hit tests and spawns.
-- Clients rebuild the same grid from the RoomId attribute on ReplicatedStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RoomGrid = require(ReplicatedStorage.Shared.RoomGrid)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local RoomBuilder = require(script.Parent.RoomBuilder)

local Arena = {}

local current: RoomGrid.RoomGrid? = nil

function Arena.load(roomId: string): RoomGrid.RoomGrid
	local def = Rooms[roomId]
	assert(def, "Unknown room: " .. roomId)
	local grid = RoomGrid.new(def, Config.CELL_SIZE)
	RoomBuilder.build(grid)
	current = grid
	ReplicatedStorage:SetAttribute("RoomId", roomId)
	return grid
end

function Arena.grid(): RoomGrid.RoomGrid
	return assert(current, "No room loaded")
end

return Arena
