--!strict
-- P pauses the run, but only when one player is on the server. The paused
-- state is a workspace attribute so the client can show the overlay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local RunState = require(script.Parent.RunState)

local PauseService = {}

local pausedAt = 0

function PauseService.set(paused: boolean)
	if paused == RunState.paused then
		return
	end
	RunState.paused = paused
	workspace:SetAttribute("Paused", paused)
	if paused then
		pausedAt = workspace:GetServerTimeNow()
		RunState.PausedChanged:Fire(true, 0)
	else
		RunState.PausedChanged:Fire(false, workspace:GetServerTimeNow() - pausedAt)
	end
end

function PauseService.start()
	workspace:SetAttribute("Paused", false)
	Net.event("PauseRequest").OnServerEvent:Connect(function(player: Player)
		local allowed = RunState.active
			and RunState.phase ~= "Over"
			and RunState.isParticipant(player)
			and #Players:GetPlayers() == 1
		if allowed or RunState.paused then
			PauseService.set(not RunState.paused)
		end
	end)
	-- Someone joining always unpauses.
	Players.PlayerAdded:Connect(function()
		PauseService.set(false)
	end)
end

return PauseService
