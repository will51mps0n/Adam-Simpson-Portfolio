--!strict
-- The client's copy of the current room grid, rebuilt from the RoomId attribute
-- the server sets. Used to stop instant tracers at walls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RoomGrid = require(Shared:WaitForChild("RoomGrid"))
local Rooms = require(Shared:WaitForChild("Rooms"))

local ClientArena = {}

local current: RoomGrid.RoomGrid? = nil

local function rebuild()
	local roomId = ReplicatedStorage:GetAttribute("RoomId")
	if typeof(roomId) == "string" and Rooms[roomId] then
		current = RoomGrid.new(Rooms[roomId], Config.CELL_SIZE)
	else
		current = nil
	end
end

function ClientArena.grid(): RoomGrid.RoomGrid?
	return current
end

function ClientArena.start()
	rebuild()
	ReplicatedStorage:GetAttributeChangedSignal("RoomId"):Connect(rebuild)
end

return ClientArena
