--!strict
-- The results screen when a run ends: wave reached, room and difficulty,
-- and every player's score and kills, with a countdown back to the lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Rooms = require(Shared:WaitForChild("Rooms"))
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local GameOverUI = {}

local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

function GameOverUI.start()
	local gui = UI.screen("GameOver", 12)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(480, 300)
	panel.BackgroundColor3 = UI.PANEL
	panel.BackgroundTransparency = 0.08
	panel.Visible = false
	UI.round(panel, 14)
	panel.Parent = gui

	local title = UI.text(panel, "GAME OVER", 56)
	title.Position = UDim2.fromOffset(0, 10)
	title.Size = UDim2.new(1, 0, 0, 60)
	title.TextColor3 = Color3.fromRGB(230, 50, 40)
	local subtitle = UI.text(panel, "", 20)
	subtitle.Position = UDim2.fromOffset(0, 70)
	subtitle.Size = UDim2.new(1, 0, 0, 24)
	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(24, 104)
	rows.Size = UDim2.new(1, -48, 1, -150)
	rows.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = rows
	local footer = UI.text(panel, "", 18)
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 0, 1, -10)
	footer.Size = UDim2.new(1, 0, 0, 24)

	local token = 0
	Net.event("RunResults").OnClientEvent:Connect(function(summary: any)
		token += 1
		local mine = token
		for _, child in rows:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local room = Rooms.ARENAS[summary.room]
		subtitle.Text = "WAVE " .. tostring(summary.wave) .. "  -  " .. (if room then room.name else "") .. "  -  " .. string.upper(tostring(summary.difficulty))
		for rank, result in summary.players do
			local line = UI.text(rows, string.format("%d.  %s     %s pts     %d kills", rank, result.name, formatNumber(result.score), result.kills), 20)
			line.Size = UDim2.new(1, 0, 0, 28)
			line.LayoutOrder = rank
			if result.userId == player.UserId then
				line.TextColor3 = Color3.fromRGB(255, 214, 60)
			end
		end
		panel.Size = UDim2.fromOffset(480, 160 + #summary.players * 32)
		panel.Visible = true
		local seconds = tonumber(summary.returnIn) or 10
		task.spawn(function()
			for left = seconds, 1, -1 do
				if token ~= mine then
					return
				end
				footer.Text = "Back to the lobby in " .. left
				task.wait(1)
			end
			if token == mine then
				panel.Visible = false
			end
		end)
	end)
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		if player:GetAttribute("InRun") == true then
			panel.Visible = false
		end
	end)
end

return GameOverUI
