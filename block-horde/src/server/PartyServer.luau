--!strict
-- A party's private server (reserved by the lobby's teleport). Waits for the
-- party to arrive, plays one run with the room and difficulty they picked,
-- then teleports everyone back to a lobby server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local RunManager = require(script.Parent.RunManager)
local Teleporter = require(script.Parent.Teleporter)

local Announce = Net.event("Announce")

local PartyServer = {}

-- True when this server is a party's private game rather than a lobby.
function PartyServer.isPartyServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

function PartyServer.start()
	Players.PlayerAdded:Connect(function(player)
		Announce:FireClient(player, "WAITING FOR YOUR PARTY...", "info")
	end)
	task.spawn(function()
		local first = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
		local data: any = first:GetJoinData().TeleportData
		local roomId = Rooms.ORDER[1]
		local difficulty = "Intermediate"
		local expected: { number } = {}
		if typeof(data) == "table" then
			if typeof(data.room) == "string" and Rooms.ARENAS[data.room] then
				roomId = data.room
			end
			if typeof(data.difficulty) == "string" and Config.DIFFICULTIES[data.difficulty] then
				difficulty = data.difficulty
			end
			if typeof(data.party) == "table" then
				for _, userId in data.party do
					if typeof(userId) == "number" then
						table.insert(expected, userId)
					end
				end
			end
		end

		-- Wait until the whole party is here (or it's taking too long).
		local deadline = os.clock() + Config.ARRIVAL_WAIT
		while os.clock() < deadline do
			local missing = false
			for _, userId in expected do
				if not Players:GetPlayerByUserId(userId) then
					missing = true
				end
			end
			if not missing then
				break
			end
			task.wait(0.5)
		end
		task.wait(1)

		RunManager.begin(Players:GetPlayers(), roomId, difficulty, function(_finished: { Player })
			Teleporter.sendHome(Players:GetPlayers())
		end)
	end)
end

return PartyServer
