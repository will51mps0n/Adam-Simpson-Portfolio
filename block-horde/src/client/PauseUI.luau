--!strict
-- Sends P presses to the server and shows a PAUSED overlay while paused.
-- Pausing only works with one player on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Input = require(script.Parent.InputController)
local UI = require(script.Parent.UI)

local PauseUI = {}

function PauseUI.start()
	local gui = UI.screen("Pause", 20)
	gui.IgnoreGuiInset = true

	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.Visible = false
	shade.Parent = gui

	local title = UI.text(shade, "PAUSED", 80)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.45)
	title.Size = UDim2.fromOffset(600, 90)

	local hint = UI.text(shade, "Press P to resume", 24)
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0.45, 56)
	hint.Size = UDim2.fromOffset(600, 30)

	local soloNote = UI.text(gui, "Pause only works when playing solo", 22)
	soloNote.AnchorPoint = Vector2.new(0.5, 0)
	soloNote.Position = UDim2.fromScale(0.5, 0.2)
	soloNote.Size = UDim2.fromOffset(600, 30)
	soloNote.Visible = false

	local function refresh()
		shade.Visible = workspace:GetAttribute("Paused") == true
	end
	workspace:GetAttributeChangedSignal("Paused"):Connect(refresh)
	refresh()

	local PauseRequest = Net.event("PauseRequest")
	local noteToken = 0
	Input.PausePressed:Connect(function()
		if #Players:GetPlayers() == 1 then
			PauseRequest:FireServer()
			return
		end
		noteToken += 1
		local token = noteToken
		soloNote.Visible = true
		task.delay(2, function()
			if token == noteToken then
				soloNote.Visible = false
			end
		end)
	end)
end

return PauseUI
