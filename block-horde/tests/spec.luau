--!strict
-- Unit tests for the pure-math shared modules. Run from the block-horde folder:
--   luau tests/spec.luau

local Hitscan = require("../src/shared/Hitscan")
local RoomGrid = require("../src/shared/RoomGrid")

local failures = 0
local function check(name: string, ok: boolean, detail: string?)
	if ok then
		print("pass  " .. name)
	else
		failures += 1
		print("FAIL  " .. name .. (if detail then ": " .. detail else ""))
	end
end
local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- RoomGrid ----------------------------------------------------------------
local grid = RoomGrid.new({
	name = "Test",
	map = {
		"#####",
		"#.P.#",
		"#...#",
		"#.#.#",
		"#####",
	},
}, 4)

check("size", grid.width == 5 and grid.height == 5)
check("centered origin", near(grid.originX, -10) and near(grid.originZ, -10))
local px, pz = grid:cellCenter(3, 2)
check("cell center", near(px, 0) and near(pz, -4), `{px}, {pz}`)
local c, r = grid:worldToCell(px, pz)
check("world to cell round trip", c == 3 and r == 2, `{c}, {r}`)
check("find spawn", #grid:find("P") == 1 and grid:find("P")[1].c == 3)
check("outside is blocked", grid:isBlocked(0, 3) and grid:isBlocked(6, 3) and grid:isBlocked(3, 99))

-- From the spawn cell center (0, -4): the north wall (row 1) ends at z = -6, distance 2.
check("ray north hits wall", near(grid:raycast(0, -4, 0, -1, 100), 2), tostring(grid:raycast(0, -4, 0, -1, 100)))
-- South: row 3 is floor, the inner wall at row 4 starts at z = 2, distance 6.
check("ray south hits inner wall", near(grid:raycast(0, -4, 0, 1, 100), 6), tostring(grid:raycast(0, -4, 0, 1, 100)))
check("ray respects max distance", near(grid:raycast(0, -4, 0, 1, 5), 5))
-- East: column 4 is floor, the wall in column 5 starts at x = 6, distance 6.
check("ray east hits wall", near(grid:raycast(0, -4, 1, 0, 100), 6))
-- Diagonal toward the south-east must stop somewhere positive and finite.
local diag = grid:raycast(0, -4, math.sqrt(0.5), math.sqrt(0.5), 100)
check("diagonal ray stops at a wall", diag > 0 and diag < 20, tostring(diag))
check("ray starting in a wall returns 0", grid:raycast(-10 + 2, -10 + 2, 1, 0, 100) == 0)
grid:setBlocked(3, 3, true)
check("placeable blocks rays", near(grid:raycast(0, -4, 0, 1, 100), 2))
grid:setBlocked(3, 3, false)

-- Hitscan -------------------------------------------------------------------
type T = { name: string, x: number, z: number, radius: number }
local function circle(t: T): (number, number, number)
	return t.x, t.z, t.radius
end
local near1: T = { name = "near", x = 0, z = -5, radius = 1 }
local far1: T = { name = "far", x = 0.5, z = -12, radius = 1 }
local side: T = { name = "side", x = 4, z = -8, radius = 1 }
local behind: T = { name = "behind", x = 0, z = 5, radius = 1 }
local targets = { far1, side, behind, near1 }

local hits, travel = Hitscan.cast(0, 0, 0, -1, 50, targets, circle, 1)
check("pistol hits nearest only", #hits == 1 and hits[1] == near1)
check("pistol stops at enemy surface", near(travel, 4), tostring(travel))

hits, travel = Hitscan.cast(0, 0, 0, -1, 50, targets, circle, math.huge)
check("railgun pierces in order", #hits == 2 and hits[1] == near1 and hits[2] == far1)
check("railgun travels full range", near(travel, 50))

hits = Hitscan.cast(0, 0, 0, -1, 8, targets, circle, math.huge)
check("wall distance cuts the shot", #hits == 1 and hits[1] == near1)

local hugging: T = { name = "hug", x = 0, z = -0.5, radius = 1 }
hits, travel = Hitscan.cast(0, 0, 0, -1, 50, { hugging }, circle, 1)
check("enemy overlapping the shooter is hit", #hits == 1 and near(travel, 0))

hits = Hitscan.cast(0, 0, 1, 0, 50, targets, circle, 1)
check("miss returns no hits", #hits == 0)

if failures > 0 then
	error(`{failures} test(s) failed`)
end
print("all tests passed")
