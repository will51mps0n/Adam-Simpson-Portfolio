--!strict
-- Server entry point. Every server builds the world and starts the game
-- systems. A normal server is a lobby (parties form there); a party's
-- private server just plays that party's run.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CharacterService = require(script.Parent.CharacterService)
local Explosions = require(script.Parent.Explosions)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local Loadout = require(script.Parent.Loadout)
local PartyServer = require(script.Parent.PartyServer)
local PartyService = require(script.Parent.PartyService)
local PauseService = require(script.Parent.PauseService)
local Projectiles = require(script.Parent.Projectiles)
local RunManager = require(script.Parent.RunManager)
local Scoreboards = require(script.Parent.Scoreboards)
local Teleporter = require(script.Parent.Teleporter)
local WeaponService = require(script.Parent.WeaponService)
local WorldSetup = require(script.Parent.WorldSetup)

ReplicatedStorage:SetAttribute("GameName", Config.GAME_NAME)
WorldSetup.start()
Loadout.start()
PauseService.start()
WeaponService.start()
Explosions.start()
Projectiles.start()
Teleporter.start()
RunManager.init()

if PartyServer.isPartyServer() then
	ReplicatedStorage:SetAttribute("ServerKind", "Party")
	PartyServer.start()
else
	ReplicatedStorage:SetAttribute("ServerKind", "Lobby")
	local lobby = LobbyBuilder.build()
	local function lobbySpawn(player: Player): CFrame?
		local spawns = lobby.spawns
		return spawns[(CharacterService.slotOf(player) - 1) % #spawns + 1]
	end
	CharacterService.homeSpawn = lobbySpawn
	Teleporter.homeSpawn = lobbySpawn
	PartyService.start(lobby.pads)
	Scoreboards.start(lobby.boards, lobby.folder)
end

CharacterService.start() -- last, because it spawns players
