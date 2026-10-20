--!strict
-- The client's copy of the current arena grid, rebuilt from the RoomId
-- attribute the server sets. Fake walls players drop are mirrored into it so
-- instant tracers stop at them, and barrels are listed for the same reason.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RoomGrid = require(Shared:WaitForChild("RoomGrid"))
local Rooms = require(Shared:WaitForChild("Rooms"))

export type Circle = { x: number, z: number, radius: number }

local ClientArena = {}

local current: RoomGrid.RoomGrid? = nil

local function propsFolder(): Instance?
	local arena = workspace:FindFirstChild("Arena")
	return arena and arena:FindFirstChild("Props")
end

local function syncWalls()
	local grid = current
	local props = propsFolder()
	if not grid or not props then
		return
	end
	-- Start from the plain map, then add every fake wall standing now.
	for r = 1, grid.height do
		for c = 1, grid.width do
			grid:setBlocked(c, r, grid:cell(c, r) == "#")
		end
	end
	for _, model in props:GetChildren() do
		local c, r = model:GetAttribute("CellC"), model:GetAttribute("CellR")
		if model:GetAttribute("Kind") == "wall" and typeof(c) == "number" and typeof(r) == "number" then
			grid:setBlocked(c, r, true)
		end
	end
end

local function rebuild()
	local roomId = ReplicatedStorage:GetAttribute("RoomId")
	if typeof(roomId) == "string" and Rooms.ARENAS[roomId] then
		current = RoomGrid.new(Rooms.ARENAS[roomId], Config.CELL_SIZE)
		syncWalls()
	else
		current = nil
	end
end

local function watchArena(arena: Instance)
	local props = arena:WaitForChild("Props", 10)
	if props then
		props.ChildAdded:Connect(syncWalls)
		props.ChildRemoved:Connect(syncWalls)
		syncWalls()
	end
end

function ClientArena.grid(): RoomGrid.RoomGrid?
	return current
end

function ClientArena.barrels(): { Circle }
	local list: { Circle } = {}
	local props = propsFolder()
	if props then
		for _, model in props:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("Kind") == "barrel" then
				local p = model:GetPivot().Position
				table.insert(list, { x = p.X, z = p.Z, radius = Config.BARREL_RADIUS })
			end
		end
	end
	return list
end

function ClientArena.start()
	rebuild()
	ReplicatedStorage:GetAttributeChangedSignal("RoomId"):Connect(rebuild)
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Arena" then
			task.spawn(watchArena, child)
		end
	end)
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		task.spawn(watchArena, arena)
	end
end

return ClientArena
