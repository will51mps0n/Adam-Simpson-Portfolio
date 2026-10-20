--!strict
-- Unit tests for the shared game logic. Run from the block-horde folder:
--   python3 tools/run_tests.py

local Combo = require("./shared/Combo")
local Config = require("./shared/Config")
local FlowField = require("./shared/FlowField")
local Hitscan = require("./shared/Hitscan")
local RoomGrid = require("./shared/RoomGrid")
local Rooms = require("./shared/Rooms")
local Snapshot = require("./shared/Snapshot")
local WaveMath = require("./shared/WaveMath")
local WeaponStats = require("./shared/WeaponStats")

local failures = 0
local function check(name: string, ok: boolean, detail: string?)
	if ok then
		print("pass  " .. name)
	else
		failures += 1
		print("FAIL  " .. name .. (if detail then ": " .. detail else ""))
	end
end
local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) < (eps or 1e-6)
end

-- RoomGrid ----------------------------------------------------------------
local grid = RoomGrid.new({ name = "Test", map = { "#####", "#.P.#", "#...#", "#.#.#", "#####" } }, 4)
check("grid size", grid.width == 5 and grid.height == 5)
check("centered origin", near(grid.originX, -10) and near(grid.originZ, -10))
local px, pz = grid:cellCenter(3, 2)
check("cell center", near(px, 0) and near(pz, -4), `{px}, {pz}`)
local c, r = grid:worldToCell(px, pz)
check("world to cell round trip", c == 3 and r == 2)
check("outside is blocked", grid:isBlocked(0, 3) and grid:isBlocked(6, 3) and grid:isBlocked(3, 99))
check("ray north hits wall", near(grid:raycast(0, -4, 0, -1, 100), 2))
check("ray south hits inner wall", near(grid:raycast(0, -4, 0, 1, 100), 6))
check("ray respects max distance", near(grid:raycast(0, -4, 0, 1, 5), 5))
check("ray east hits wall", near(grid:raycast(0, -4, 1, 0, 100), 6))
local diag = grid:raycast(0, -4, math.sqrt(0.5), math.sqrt(0.5), 100)
check("diagonal ray stops at a wall", diag > 0 and diag < 20, tostring(diag))
check("ray starting in a wall returns 0", grid:raycast(-8, -8, 1, 0, 100) == 0)
grid:setBlocked(3, 3, true)
check("fake wall blocks rays", near(grid:raycast(0, -4, 0, 1, 100), 2))
grid:setBlocked(3, 3, false)

-- Hitscan -------------------------------------------------------------------
type T = { x: number, z: number, radius: number }
local function circle(t: T): (number, number, number)
	return t.x, t.z, t.radius
end
local near1: T = { x = 0, z = -5, radius = 1 }
local far1: T = { x = 0.5, z = -12, radius = 1 }
local targets = { far1, { x = 4, z = -8, radius = 1 }, { x = 0, z = 5, radius = 1 }, near1 }
local hits, travel, dists = Hitscan.cast(0, 0, 0, -1, 50, targets, circle, 1)
check("pistol hits nearest only", #hits == 1 and hits[1] == near1)
check("pistol stops at enemy surface", near(travel, 4) and near(dists[1], 4))
hits, travel = Hitscan.cast(0, 0, 0, -1, 50, targets, circle, math.huge)
check("railgun pierces in order", #hits == 2 and hits[1] == near1 and hits[2] == far1 and near(travel, 50))
hits = Hitscan.cast(0, 0, 0, -1, 8, targets, circle, math.huge)
check("wall distance cuts the shot", #hits == 1)
hits, travel = Hitscan.cast(0, 0, 0, -1, 50, { { x = 0, z = -0.5, radius = 1 } }, circle, 1)
check("enemy hugging the shooter is hit", #hits == 1 and near(travel, 0))

-- FlowField -----------------------------------------------------------------
local map = { "#######", "#.....#", "#.###.#", "#.....#", "#######" }
local fg = RoomGrid.new({ name = "F", map = map }, 4)
local function plain(cx: number, cr: number): number?
	return if fg:isBlocked(cx, cr) then nil else 1
end
local field = FlowField.compute(fg.width, fg.height, plain, { { c = 2, r = 2 } })
local nc, nr = FlowField.next(field, 3, 2)
check("flow steps toward the player", nc == 2 and nr == 2, `{nc}, {nr}`)
check("flow has no step out of a wall", (FlowField.next(field, 3, 3)) == nil)
local hops, fc, fr = 0, 6, 4
while not (fc == 2 and fr == 2) and hops < 20 do
	local a, b = FlowField.next(field, fc, fr)
	if not a or not b then
		break
	end
	fc, fr, hops = a, b, hops + 1
end
check("following the flow reaches the player", fc == 2 and fr == 2 and hops <= 6, `{hops} hops`)
-- A barrel in the narrow gap: enemies walk around if the detour is cheap.
local function withBarrel(cx: number, cr: number): number?
	if cx == 4 and cr == 2 then
		return 1 + Config.PLACEABLE_PATH_COST
	end
	return plain(cx, cr)
end
local around = FlowField.compute(fg.width, fg.height, withBarrel, { { c = 2, r = 2 } })
local ac, ar = FlowField.next(around, 5, 2)
check("enemies route around a barrel", not (ac == 4 and ar == 2), `{ac}, {ar}`)

-- Every arena: all entry gaps lead to the players and nothing is sealed off.
for _, roomId in Rooms.ORDER do
	local def = Rooms.ARENAS[roomId]
	local room = RoomGrid.new(def, Config.CELL_SIZE)
	local spawns = room:find("P")
	local roomField = FlowField.compute(room.width, room.height, function(cx: number, cr: number): number?
		return if room:isBlocked(cx, cr) then nil else 1
	end, { spawns[1] })
	local ok = #spawns >= 6 and #room:find("A") >= 4
	for _, entry in room:find("S") do
		if roomField.dist[(entry.r - 1) * room.width + entry.c] == math.huge then
			ok = false
		end
	end
	check("room " .. roomId .. " is playable", ok)
end

-- Combo ---------------------------------------------------------------------
local combo = Combo.new()
local points, reached = Combo.addKills(combo, 0, { 10 })
check("first kill scores at x2", points == 20 and combo.base == 2 and #reached == 0, `{points}`)
local multiState = Combo.new()
points = Combo.addKills(multiState, 0, { 10, 10, 10 })
check("triple kill scores and earns a bonus", points == 90 and multiState.base == 6, `{points} {multiState.base}`)
check("no drain during the grace time", Combo.valueAt(6, 2, 1.5) == 6)
check("drains after the grace time", near(Combo.valueAt(6, 2, 3), 6 - Config.MULT_DECAY_RATE))
check("never drains below 1", Combo.valueAt(6, 2, 100) == 1)
local ladder = Combo.new()
local _, unlocked = Combo.addKills(ladder, 0, { 1, 1, 1 })
check("x6 unlocks the uzi first", #unlocked == 1 and unlocked[1].weapon == "uzi")
local _, more = Combo.addKills(ladder, 0.5, { 1, 1, 1, 1, 1 })
check("x15 unlocks shotgun and barrels", #more == 2 and more[1].weapon == "shotgun" and more[2].weapon == "barrels")
Combo.shift(ladder, 10)
check("pause shifts the drain", near(ladder.graceEnd, 12.5))

-- WaveMath ------------------------------------------------------------------
local normal = Config.DIFFICULTIES.Intermediate
check("wave 1 solo", WaveMath.count(1, 1, normal) == 10)
check("wave 10 with six players", WaveMath.count(10, 6, normal) == 115, tostring(WaveMath.count(10, 6, normal)))
check("speed is capped", WaveMath.speedMultiplier(1000, normal) == Config.WAVE_SPEED_CAP)
check("wave 1 is all zombies", WaveMath.pickKind(1, 0) == "Zombie" and WaveMath.pickKind(1, 0.99) == "Zombie")
local total = 0
for _, share in WaveMath.shares(40) do
	total += share
end
check("late waves still have zombies", total < 1, tostring(total))
check("devils from wave 3", WaveMath.pickKind(3, 0) ~= "Zombie")

-- WeaponStats -----------------------------------------------------------------
check("pistol has infinite ammo", WeaponStats.get("pistol").maxAmmo == nil)
check("rapid fire halves the interval", near(WeaponStats.get("uzi", { RapidFire = true }).fireInterval, 0.05))
check("unlimited ammo", WeaponStats.get("uzi", { UnlimitedAmmo = true }).maxAmmo == nil)
check("big shot adds pellets", WeaponStats.get("shotgun", { BigShot = true }).pellets == 8)
check("turret rapid fire speeds the turret", WeaponStats.get("turret", { RapidFire = true }).turretFireInterval < Config.TURRET_FIRE_INTERVAL)
local shotgun = WeaponStats.get("shotgun")
local a1 = WeaponStats.pelletDirections(0, -1, shotgun, 1234)
local a2 = WeaponStats.pelletDirections(0, -1, shotgun, 1234)
local unit = #a1 == shotgun.pellets
for i, d in a1 do
	unit = unit and near(d[1] * d[1] + d[2] * d[2], 1, 1e-9) and d[1] == a2[i][1] and d[2] == a2[i][2]
end
check("pellets are unit length and repeatable", unit)
check("pellets fan out", a1[1][1] * a1[#a1][1] < 0)
check("unlock label", WeaponStats.unlockLabel("shotgun", "WideShot", { WideShot = "WIDE SHOT" }) == "SHOTGUN + WIDE SHOT")

-- Snapshot --------------------------------------------------------------------
local buf = Snapshot.create(2, 123.5)
Snapshot.write(buf, 0, 7, 3, -12.34, 56.78, math.pi / 2, 0.5)
Snapshot.write(buf, 1, 65535, 1, 0, 0, 0, 0.001)
local seen = {}
local time = Snapshot.read(buf, function(id, kind, x, z, facing, health)
	table.insert(seen, { id, kind, x, z, facing, health })
end)
check("snapshot time", time == 123.5 and Snapshot.time(buf) == 123.5)
check("snapshot entry", seen[1][1] == 7 and seen[1][2] == 3 and near(seen[1][3], -12.3) and near(seen[1][4], 56.8) and near(seen[1][5], math.pi / 2, 0.03) and near(seen[1][6], 128 / 255))
check("tiny health still shows alive", seen[2][1] == 65535 and seen[2][6] > 0)
check("packet fits the unreliable limit", Snapshot.HEADER + Snapshot.MAX_PER_PACKET * Snapshot.ENTRY < 900)

if failures > 0 then
	error(`{failures} test(s) failed`)
end
print("all tests passed")
