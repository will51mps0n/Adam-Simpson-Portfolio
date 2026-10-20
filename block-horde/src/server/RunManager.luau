--!strict
-- Runs one game at a time: GET READY, then waves that grow bigger and faster
-- forever, with a short break and "WAVE N" between them. When every player
-- is down it shows the results, saves high scores and hands the players back
-- (to the lobby, or teleports them home from a party server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RoomGrid = require(ReplicatedStorage.Shared.RoomGrid)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local WaveMath = require(ReplicatedStorage.Shared.WaveMath)
local AmmoBoxes = require(script.Parent.AmmoBoxes)
local Arena = require(script.Parent.Arena)
local CharacterService = require(script.Parent.CharacterService)
local EnemyService = require(script.Parent.EnemyService)
local HighScores = require(script.Parent.HighScores)
local Loadout = require(script.Parent.Loadout)
local PauseService = require(script.Parent.PauseService)
local Placeables = require(script.Parent.Placeables)
local PlayerHealth = require(script.Parent.PlayerHealth)
local Projectiles = require(script.Parent.Projectiles)
local RunState = require(script.Parent.RunState)
local Scoring = require(script.Parent.Scoring)

local Announce = Net.event("Announce")
local RunResults = Net.event("RunResults")
local ExplosionRemote = Net.event("Explosion")

export type FinishHandler = (players: { Player }) -> ()

local RunManager = {}

local entries: { RoomGrid.Cell } = {}
local onFinished: FinishHandler? = nil
local toSpawn = 0
local spawnInterval = 1
local nextSpawnAt = 0
local phaseEndsAt = 0
local speedMultiplier = 1
local damageMultiplier = 1
local runToken = 0 -- changes whenever a run starts or is cleaned up
local rng = Random.new()

local function announce(text: string, style: string)
	for player in RunState.participants do
		Announce:FireClient(player, text, style)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function targets(): { EnemyService.Target }
	local list: { EnemyService.Target } = {}
	for _, participant in RunState.alive() do
		local root = rootOf(participant.player)
		if root then
			table.insert(list, { player = participant.player, x = root.Position.X, z = root.Position.Z })
		end
	end
	return list
end

local function beginWave(wave: number)
	local difficulty = Config.DIFFICULTIES[RunState.difficulty]
	RunState.wave = wave
	RunState.phase = "Wave"
	toSpawn = WaveMath.count(wave, RunState.count(), difficulty)
	spawnInterval = Config.WAVE_SPAWN_TIME / toSpawn
	nextSpawnAt = RunState.clock
	speedMultiplier = WaveMath.speedMultiplier(wave, difficulty)
	RunState.publish()
	if wave == 1 then
		announce("WAVE 1", "wave")
	end
end

local function spawnOne()
	if #entries == 0 then
		toSpawn = 0
		return
	end
	local cell = entries[rng:NextInteger(1, #entries)]
	EnemyService.spawn(WaveMath.pickKind(RunState.wave, rng:NextNumber()), cell, speedMultiplier, damageMultiplier)
end

local function reviveFallen()
	for player, participant in RunState.participants do
		if not participant.alive and player.Parent then
			participant.alive = true
			task.spawn(CharacterService.spawnAt, player, Arena.spawnFor(participant.slot))
			Announce:FireClient(player, "BACK IN THE FIGHT", "info")
		end
	end
end

local function cleanup()
	runToken += 1
	local players: { Player } = {}
	for player in RunState.participants do
		table.insert(players, player)
		player:SetAttribute("InRun", nil)
		Loadout.clear(player)
		PlayerHealth.forget(player)
	end
	EnemyService.clear()
	Projectiles.clear()
	Placeables.clear()
	AmmoBoxes.clear()
	Scoring.clear()
	table.clear(RunState.participants)
	RunState.active = false
	RunState.phase = "Idle"
	RunState.wave = 0
	RunState.publish()
	local finished = onFinished
	onFinished = nil
	if finished then
		finished(players)
	end
end

local function finishRun()
	if not RunState.active or RunState.phase == "Over" then
		return
	end
	RunState.phase = "Over"
	RunState.publish()
	PauseService.set(false)
	local results = Scoring.results()
	local summary = {
		wave = RunState.wave,
		room = RunState.roomId,
		difficulty = RunState.difficulty,
		players = results,
		returnIn = Config.RESULTS_TIME,
	}
	for player in RunState.participants do
		RunResults:FireClient(player, summary)
	end
	local roomId, difficulty = RunState.roomId, RunState.difficulty
	task.spawn(function()
		for _, result in results do
			HighScores.submit(roomId, difficulty, result.userId, result.score)
		end
	end)
	local token = runToken
	task.delay(Config.RESULTS_TIME, function()
		if token == runToken then
			cleanup()
		end
	end)
end

local function checkAllDown()
	if RunState.active and RunState.phase ~= "Over" and #RunState.alive() == 0 then
		finishRun()
	end
end

local function onDied(player: Player)
	local participant = RunState.participants[player]
	if not participant or not participant.alive then
		return
	end
	participant.alive = false
	local root = rootOf(player)
	if root then
		ExplosionRemote:FireAllClients(root.Position.X, root.Position.Z, 0, "death")
	end
	Announce:FireClient(player, "YOU DIED", "big")
	checkAllDown()
end

local function onLeave(player: Player)
	if not RunState.participants[player] then
		return
	end
	RunState.participants[player] = nil
	Scoring.remove(player)
	if RunState.count() == 0 then
		cleanup()
	else
		checkAllDown()
	end
end

local function step(dt: number)
	if not RunState.active or RunState.paused then
		return
	end
	if RunState.phase == "Over" then
		EnemyService.flush()
		return
	end
	RunState.clock += dt
	local clock = RunState.clock
	EnemyService.update(dt, clock, targets())
	Projectiles.update(dt, clock)
	Placeables.update(clock)
	AmmoBoxes.update(dt)
	PlayerHealth.update(dt)

	if RunState.phase == "Starting" then
		if clock >= phaseEndsAt then
			beginWave(1)
		end
	elseif RunState.phase == "Wave" then
		while toSpawn > 0 and clock >= nextSpawnAt and EnemyService.count() < Config.MAX_ALIVE_ENEMIES do
			spawnOne()
			toSpawn -= 1
			nextSpawnAt += spawnInterval
		end
		if toSpawn > 0 and EnemyService.count() >= Config.MAX_ALIVE_ENEMIES then
			nextSpawnAt = math.max(nextSpawnAt, clock) -- don't save up a burst while full
		end
		if toSpawn == 0 and EnemyService.count() == 0 then
			RunState.phase = "Break"
			phaseEndsAt = clock + Config.WAVE_BREAK
			RunState.publish()
			if Config.REVIVE_AT_WAVE_END then
				reviveFallen()
			end
			announce("WAVE " .. (RunState.wave + 1), "wave")
		end
	elseif RunState.phase == "Break" then
		if clock >= phaseEndsAt then
			beginWave(RunState.wave + 1)
		end
	end
end

-- Starts a run in this server's arena. Returns false if one is already going.
function RunManager.begin(players: { Player }, roomId: string, difficulty: string, finished: FinishHandler): boolean
	if RunState.active or #players == 0 then
		return false
	end
	if not Rooms.ARENAS[roomId] then
		roomId = Rooms.ORDER[1]
	end
	if not Config.DIFFICULTIES[difficulty] then
		difficulty = "Intermediate"
	end
	local grid = Arena.load(roomId)
	entries = grid:find("S")

	runToken += 1
	RunState.active = true
	RunState.phase = "Starting"
	RunState.clock = 0
	RunState.roomId = roomId
	RunState.difficulty = difficulty
	RunState.wave = 0
	table.clear(RunState.participants)
	for slot, player in players do
		RunState.participants[player] = { player = player, slot = slot, alive = true }
		CharacterService.setSlot(player, slot)
		player:SetAttribute("InRun", true)
		Loadout.reset(player)
		PlayerHealth.forget(player)
	end
	Scoring.reset(players)
	EnemyService.start(grid)
	Placeables.start(grid)
	AmmoBoxes.start(grid)
	onFinished = finished
	damageMultiplier = Config.DIFFICULTIES[difficulty].damage
	phaseEndsAt = Config.RUN_START_DELAY
	PauseService.set(false)
	RunState.publish()

	for player, participant in RunState.participants do
		task.spawn(CharacterService.spawnAt, player, Arena.spawnFor(participant.slot))
	end
	announce("GET READY", "wave")
	return true
end

function RunManager.init()
	EnemyService.hooks.attackPlayer = PlayerHealth.damage
	CharacterService.Died:Connect(onDied)
	Players.PlayerRemoving:Connect(onLeave)
	RunState.PausedChanged:Connect(function(paused: boolean, seconds: number)
		if not paused and seconds > 0 then
			Scoring.shiftAll(seconds)
		end
	end)
	RunState.publish()
	RunService.Heartbeat:Connect(step)
end

return RunManager
