--!strict
-- A SETTINGS button in the top right that opens a panel for switching
-- between Classic (keys only) and Mouse aim controls, with a control cheat sheet.

local Input = require(script.Parent.InputController)
local UI = require(script.Parent.UI)

local SettingsUI = {}

local HELP: { [string]: string } = {
	Classic = "WASD / Arrows: move and aim\nSpace: fire\n1-9, 0: pick weapon    Q / E: cycle\nP: pause (solo only)",
	Mouse = "WASD / Arrows: move\nMouse: aim    Click or Space: fire\n1-9, 0: pick weapon    Q / E: cycle\nP: pause (solo only)",
	Touch = "Left thumb: move and aim\nFIRE: shoot    SWAP: next weapon",
}

function SettingsUI.start()
	local gui = UI.screen("Settings", 10)

	local openButton = UI.button(gui, "SETTINGS", 16)
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(1, -12, 0, 12)
	openButton.Size = UDim2.fromOffset(110, 34)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(380, 300)
	panel.BackgroundColor3 = UI.PANEL
	panel.BackgroundTransparency = 0.08
	panel.Visible = false
	UI.round(panel, 14)
	panel.Parent = gui

	local title = UI.text(panel, "SETTINGS", 30)
	title.Position = UDim2.fromOffset(0, 12)
	title.Size = UDim2.new(1, 0, 0, 36)

	local controlsLabel = UI.text(panel, "CONTROLS", 18)
	controlsLabel.Position = UDim2.fromOffset(0, 58)
	controlsLabel.Size = UDim2.new(1, 0, 0, 24)

	local classicButton = UI.button(panel, "CLASSIC", 20)
	classicButton.Position = UDim2.fromOffset(20, 90)
	classicButton.Size = UDim2.fromOffset(165, 40)

	local mouseButton = UI.button(panel, "MOUSE AIM", 20)
	mouseButton.Position = UDim2.fromOffset(195, 90)
	mouseButton.Size = UDim2.fromOffset(165, 40)

	local help = UI.text(panel, "", 16)
	help.Position = UDim2.fromOffset(20, 142)
	help.Size = UDim2.new(1, -40, 0, 100)
	help.TextWrapped = true
	help.TextYAlignment = Enum.TextYAlignment.Top

	local closeButton = UI.button(panel, "CLOSE", 20)
	closeButton.AnchorPoint = Vector2.new(0.5, 1)
	closeButton.Position = UDim2.new(0.5, 0, 1, -14)
	closeButton.Size = UDim2.fromOffset(140, 38)

	local function refresh()
		local touch = Input.scheme == "Touch"
		classicButton.Visible = not touch
		mouseButton.Visible = not touch
		controlsLabel.Text = if touch then "TOUCH CONTROLS" else "CONTROLS"
		classicButton.BackgroundColor3 = if Input.scheme == "Classic" then UI.ACCENT else UI.BUTTON
		mouseButton.BackgroundColor3 = if Input.scheme == "Mouse" then UI.ACCENT else UI.BUTTON
		help.Text = HELP[Input.scheme] or ""
	end

	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refresh()
	end)
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)
	classicButton.Activated:Connect(function()
		Input.setScheme("Classic")
	end)
	mouseButton.Activated:Connect(function()
		Input.setScheme("Mouse")
	end)
	Input.SchemeChanged:Connect(refresh)
	refresh()
end

return SettingsUI
