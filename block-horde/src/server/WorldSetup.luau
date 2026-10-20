--!strict
-- One-time world setup: the dark ground around every room and collision rules.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldSetup = {}

WorldSetup.PLAYER_GROUP = "Players"

function WorldSetup.start()
	-- Players walk through each other, so co-op partners never block a corridor.
	PhysicsService:RegisterCollisionGroup(WorldSetup.PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(WorldSetup.PLAYER_GROUP, WorldSetup.PLAYER_GROUP, false)

	-- Dark ground under and around the rooms, so the overhead camera never sees sky.
	local void = Instance.new("Part")
	void.Name = "Void"
	void.Anchored = true
	void.Size = Vector3.new(2048, 1, 2048)
	void.CFrame = CFrame.new(0, -2, 0)
	void.Color = Config.VOID_COLOR
	void.Material = Enum.Material.SmoothPlastic
	void.TopSurface = Enum.SurfaceType.Smooth
	void.BottomSurface = Enum.SurfaceType.Smooth
	void.CastShadow = false
	void.Parent = workspace
end

return WorldSetup
