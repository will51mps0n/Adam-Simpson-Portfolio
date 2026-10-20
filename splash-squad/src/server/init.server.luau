--!strict
-- Server entry point. For now (milestone 1) it only sets up the sunny lighting;
-- the match logic arrives in later milestones.

local Players = game:GetService("Players")

local LightingSetup = require(script.LightingSetup)

-- Players don't walk around: each kid is a model the game builds and places.
Players.CharacterAutoLoads = false

LightingSetup.apply()
