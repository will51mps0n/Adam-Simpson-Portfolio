--!strict
-- Shared look for every screen: chunky FredokaOne text, white with a dark outline.

local Players = game:GetService("Players")

local UI = {}

UI.FONT = Enum.Font.FredokaOne
UI.WHITE = Color3.new(1, 1, 1)
UI.DARK = Color3.fromRGB(22, 22, 28)
UI.PANEL = Color3.fromRGB(36, 36, 46)
UI.BUTTON = Color3.fromRGB(60, 60, 74)
UI.ACCENT = Color3.fromRGB(232, 170, 40)

function UI.screen(name: string, displayOrder: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function UI.round(object: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
end

function UI.text(parent: Instance, text: string, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = UI.FONT
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = UI.WHITE
	label.TextStrokeColor3 = UI.DARK
	label.TextStrokeTransparency = 0
	label.Parent = parent
	return label
end

function UI.button(parent: Instance, text: string, textSize: number): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = UI.BUTTON
	button.Font = UI.FONT
	button.Text = text
	button.TextSize = textSize
	button.TextColor3 = UI.WHITE
	button.TextStrokeColor3 = UI.DARK
	button.TextStrokeTransparency = 0
	UI.round(button, 10)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = UI.DARK
	stroke.Thickness = 2
	stroke.Parent = button
	button.Parent = parent
	return button
end

return UI
