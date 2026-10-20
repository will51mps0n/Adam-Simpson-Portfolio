--!strict
-- Floating high score boards in the lobby, one per difficulty, each cycling
-- through the rooms. Data is fetched slowly in the background to stay inside
-- Roblox's DataStore request budget.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local HighScores = require(script.Parent.HighScores)
local LobbyBuilder = require(script.Parent.LobbyBuilder)

type Board = { difficulty: string, title: TextLabel, rows: { TextLabel }, roomIndex: number }
type Cached = { rows: { HighScores.Row }?, fetchedAt: number }

local Scoreboards = {}

local FETCH_GAP = 15 -- seconds between DataStore reads (budget: 5 + 2 per player per minute)
local STALE_AFTER = 300

local boards: { Board } = {}
local cache: { [string]: Cached } = {}
local wanted: { string } = {}

local function key(roomId: string, difficulty: string): string
	return roomId .. "|" .. difficulty
end

local function render(board: Board)
	local roomId = Rooms.ORDER[board.roomIndex]
	board.title.Text = Rooms.ARENAS[roomId].name .. "  -  " .. string.upper(board.difficulty)
	local entry = cache[key(roomId, board.difficulty)]
	for i, row in board.rows do
		local data = entry and entry.rows and entry.rows[i]
		if data then
			row.Text = string.format("%d. %s   %d", i, data.name, data.score)
		elseif i == 1 then
			row.Text = if entry == nil then "loading..." elseif entry.rows == nil then "scores need a published game" else "no scores yet"
		else
			row.Text = ""
		end
	end
	local entryKey = key(roomId, board.difficulty)
	if (entry == nil or os.clock() - entry.fetchedAt > STALE_AFTER) and not table.find(wanted, entryKey) then
		table.insert(wanted, entryKey)
	end
end

function Scoreboards.start(anchors: { Vector3 }, parent: Instance)
	for i, at in anchors do
		local difficulty = Config.DIFFICULTY_ORDER[i]
		if not difficulty then
			break
		end
		local gui = LobbyBuilder.sign(parent, at, 20, 12)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
		frame.BackgroundTransparency = 0.25
		frame.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.06, 0)
		corner.Parent = frame
		local function line(y: number, h: number, color: Color3): TextLabel
			local text = Instance.new("TextLabel")
			text.BackgroundTransparency = 1
			text.Position = UDim2.fromScale(0.05, y)
			text.Size = UDim2.fromScale(0.9, h)
			text.Font = Enum.Font.FredokaOne
			text.TextScaled = true
			text.TextColor3 = color
			text.TextXAlignment = Enum.TextXAlignment.Left
			text.Text = ""
			text.Parent = frame
			return text
		end
		local title = line(0.03, 0.14, Color3.fromRGB(240, 196, 60))
		local rows = {}
		for r = 1, Config.SCOREBOARD_SIZE do
			table.insert(rows, line(0.2 + (r - 1) * 0.095, 0.085, Color3.new(1, 1, 1)))
		end
		local board = { difficulty = difficulty, title = title, rows = rows, roomIndex = 1 }
		table.insert(boards, board)
		render(board)
	end

	-- Cycle rooms on every board.
	task.spawn(function()
		while true do
			task.wait(Config.SCOREBOARD_CYCLE)
			for _, board in boards do
				board.roomIndex = board.roomIndex % #Rooms.ORDER + 1
				render(board)
			end
		end
	end)

	-- Fetch one board's data at a time.
	task.spawn(function()
		while true do
			local nextKey = table.remove(wanted, 1)
			if nextKey then
				local roomId, difficulty = string.match(nextKey, "^(.-)|(.*)$")
				if roomId and difficulty then
					cache[nextKey] = { rows = HighScores.top(roomId, difficulty, Config.SCOREBOARD_SIZE), fetchedAt = os.clock() }
					for _, board in boards do
						render(board)
					end
				end
			end
			task.wait(FETCH_GAP)
		end
	end)
end

return Scoreboards
