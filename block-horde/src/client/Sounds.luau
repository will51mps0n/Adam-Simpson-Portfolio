--!strict
-- Plays the sounds listed in Config.SOUNDS. Sounds with no id are skipped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sounds = {}

local MIN_GAP = 0.04 -- the same sound can't restart faster than this
local templates: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}

local function template(name: string): Sound?
	local existing = templates[name]
	if existing then
		return existing
	end
	local entry = Config.SOUNDS[name]
	if not entry or entry.id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "BlockHorde_" .. name
	sound.SoundId = entry.id
	sound.Volume = entry.volume
	sound.Parent = SoundService
	templates[name] = sound
	return sound
end

function Sounds.play(name: string, volumeScale: number?)
	local sound = template(name)
	if not sound then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < MIN_GAP then
		return
	end
	lastPlayed[name] = now
	local copy = sound:Clone()
	copy.Volume = sound.Volume * (volumeScale or 1)
	copy.Parent = SoundService
	copy.Ended:Once(function()
		copy:Destroy()
	end)
	copy:Play()
	task.delay(8, function()
		if copy.Parent then
			copy:Destroy()
		end
	end)
end

return Sounds
