--!strict
-- Server entry point: creates the remotes, gives each player a level session, and runs
-- the enemies 30 times a second.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local Protocol = require(Shared.Net.Protocol)
local LevelSession = require(script.LevelSession)

-- The ninja is our own 2D physics body, not a Roblox character (the project file sets
-- this too; repeating it here keeps it true even if the place's settings change).
Players.CharacterAutoLoads = false

local DEFAULT_LEVEL = "test_shapes"

local remotes = Protocol.remotes()
local sessions: { [Player]: LevelSession.Session } = {}

local function startSession(player: Player, levelId: string)
	local old = sessions[player]
	if old then
		LevelSession.removePlayer(old, player)
	end
	local session = LevelSession.new(levelId, remotes)
	LevelSession.addPlayer(session, player)
	sessions[player] = session
end

local function levelExists(id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	for _, def in Levels.list() do
		if def.id == id then
			return true
		end
	end
	return false
end

remotes.PlayerAction.OnServerEvent:Connect(function(player: Player, kind: any, ...: any)
	if type(kind) ~= "string" then
		return
	end
	if kind == "ready" then
		local session = sessions[player]
		if session then
			LevelSession.sendLoad(session, player)
		else
			startSession(player, DEFAULT_LEVEL)
		end
	elseif kind == "loadLevel" then
		local id = ...
		if levelExists(id) then
			startSession(player, id)
		end
	else
		local session = sessions[player]
		if session then
			LevelSession.onAction(session, player, kind, ...)
		end
	end
end)

remotes.NinjaState.OnServerEvent:Connect(function(player: Player, data: any)
	local session = sessions[player]
	if session and typeof(data) == "buffer" then
		LevelSession.onNinjaState(session, player, data)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	if session then
		LevelSession.removePlayer(session, player)
		sessions[player] = nil
	end
end)

local TICK = 1 / Config.ENEMY_HZ
local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated = math.min(accumulated + dt, TICK * 4)
	while accumulated >= TICK do
		accumulated -= TICK
		for _, session in sessions do
			LevelSession.tick(session, TICK)
		end
	end
end)
