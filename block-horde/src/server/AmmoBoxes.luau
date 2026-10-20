--!strict
-- Wooden ammo crates appear on the room's 'A' cells every AMMO_BOX_INTERVAL
-- seconds (at most AMMO_BOX_MAX at once). Walking over one refills part of
-- every weapon you own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local PropModels = require(ReplicatedStorage.Shared.Models.PropModels)
local RoomGrid = require(ReplicatedStorage.Shared.RoomGrid)
local Arena = require(script.Parent.Arena)
local Loadout = require(script.Parent.Loadout)
local Placeables = require(script.Parent.Placeables)
local RunState = require(script.Parent.RunState)

local Announce = Net.event("Announce")

type Crate = { c: number, r: number, x: number, z: number, model: Model }

local AmmoBoxes = {}

local grid: RoomGrid.RoomGrid? = nil
local crates: { Crate } = {}
local timer = 0
local rng = Random.new()

function AmmoBoxes.start(g: RoomGrid.RoomGrid)
	AmmoBoxes.clear()
	grid = g
	timer = Config.AMMO_BOX_INTERVAL
end

function AmmoBoxes.clear()
	for _, crate in crates do
		crate.model:Destroy()
	end
	table.clear(crates)
end

local function spawnCrate(g: RoomGrid.RoomGrid)
	local free: { RoomGrid.Cell } = {}
	for _, cell in g:find("A") do
		local taken = false
		for _, crate in crates do
			if crate.c == cell.c and crate.r == cell.r then
				taken = true
			end
		end
		if not taken and not g:isBlocked(cell.c, cell.r) then
			local blocking = false
			for _, placeable in Placeables.list() do
				if placeable.c == cell.c and placeable.r == cell.r then
					blocking = true
				end
			end
			if not blocking then
				table.insert(free, cell)
			end
		end
	end
	if #free == 0 then
		return
	end
	local cell = free[rng:NextInteger(1, #free)]
	local x, z = g:cellCenter(cell.c, cell.r)
	local model = PropModels.ammoCrate(CFrame.new(x, 0, z))
	model.Parent = Arena.props()
	table.insert(crates, { c = cell.c, r = cell.r, x = x, z = z, model = model })
end

function AmmoBoxes.update(dt: number)
	local g = grid
	if not g then
		return
	end
	timer -= dt
	if timer <= 0 then
		timer = Config.AMMO_BOX_INTERVAL
		if #crates < Config.AMMO_BOX_MAX then
			spawnCrate(g)
		end
	end

	local reach = Config.AMMO_BOX_PICKUP_RADIUS
	for _, participant in RunState.alive() do
		local character = participant.player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end
		for i = #crates, 1, -1 do
			local crate = crates[i]
			local dx, dz = root.Position.X - crate.x, root.Position.Z - crate.z
			if dx * dx + dz * dz <= reach * reach then
				crate.model:Destroy()
				table.remove(crates, i)
				Loadout.refill(participant.player, Config.AMMO_BOX_REFILL)
				Announce:FireClient(participant.player, "AMMO", "pickup")
			end
		end
	end
end

return AmmoBoxes
