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

type Pending = { kind: string, options: TeleportOptions?, attempts: number }

local Teleporter = {}

local MAX_ATTEMPTS = 4
-- Players whose teleport was accepted; most failures only show up later through
-- TeleportInitFailed, so this remembers how to try them again.
local pending: { [Player]: Pending } = {}

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
			if player.Parent then
				CharacterService.reassignSlot(player)
				local home = Teleporter.homeSpawn(player)
				if home then
					task.spawn(CharacterService.spawnAt, player, home)
				end
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
			local ok, result = pcall(function()
				return TeleportService:TeleportAsync(game.PlaceId, group, options)
			end)
			if ok then
				-- Stragglers retry into the same private server.
				local retry = Instance.new("TeleportOptions")
				retry.ReservedServerAccessCode = (result :: TeleportAsyncResult).ReservedServerAccessCode
				retry:SetTeleportData({ room = roomId, difficulty = difficulty, party = userIds })
				for _, player in group do
					pending[player] = { kind = "party", options = retry, attempts = 1 }
				end
				return
			end
			warn("[Block Horde] party teleport failed (attempt " .. attempt .. "): " .. tostring(result))
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
				for _, player in group do
					pending[player] = { kind = "home", options = nil, attempts = 1 }
				end
				return
			end
			warn("[Block Horde] teleport home failed (attempt " .. attempt .. "): " .. tostring(err))
			task.wait(5)
		end
	end)
end

function Teleporter.start()
	TeleportService.TeleportInitFailed:Connect(function(player: Player, _result: Enum.TeleportResult, message: string)
		local entry = pending[player]
		if not entry or entry.attempts >= MAX_ATTEMPTS then
			pending[player] = nil
			if entry and entry.kind == "home" then
				-- Better than leaving them alone in an empty game server.
				player:Kick("Couldn't get you back to the lobby. Please rejoin the game.")
			else
				Announce:FireClient(player, "TELEPORT FAILED: " .. message, "info")
			end
			return
		end
		entry.attempts += 1
		Announce:FireClient(player, "TELEPORT FAILED, RETRYING...", "info")
		task.delay(2 * entry.attempts, function()
			if player.Parent then
				pcall(function()
					TeleportService:TeleportAsync(game.PlaceId, { player }, entry.options)
				end)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return Teleporter
