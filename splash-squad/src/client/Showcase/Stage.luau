--!strict
-- The milestone 1 test stage: a wooden dock over turquoise water.
-- (The real beach, rafts and sky arrive in milestone 2.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Shapes = require(ReplicatedStorage.Shared.Character.Shapes)

local Stage = {}

Stage.DockY = 1.4 -- height of the dock's deck (kids stand here)
Stage.DockLeft = -16.5
Stage.DockRight = 16.5

local WOOD = {
	Color3.fromRGB(205, 150, 94),
	Color3.fromRGB(188, 134, 82),
	Color3.fromRGB(214, 160, 104),
}
local DARK_WOOD = Color3.fromRGB(140, 92, 56)
local ROPE = Color3.fromRGB(236, 210, 150)

local function cylinder(name: string, length: number, diameter: number, color: Color3, cf: CFrame, parent: Instance): Part
	local part = Shapes.block(name, Vector3.new(length, diameter, diameter), color, parent)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = cf
	return part
end

function Stage.build(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "TestStage"

	local water = Shapes.block("Water", Vector3.new(1200, 2, 1200), Color3.fromRGB(52, 196, 214), folder)
	water.CFrame = CFrame.new(0, Config.World.WaterY - 1, 0)
	water.CastShadow = false

	local length = Stage.DockRight - Stage.DockLeft
	local middle = (Stage.DockLeft + Stage.DockRight) / 2
	for i, z in { -2.1, 0, 2.1 } do
		local board = Shapes.block("Board", Vector3.new(length, 0.5, 1.95), WOOD[i], folder)
		board.CFrame = CFrame.new(middle, Stage.DockY - 0.25, z)
	end
	local beam = Shapes.block("Beam", Vector3.new(length + 0.4, 0.7, 0.5), DARK_WOOD, folder)
	beam.CFrame = CFrame.new(middle, Stage.DockY - 0.85, 3.05)

	-- Posts with rounded caps and a rope wrap.
	local posts = 7
	for i = 0, posts - 1 do
		local x = Stage.DockLeft + 0.3 + (length - 0.6) * i / (posts - 1)
		for _, z in { 3.3, -3.3 } do
			local top = Stage.DockY + 0.6
			local bottom = Config.World.WaterY - 4
			cylinder("Post", top - bottom, 0.9, DARK_WOOD, CFrame.new(x, (top + bottom) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), folder)
			local cap = Shapes.ellipsoid("PostCap", Vector3.new(0.9, 0.45, 0.9), DARK_WOOD, folder)
			cap.CFrame = CFrame.new(x, top, z)
			cylinder("Rope", 0.3, 1.0, ROPE, CFrame.new(x, top - 0.5, z) * CFrame.Angles(0, 0, math.rad(90)), folder)
		end
	end

	-- A little sign standing in the water past the end of the dock.
	local signX = Stage.DockRight + 2.4
	local sign = Shapes.block("Sign", Vector3.new(4.2, 1.4, 0.25), Color3.fromRGB(250, 236, 200), folder)
	sign.CFrame = CFrame.new(signX, Stage.DockY + 1.9, 0) * CFrame.Angles(0, math.rad(-12), 0)
	for _, dx in { -1.5, 1.5 } do
		local bottom = Config.World.WaterY - 3
		local top = Stage.DockY + 1.9
		cylinder(
			"SignPost",
			top - bottom,
			0.3,
			DARK_WOOD,
			CFrame.new(signX + dx, (top + bottom) / 2, -0.2) * CFrame.Angles(0, 0, math.rad(90)),
			folder
		)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- the side facing the camera (+Z)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.5
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.Text = Config.GameName
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 120, 96)
	text.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.Parent = text

	folder.Parent = workspace
	return folder
end

return Stage
