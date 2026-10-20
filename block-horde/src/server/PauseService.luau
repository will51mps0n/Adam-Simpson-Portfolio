--!strict
-- P pauses the game, but only when one player is on the server.
-- The paused state is a workspace attribute so every client can see it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local PauseService = {}

local paused = false

local function setPaused(value: boolean)
	paused = value
	workspace:SetAttribute("Paused", value)
end

function PauseService.isPaused(): boolean
	return paused
end

function PauseService.start()
	setPaused(false)
	Net.event("PauseRequest").OnServerEvent:Connect(function()
		if #Players:GetPlayers() == 1 then
			setPaused(not paused)
		end
	end)
	-- Someone joining always unpauses.
	Players.PlayerAdded:Connect(function()
		if paused then
			setPaused(false)
		end
	end)
end

return PauseService
