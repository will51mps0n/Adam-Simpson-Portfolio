--!strict
-- Sends a party into a game. In the published game the party is teleported
-- to its own private (reserved) server of this same place. In Studio, where
-- teleports don't work, the run happens right here in this server's arena.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local CharacterService = require(script.Parent.CharacterService)
local RunManager = require(script.Parent.RunManager)

local Announce = Net.event("Announce")

local Teleporter = {}

-- Where players go when a run in this server ends. Set by Main.
Teleporter.homeSpawn = function(_player: Player): CFrame?
	return nil
end

local function present(players: { Player }): { Player }
	local list = {}
	for _, player in players do
		if player.Parent == Players then
			table.insert(list, player)
		end
	end
	return list
end

-- Plays the run in this server's own arena.
function Teleporter.playHere(players: { Player }, roomId: string, difficulty: string)
	local started = RunManager.begin(players, roomId, difficulty, function(finished: { Player })
		for _, player in finished do
			local home = Teleporter.homeSpawn(player)
			if player.Parent and home then
				task.spawn(CharacterService.spawnAt, player, home)
			end
		end
	end)
	if not started then
		for _, player in players do
			Announce:FireClient(player, "ARENA BUSY - TRY AGAIN IN A MOMENT", "info")
		end
	end
end

function Teleporter.launch(players: { Player }, roomId: string, difficulty: string)
	if RunService:IsStudio() then
		Teleporter.playHere(players, roomId, difficulty)
		return
	end
	task.spawn(function()
		local userIds = {}
		for _, player in players do
			table.insert(userIds, player.UserId)
			Announce:FireClient(player, "TELEPORTING...", "info")
		end
		local options = Instance.new("TeleportOptions")
		options.ShouldReserveServer = true
		options:SetTeleportData({ room = roomId, difficulty = difficulty, party = userIds })
		for attempt = 1, Config.TELEPORT_RETRIES do
			local group = present(players)
			if #group == 0 then
				return
			end
			local ok, err = pcall(function()
				return TeleportService:TeleportAsync(game.PlaceId, group, options)
			end)
			if ok then
				return
			end
			warn("[Block Horde] party teleport failed (attempt " .. attempt .. "): " .. tostring(err))
			task.wait(2 * attempt)
		end
		-- Teleports keep failing: play in this server instead.
		Teleporter.playHere(present(players), roomId, difficulty)
	end)
end

-- From a party's private server: send everyone back to a lobby server.
function Teleporter.sendHome(players: { Player })
	task.spawn(function()
		for attempt = 1, 10 do
			local group = present(players)
			if #group == 0 then
				return
			end
			for _, player in group do
				Announce:FireClient(player, "BACK TO THE LOBBY...", "info")
			end
			local ok, err = pcall(function()
				return TeleportService:TeleportAsync(game.PlaceId, group)
			end)
			if ok then
				return
			end
			warn("[Block Horde] teleport home failed (attempt " .. attempt .. "): " .. tostring(err))
			task.wait(5)
		end
	end)
end

function Teleporter.start()
	TeleportService.TeleportInitFailed:Connect(function(player: Player, _result: Enum.TeleportResult, message: string)
		Announce:FireClient(player, "TELEPORT FAILED: " .. message, "info")
	end)
end

return Teleporter
