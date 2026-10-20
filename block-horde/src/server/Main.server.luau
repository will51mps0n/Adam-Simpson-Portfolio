--!strict
-- Server entry point: builds the world, then starts each service in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Arena = require(script.Parent.Arena)
local CharacterService = require(script.Parent.CharacterService)
local Loadout = require(script.Parent.Loadout)
local PauseService = require(script.Parent.PauseService)
local PracticeTargets = require(script.Parent.PracticeTargets)
local WeaponService = require(script.Parent.WeaponService)
local WorldSetup = require(script.Parent.WorldSetup)

WorldSetup.start()
local grid = Arena.load(Config.START_ROOM)
Loadout.start()
PauseService.start()
WeaponService.start()
PracticeTargets.start(grid)
CharacterService.start() -- last, because it spawns players into the room
