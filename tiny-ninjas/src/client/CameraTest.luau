--!strict
-- Milestone 1 test helper; real ninjas replace it in milestone 2.
--  * Press 1 or 2 (or click the bar at the bottom) to switch between the test levels.
--  * In the big arena, two balls stand in for players: move the red one with WASD and
--    the blue one with the arrow keys, and the follow camera keeps both in view.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local CameraController = require(script.Parent.CameraController)
local LevelController = require(script.Parent.LevelController)

local TEST_LEVELS = { "test_shapes", "test_arena" }
local MARKER_SPEED = 30 -- studs per second

type MarkerKeys = {
	left: Enum.KeyCode,
	right: Enum.KeyCode,
	up: Enum.KeyCode,
	down: Enum.KeyCode,
	color: Color3,
}

local MARKER_KEYS: { MarkerKeys } = {
	{
		left = Enum.KeyCode.A,
		right = Enum.KeyCode.D,
		up = Enum.KeyCode.W,
		down = Enum.KeyCode.S,
		color = Color3.fromRGB(225, 60, 60),
	},
	{
		left = Enum.KeyCode.Left,
		right = Enum.KeyCode.Right,
		up = Enum.KeyCode.Up,
		down = Enum.KeyCode.Down,
		color = Color3.fromRGB(50, 110, 230),
	},
}

local CameraTest = {}

local levelIndex = 1
local markers: { BasePart } = {}
local bar: TextButton? = nil

local function makeBar(): TextButton
	local gui = Instance.new("ScreenGui")
	gui.Name = "CameraTest"
	gui.ResetOnSpawn = false

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -8)
	button.Size = UDim2.new(0.95, 0, 0, 28)
	button.BackgroundColor3 = Color3.new(0, 0, 0)
	button.BackgroundTransparency = 0.45
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 14
	button.TextScaled = false
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.Parent = gui

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(640, 28)
	limit.Parent = button
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return button
end

local function makeMarker(color: Color3, position: Vector3, parent: Instance): BasePart
	local marker = Instance.new("Part")
	marker.Name = "TestMarker"
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.one * 2.5
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.Material = Enum.Material.SmoothPlastic
	marker.Color = color
	marker.Position = position
	marker.Parent = parent
	return marker
end

local function markerPositions(): { Vector3 }
	local list = {}
	for _, marker in markers do
		table.insert(list, marker.Position)
	end
	return list
end

local function loadLevel(index: number)
	levelIndex = index
	local built = LevelController.load(TEST_LEVELS[index])
	table.clear(markers)

	local text
	if built.cameraMode == "follow" then
		local spawns = {}
		for _, object in built.def.objects do
			if object.type == "spawn" then
				table.insert(spawns, object)
			end
		end
		for i, keys in MARKER_KEYS do
			local spawn = spawns[i] or spawns[1]
			local x = if spawn then spawn.x else built.grid.width / 2
			local y = if spawn then spawn.y else built.grid.height / 2
			local position = Units.toWorld((x + 0.5) * Config.TILE_PX, (y + 0.5) * Config.TILE_PX, built.frontZ + 1)
			markers[i] = makeMarker(keys.color, position, built.model)
		end
		CameraController.setTargets(markerPositions)
		text = `{built.def.name}: move red with WASD, blue with the arrow keys. Press 1 / 2 to switch level`
	else
		CameraController.setTargets(nil)
		text = `{built.def.name}: the whole level fits on screen. Press 1 / 2 or click here to switch level`
	end
	if bar then
		bar.Text = text
	end
end

local function moveMarkers(dt: number)
	local built = LevelController.current()
	if not built then
		return
	end
	local function axis(negative: Enum.KeyCode, positive: Enum.KeyCode): number
		return (if UserInputService:IsKeyDown(positive) then 1 else 0)
			- (if UserInputService:IsKeyDown(negative) then 1 else 0)
	end
	for i, marker in markers do
		local keys = MARKER_KEYS[i]
		local direction = Vector3.new(axis(keys.left, keys.right), axis(keys.down, keys.up), 0)
		if direction.Magnitude > 0 then
			local p = marker.Position + direction.Unit * MARKER_SPEED * dt
			marker.Position = Vector3.new(
				math.clamp(p.X, built.boundsMin.X, built.boundsMax.X),
				math.clamp(p.Y, built.boundsMin.Y, built.boundsMax.Y),
				p.Z
			)
		end
	end
end

function CameraTest.start()
	local button = makeBar()
	bar = button
	button.Activated:Connect(function()
		loadLevel(levelIndex % #TEST_LEVELS + 1)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.One then
			loadLevel(1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			loadLevel(2)
		end
	end)
	RunService.Heartbeat:Connect(moveMarkers)
	loadLevel(1)
end

return CameraTest
