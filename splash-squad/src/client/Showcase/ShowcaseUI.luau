--!strict
-- On-screen buttons for the test stage: pick a kid, try every face and move,
-- and dress kids up from the wardrobe. Big chunky buttons that work by touch.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Face = require(ReplicatedStorage.Shared.Character.Face)

local ShowcaseUI = {}

export type Callbacks = {
	select: (index: number) -> (), -- 0 = everyone
	face: (expression: string) -> (),
	move: (move: string) -> (),
	toggle: (name: string, on: boolean) -> (),
	wardrobe: (field: string, step: number) -> (),
}

export type UI = {
	gui: ScreenGui,
	setSelected: (index: number) -> (),
	setWardrobe: (values: { [string]: string }?) -> (),
}

ShowcaseUI.WardrobeFields = {
	"Skin",
	"Hair",
	"Hair color",
	"Hat",
	"Top",
	"Top color",
	"Bottom",
	"Bottom color",
	"Shoes",
	"Shoe color",
	"Cape",
	"Goggles",
	"Life ring",
	"Mask",
}

ShowcaseUI.Moves = {
	{ id = "Aim", label = "Aim" },
	{ id = "Throw", label = "Throw!" },
	{ id = "Hit", label = "Get hit" },
	{ id = "Knock", label = "Splash!" },
	{ id = "Win", label = "Win dance" },
	{ id = "Reset", label = "Reset" },
}

local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(34, 22, 36)
local WHITE = Color3.new(1, 1, 1)
local COLORS = {
	tab = Color3.fromRGB(255, 255, 255),
	tabSelected = Color3.fromRGB(255, 214, 58),
	face = Color3.fromRGB(118, 196, 255),
	move = Color3.fromRGB(255, 120, 106),
	toggleOff = Color3.fromRGB(200, 214, 230),
	toggleOn = Color3.fromRGB(132, 232, 170),
	panel = Color3.fromRGB(255, 250, 238),
	arrow = Color3.fromRGB(255, 186, 36),
}
local REFERENCE = Vector2.new(1280, 720) -- layout is designed at this size and scaled

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, text: string, size: UDim2, textSize: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.Text = text
	l.TextSize = textSize
	l.TextColor3 = color or WHITE
	l.TextStrokeColor3 = INK
	l.TextStrokeTransparency = if color then 1 else 0
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, size: Vector2, color: Color3, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = text
	b.Size = UDim2.fromOffset(size.X, size.Y)
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Font = FONT
	b.Text = text
	b.TextSize = math.min(24, size.Y * 0.48)
	b.TextColor3 = WHITE
	b.TextStrokeColor3 = INK
	b.TextStrokeTransparency = 0
	b.Parent = parent
	corner(b, math.floor(size.Y * 0.3))
	stroke(b, 3)
	local pop = Instance.new("UIScale")
	pop.Parent = b
	b.Activated:Connect(function()
		pop.Scale = 0.88
		TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		onClick()
	end)
	return b
end

local function row(parent: Instance, name: string, position: UDim2, anchor: Vector2, padding: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.Size = UDim2.fromOffset(0, 0)
	f.Position = position
	f.AnchorPoint = anchor
	f.BackgroundTransparency = 1
	f.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, padding)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = f
	return f
end

function ShowcaseUI.build(names: { string }, callbacks: Callbacks): UI
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShowcaseUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Everything is laid out for 1280x720 and scaled to fit the screen.
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function fit()
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else REFERENCE
		local s = math.clamp(math.min(viewport.X / REFERENCE.X, viewport.Y / REFERENCE.Y), 0.62, 1.4)
		scale.Scale = s
		root.Size = UDim2.fromOffset(viewport.X / s, viewport.Y / s)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- Title
	local title = label(root, Config.GameName, UDim2.fromOffset(300, 40), 34)
	title.Position = UDim2.fromOffset(18, 12)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local subtitle = label(root, "Milestone 1 - meet the kids", UDim2.fromOffset(300, 22), 18)
	subtitle.Position = UDim2.fromOffset(20, 48)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left

	-- Kid tabs
	local tabs = row(root, "Tabs", UDim2.fromOffset(18, 80), Vector2.new(0, 0), 8)
	local tabButtons: { TextButton } = {}
	local allNames = { "Everyone" }
	for _, n in names do
		table.insert(allNames, n)
	end
	for i, n in allNames do
		local b = button(tabs, n, Vector2.new(30 + #n * 12, 42), COLORS.tab, function()
			callbacks.select(i - 1)
		end)
		b.LayoutOrder = i
		b.TextColor3 = INK
		b.TextStrokeTransparency = 1
		tabButtons[i] = b
	end

	-- Faces and moves along the bottom
	local faces = row(root, "Faces", UDim2.new(0.5, 0, 1, -76), Vector2.new(0.5, 1), 8)
	label(faces, "Faces", UDim2.fromOffset(78, 46), 22).LayoutOrder = 0
	for i, expression in Face.ExpressionOrder do
		button(faces, expression, Vector2.new(112, 46), COLORS.face, function()
			callbacks.face(expression)
		end).LayoutOrder = i
	end
	local moves = row(root, "Moves", UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1), 8)
	label(moves, "Moves", UDim2.fromOffset(78, 50), 22).LayoutOrder = 0
	for i, move in ShowcaseUI.Moves do
		button(moves, move.label, Vector2.new(128, 50), COLORS.move, function()
			callbacks.move(move.id)
		end).LayoutOrder = i
	end

	-- Toggles on the right
	local toggles = row(root, "Toggles", UDim2.new(1, -18, 0, 14), Vector2.new(1, 0), 8)
	local wardrobePanel: ScrollingFrame
	for i, name in { "Close-up", "Spin", "Wardrobe" } do
		local on = false
		local b: TextButton
		b = button(toggles, name, Vector2.new(124, 44), COLORS.toggleOff, function()
			on = not on
			b.BackgroundColor3 = if on then COLORS.toggleOn else COLORS.toggleOff
			if name == "Wardrobe" then
				wardrobePanel.Visible = on
			end
			callbacks.toggle(name, on)
		end)
		b.LayoutOrder = i
		b.TextColor3 = INK
		b.TextStrokeTransparency = 1
	end

	-- Wardrobe panel
	wardrobePanel = Instance.new("ScrollingFrame")
	wardrobePanel.Name = "Wardrobe"
	wardrobePanel.Visible = false
	wardrobePanel.AnchorPoint = Vector2.new(1, 0)
	wardrobePanel.Position = UDim2.new(1, -18, 0, 70)
	wardrobePanel.Size = UDim2.new(0, 330, 1, -224)
	wardrobePanel.BackgroundColor3 = COLORS.panel
	wardrobePanel.ScrollBarThickness = 8
	wardrobePanel.ScrollBarImageColor3 = INK
	wardrobePanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	wardrobePanel.CanvasSize = UDim2.new()
	wardrobePanel.Parent = root
	corner(wardrobePanel, 16)
	stroke(wardrobePanel, 3)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = wardrobePanel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = wardrobePanel

	local hint = label(wardrobePanel, "Pick one kid to dress up!", UDim2.new(1, 0, 0, 40), 20, INK)
	hint.LayoutOrder = 0
	local valueLabels: { [string]: TextLabel } = {}
	local rowsFrames: { Frame } = {}
	for i, field in ShowcaseUI.WardrobeFields do
		local r = Instance.new("Frame")
		r.Name = field
		r.Size = UDim2.new(1, 0, 0, 40)
		r.BackgroundTransparency = 1
		r.LayoutOrder = i
		r.Parent = wardrobePanel
		local name = label(r, field, UDim2.fromOffset(104, 40), 17, INK)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local left = button(r, "<", Vector2.new(36, 36), COLORS.face, function()
			callbacks.wardrobe(field, -1)
		end)
		left.Position = UDim2.fromOffset(104, 2)
		local value = label(r, "-", UDim2.fromOffset(122, 40), 16, INK)
		value.Position = UDim2.fromOffset(142, 0)
		value.TextScaled = false
		value.TextWrapped = true
		valueLabels[field] = value
		local right = button(r, ">", Vector2.new(36, 36), COLORS.face, function()
			callbacks.wardrobe(field, 1)
		end)
		right.Position = UDim2.fromOffset(266, 2)
		table.insert(rowsFrames, r)
	end
	local extras = row(wardrobePanel, "Extras", UDim2.new(), Vector2.new(), 8)
	extras.LayoutOrder = #ShowcaseUI.WardrobeFields + 1
	button(extras, "Random", Vector2.new(140, 42), COLORS.move, function()
		callbacks.wardrobe("Random", 1)
	end)
	button(extras, "Undo all", Vector2.new(140, 42), COLORS.toggleOff, function()
		callbacks.wardrobe("Reset", 1)
	end).TextColor3 = INK

	gui.Parent = player:WaitForChild("PlayerGui")

	local ui: UI = {
		gui = gui,
		setSelected = function(index: number)
			for i, b in tabButtons do
				b.BackgroundColor3 = if i - 1 == index then COLORS.tabSelected else COLORS.tab
			end
		end,
		setWardrobe = function(values: { [string]: string }?)
			hint.Visible = values == nil
			extras.Visible = values ~= nil
			for _, r in rowsFrames do
				r.Visible = values ~= nil
			end
			if values then
				for field, l in valueLabels do
					l.Text = values[field] or "-"
				end
			end
		end,
	}
	ui.setSelected(0)
	ui.setWardrobe(nil)
	return ui
end

return ShowcaseUI
