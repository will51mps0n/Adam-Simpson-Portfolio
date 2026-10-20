--!strict
-- Server entry point.

local Players = game:GetService("Players")

-- The ninja is our own 2D physics body, not a Roblox character (the project file sets
-- this too; repeating it here keeps it true even if the place's settings change).
Players.CharacterAutoLoads = false
