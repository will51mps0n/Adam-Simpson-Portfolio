--!strict
-- The party panel in the lobby, shown while you stand on a party pad.
-- The leader picks the room, difficulty, party size and friends-only, then
-- presses START; everyone else sees the choices and waits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Rooms = require(Shared:WaitForChild("Rooms"))
local UI = require(script.Parent.UI)

local PartyAction = Net.event("PartyAction")

local PartyUI = {}

type Picker = { label: TextLabel, left: TextButton, right: TextButton }

local GREEN = Color3.fromRGB(60, 170, 80)
local RED = Color3.fromRGB(196, 58, 40)

function PartyUI.start()
	local gui = UI.screen("Party", 8)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.fromOffset(300, 384)
	panel.BackgroundColor3 = UI.PANEL
	panel.BackgroundTransparency = 0.08
	panel.Visible = false
	UI.round(panel, 14)
	panel.Parent = gui

	local function text(content: string, size: number, y: number, height: number): TextLabel
		local label = UI.text(panel, content, size)
		label.Position = UDim2.fromOffset(12, y)
		label.Size = UDim2.new(1, -24, 0, height)
		label.TextWrapped = true
		return label
	end

	local title = text("PARTY", 28, 8, 34)
	local leaderLabel = text("", 16, 42, 20)
	local membersLabel = text("", 15, 62, 40)

	local function picker(caption: string, y: number): Picker
		text(caption, 14, y, 18).TextColor3 = Color3.fromRGB(200, 200, 210)
		local left = UI.button(panel, "<", 22)
		left.Position = UDim2.fromOffset(12, y + 20)
		left.Size = UDim2.fromOffset(40, 34)
		local right = UI.button(panel, ">", 22)
		right.Position = UDim2.new(1, -52, 0, y + 20)
		right.Size = UDim2.fromOffset(40, 34)
		local value = UI.text(panel, "", 22)
		value.Position = UDim2.fromOffset(56, y + 20)
		value.Size = UDim2.new(1, -112, 0, 34)
		return { label = value, left = left, right = right }
	end

	local roomPicker = picker("ROOM", 104)
	local difficultyPicker = picker("DIFFICULTY", 162)
	local sizePicker = picker("PARTY SIZE", 220)

	local friendsButton = UI.button(panel, "FRIENDS ONLY: OFF", 18)
	friendsButton.Position = UDim2.fromOffset(12, 282)
	friendsButton.Size = UDim2.new(1, -24, 0, 34)

	local startButton = UI.button(panel, "START", 24)
	startButton.Position = UDim2.fromOffset(12, 324)
	startButton.Size = UDim2.new(1, -24, 0, 44)
	startButton.BackgroundColor3 = GREEN
	local waitingLabel = text("", 18, 324, 44)

	local state: any = nil

	local function step(list: { string }, current: string, delta: number): string
		local index = table.find(list, current) or 1
		return list[(index - 1 + delta) % #list + 1]
	end

	roomPicker.left.Activated:Connect(function()
		if state then
			PartyAction:FireServer("room", step(Rooms.ORDER, state.room, -1))
		end
	end)
	roomPicker.right.Activated:Connect(function()
		if state then
			PartyAction:FireServer("room", step(Rooms.ORDER, state.room, 1))
		end
	end)
	difficultyPicker.left.Activated:Connect(function()
		if state then
			PartyAction:FireServer("difficulty", step(Config.DIFFICULTY_ORDER, state.difficulty, -1))
		end
	end)
	difficultyPicker.right.Activated:Connect(function()
		if state then
			PartyAction:FireServer("difficulty", step(Config.DIFFICULTY_ORDER, state.difficulty, 1))
		end
	end)
	sizePicker.left.Activated:Connect(function()
		if state then
			PartyAction:FireServer("size", state.size - 1)
		end
	end)
	sizePicker.right.Activated:Connect(function()
		if state then
			PartyAction:FireServer("size", state.size + 1)
		end
	end)
	friendsButton.Activated:Connect(function()
		if state then
			PartyAction:FireServer("friends", not state.friendsOnly)
		end
	end)
	startButton.Activated:Connect(function()
		if state then
			PartyAction:FireServer(if state.countdown then "cancel" else "start")
		end
	end)

	Net.event("PartyState").OnClientEvent:Connect(function(newState: any)
		state = newState
		if not newState then
			panel.Visible = false
			return
		end
		panel.Visible = true
		local leader = newState.isLeader == true
		title.Text = "PARTY " .. tostring(newState.pad)
		leaderLabel.Text = "Leader: " .. tostring(newState.leader)
		membersLabel.Text = table.concat(newState.members, ", ")
		local room = Rooms.ARENAS[newState.room]
		roomPicker.label.Text = if room then room.name else tostring(newState.room)
		difficultyPicker.label.Text = string.upper(tostring(newState.difficulty))
		sizePicker.label.Text = tostring(#newState.members) .. " / " .. tostring(newState.size)
		for _, pick in { roomPicker, difficultyPicker, sizePicker } do
			pick.left.Visible = leader
			pick.right.Visible = leader
		end
		friendsButton.Text = "FRIENDS ONLY: " .. (if newState.friendsOnly then "ON" else "OFF")
		friendsButton.BackgroundColor3 = if newState.friendsOnly then GREEN else UI.BUTTON
		friendsButton.AutoButtonColor = leader
		friendsButton.Active = leader

		local countdown = newState.countdown
		startButton.Visible = leader
		if countdown then
			startButton.Text = "CANCEL (" .. tostring(countdown) .. ")"
			startButton.BackgroundColor3 = RED
		else
			startButton.Text = "START"
			startButton.BackgroundColor3 = GREEN
		end
		waitingLabel.Visible = not leader
		waitingLabel.Text = if countdown then "STARTING IN " .. tostring(countdown) else "Waiting for the leader to start.\nWalk out of the room to leave."
	end)
end

return PartyUI
