--!strict
-- Shared state of the current run (one at a time per server), read by every
-- server system. RunManager is the only module that changes it, apart from
-- PauseService toggling `paused`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

export type Participant = {
	player: Player,
	slot: number, -- 1-6: spawn cell and shirt order
	alive: boolean,
}

local RunState = {}

RunState.active = false
RunState.phase = "Idle" -- Idle, Starting, Wave, Break, Over
RunState.paused = false
RunState.clock = 0 -- seconds of unpaused run time; cooldowns use this
RunState.roomId = ""
RunState.difficulty = "Intermediate"
RunState.wave = 0
RunState.participants = {} :: { [Player]: Participant }
RunState.PausedChanged = Signal.new() -- (paused: boolean, pausedForSeconds: number)

function RunState.isParticipant(player: Player): boolean
	return RunState.participants[player] ~= nil
end

-- True while this player may shoot, place and pick things up.
function RunState.canAct(player: Player): boolean
	local participant = RunState.participants[player]
	return RunState.active
		and not RunState.paused
		and participant ~= nil
		and participant.alive
		and RunState.phase ~= "Over"
		and RunState.phase ~= "Idle"
end

function RunState.alive(): { Participant }
	local list = {}
	for _, participant in RunState.participants do
		if participant.alive then
			table.insert(list, participant)
		end
	end
	return list
end

function RunState.count(): number
	local n = 0
	for _ in RunState.participants do
		n += 1
	end
	return n
end

-- Mirrors the run's state onto ReplicatedStorage so clients can show it.
function RunState.publish()
	ReplicatedStorage:SetAttribute("RunActive", RunState.active)
	ReplicatedStorage:SetAttribute("RunPhase", RunState.phase)
	ReplicatedStorage:SetAttribute("Wave", RunState.wave)
	ReplicatedStorage:SetAttribute("RoomId", RunState.roomId)
	ReplicatedStorage:SetAttribute("Difficulty", RunState.difficulty)
end

return RunState
