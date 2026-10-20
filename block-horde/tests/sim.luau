--!strict
-- Headless check of the real server enemy code: in every arena, a mixed horde
-- spawns at the entry gaps around one standing player. After 60 simulated
-- seconds every enemy must have reached the player (devils: come within
-- fireball range), and none may be stuck.

local Config = require("./shared/Config")
local RoomGrid = require("./shared/RoomGrid")
local Rooms = require("./shared/Rooms")
local EnemyService = require("./server/EnemyService")

local KINDS = { "Zombie", "Zombie", "Runner", "Mummy", "Vampire", "Devil" }
local DT = 1 / 30
local CROWD_RADIUS = 18 -- a big horde packs around the player; the back rows can't touch them

local failures = 0
math.randomseed(42)

-- Spawns `count` enemies across the room's gaps and simulates `seconds`.
-- Returns how many reached the player, how many ended inside the crowd
-- around them, the longest time an enemy sat still far from the player,
-- and an example of an enemy that didn't make it.
local function simulate(roomId: string, count: number, seconds: number): (number, number, number, string)
	local grid = RoomGrid.new(Rooms.ARENAS[roomId], Config.CELL_SIZE)
	EnemyService.start(grid)
	local spawn = grid:find("P")[1]
	local px, pz = grid:cellCenter(spawn.c, spawn.r)
	local fakePlayer: any = { Name = "P" }
	local targets = { { player = fakePlayer, x = px, z = pz } }

	local reached: { [number]: boolean } = {}
	EnemyService.hooks.attackPlayer = function() end
	EnemyService.hooks.shootFireball = function(enemy: any)
		reached[enemy.id] = true -- a devil in fireball range has done its job
	end

	local entries = grid:find("S")
	local enemies = {}
	for i = 1, count do
		local enemy = EnemyService.spawn(KINDS[(i - 1) % #KINDS + 1], entries[(i - 1) % #entries + 1], 1, 1)
		table.insert(enemies, enemy)
	end

	local clock = 0
	local stillSince: { [number]: number } = {}
	local lastPos: { [number]: { number } } = {}
	local longestStall = 0
	for _ = 1, math.floor(seconds / DT) do
		clock += DT
		EnemyService.update(DT, clock, targets)
		for _, enemy in EnemyService.list() do
			local dx, dz = enemy.x - px, enemy.z - pz
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist <= enemy.radius + Config.PLAYER_RADIUS + 0.5 then
				reached[enemy.id] = true
			end
			local prev = lastPos[enemy.id]
			local far = dist > CROWD_RADIUS and not enemy.entering
			if far and prev and math.abs(enemy.x - prev[1]) + math.abs(enemy.z - prev[2]) < 0.02 then
				stillSince[enemy.id] = stillSince[enemy.id] or clock
				longestStall = math.max(longestStall, clock - stillSince[enemy.id])
			else
				stillSince[enemy.id] = nil
			end
			lastPos[enemy.id] = { enemy.x, enemy.z }
		end
	end

	local reachedCount, crowded = 0, 0
	local example = ""
	for _, enemy in enemies do
		if not enemy then
			continue
		end
		local dist = math.sqrt((enemy.x - px) ^ 2 + (enemy.z - pz) ^ 2)
		if reached[enemy.id] then
			reachedCount += 1
		end
		if reached[enemy.id] or dist <= CROWD_RADIUS then
			crowded += 1
		elseif example == "" then
			local c, r = grid:worldToCell(enemy.x, enemy.z)
			example = string.format("  e.g. %s stuck at cell %d,%d", enemy.kind, c, r)
		end
	end
	return reachedCount, crowded, longestStall, example
end

for _, roomId in Rooms.ORDER do
	-- A small group: every one of them must get to the player.
	local reached, _, stall, example = simulate(roomId, 6, 40)
	local ok = reached == 6 and stall < 4
	if not ok then
		failures += 1
	end
	print(string.format("%s  %-8s small group: %d/6 reached the player, longest stall %.1fs%s", if ok then "pass" else "FAIL", roomId, reached, stall, example))

	-- A big horde: everyone must end up packed around the player.
	local _, crowded, hordeStall, hordeExample = simulate(roomId, 60, 60)
	local hordeOk = crowded == 60 and hordeStall < 4
	if not hordeOk then
		failures += 1
	end
	print(string.format("%s  %-8s horde of 60: %d/60 around the player, longest far stall %.1fs%s", if hordeOk then "pass" else "FAIL", roomId, crowded, hordeStall, hordeExample))
end

-- Walled in: barrels on all 8 cells around the player. Enemies must path to
-- the barricade and attack it.
do
	local grid = RoomGrid.new(Rooms.ARENAS.Boxy, Config.CELL_SIZE)
	EnemyService.start(grid)
	local spawn = grid:find("P")[1]
	local px, pz = grid:cellCenter(spawn.c, spawn.r)
	local barrels: { [number]: any } = {}
	for dc = -1, 1 do
		for dr = -1, 1 do
			if dc ~= 0 or dr ~= 0 then
				barrels[(spawn.r + dr) * 10000 + spawn.c + dc] = { kind = "barrel" }
			end
		end
	end
	local attacks, playerHits = 0, 0
	EnemyService.hooks.blockingPlaceableAt = function(c: number, r: number): any
		return barrels[r * 10000 + c]
	end
	EnemyService.hooks.attackPlaceable = function()
		attacks += 1
	end
	EnemyService.hooks.attackPlayer = function()
		playerHits += 1
	end
	for i = 1, 12 do
		EnemyService.spawn("Zombie", grid:find("S")[(i - 1) % 6 + 1], 1, 1)
	end
	local clock = 0
	for _ = 1, math.floor(30 / DT) do
		clock += DT
		EnemyService.update(DT, clock, { { player = {} :: any, x = px, z = pz } })
	end
	local ok = attacks > 10
	if not ok then
		failures += 1
	end
	print(string.format("%s  barricade: enemies attacked the barrels %d times (player hit %d times through them)", if ok then "pass" else "FAIL", attacks, playerHits))
end

if failures > 0 then
	error(`{failures} horde check(s) failed`)
end
print("horde simulation passed")
