--[[
	==================================================================
	 CAVE HUNT  -  Cave System Builder  (v1)
	==================================================================
	Carves a cave network for a monster hide-and-seek game.

	  * 4 rooms (Base Camp, Great Cavern, Old Mine, Crystal Grotto) joined
	    by winding tunnels in two loops, so hiders can run circles around
	    the monster
	  * small side "nooks" off the tunnels
	  * Base Camp with the player SpawnLocation
	  * MonsterSpawn points at the far ends of the other three rooms
	  * a few hiding spots of my own: mine carts, a locker, a wardrobe in
	    each shack, a barrel up a climbable scaffold
	  * shacks, crystals, a campfire, mine supports + rails, barricades,
	    boulders, pillars, floating dust, very few (dim) lights
	  * lots of invisible PropSpot markers where PlaceAssets.lua puts YOUR
	    models: in every room, along the tunnels and in the nooks

	Everything is put in Workspace.CaveSystem. The caves are carved inside
	a big block of rock (720 x 200 x 720 studs) in the middle of the
	Baseplate. Anything else in Workspace that would end up inside the rock
	is lifted onto the top of it, so nothing gets buried.

	CollectionService tags for the gameplay scripts we add next:
	  HidingSpot   Model. Has HidePoint + ExitPoint parts and the
	               attributes HideType and Occupied
	  MonsterSpawn Part. A place the monster player can spawn
	  PlayerSpawn  The SpawnLocation in Base Camp
	  PropSpot     Part. Free floor space (attributes MaxFootprint, MaxHeight)
	  CaveRoom     Part. Invisible box around each room (attribute RoomKind)

	HOW TO RUN: use the one-line Command Bar command in README.md. It
	downloads this file from GitHub into a ModuleScript and runs it:
	  ... require(M)()
	Put options in the last brackets, e.g.  require(M)({ OVERWRITE = true })
	Pasting this whole file into the Command Bar also works.
]]

-- Settings. Override any of them from the Command Bar, e.g. require(M)({ SEED = 7, OVERWRITE = true })
local DEFAULTS = {
	ORIGIN = Vector3.new(0, 64, 0), -- cave center: a rock mountain in the middle of the Baseplate. Keep Y a multiple of 4
	SEED = 2024, -- change this for a different random arrangement
	OVERWRITE = false, -- true = delete the old cave (and edits inside it) and rebuild
	TUNNEL_SIZE = 1, -- tunnel width/height multiplier. Try 1.3 if your monster is huge
	DISABLE_OTHER_SPAWNS = true, -- turn off other SpawnLocations so playtests start in the cave
	DARK_CAVE = true, -- few lights inside; players need flashlights. The dark mood itself is applied by GameScripts only while a player is in the cave
	LIGHT_SHADOWS = false, -- lantern shadows: prettier, but slower on weak devices
	MOVE_CAMERA = true, -- fly the Studio camera to Base Camp when done
}

local function run(options)
	local CONFIG = table.clone(DEFAULTS)
	for k, v in pairs(options or {}) do
		if DEFAULTS[k] == nil then
			warn("[CaveBuilder] Unknown option: " .. tostring(k))
		end
		CONFIG[k] = v
	end

	local function build()
		local Terrain = workspace.Terrain
		local CollectionService = game:GetService("CollectionService")
		local ChangeHistoryService = game:GetService("ChangeHistoryService")

		local O = CONFIG.ORIGIN
		local TS = CONFIG.TUNNEL_SIZE
		local rng = Random.new(CONFIG.SEED)
		local startTime = os.clock()

		local M = Enum.Material
		local AIR, ROCK = M.Air, M.Slate
		local HALF = 360 -- the rock block is 720 x 720 studs
		local ROCK_BOTTOM, ROCK_TOP = -64, 136 -- Y range of the rock block, relative to ORIGIN
		local LANE_HALF = 8 -- keep walking lanes this wide (each side) clear of props inside rooms

		local C = {
			wood = Color3.fromRGB(120, 85, 55),
			darkWood = Color3.fromRGB(78, 55, 37),
			plank = Color3.fromRGB(146, 108, 70),
			crate = Color3.fromRGB(162, 121, 76),
			barrel = Color3.fromRGB(112, 74, 46),
			metal = Color3.fromRGB(92, 96, 102),
			rust = Color3.fromRGB(126, 72, 45),
			locker = Color3.fromRGB(70, 92, 104),
			lockerAlt = Color3.fromRGB(86, 102, 76),
			roof = Color3.fromRGB(112, 84, 62),
			canvas = Color3.fromRGB(150, 130, 95),
			tentGreen = Color3.fromRGB(86, 100, 70),
			stone = Color3.fromRGB(98, 98, 104),
			bone = Color3.fromRGB(226, 219, 200),
			dark = Color3.fromRGB(24, 24, 28),
			lamp = Color3.fromRGB(255, 198, 122),
			lampLight = Color3.fromRGB(255, 178, 106),
			fire = Color3.fromRGB(255, 132, 50),
			lair = Color3.fromRGB(255, 48, 34),
			crystalA = Color3.fromRGB(80, 220, 255),
			crystalB = Color3.fromRGB(176, 96, 255),
		}

		local old = workspace:FindFirstChild("CaveSystem")
		-- caves from the first test versions (before this attribute existed) get replaced automatically
		local oldOrigin = old and old:GetAttribute("Origin")
		local oldBoxCenter = old and old:GetAttribute("BoxCenter")
		local oldBoxSize = old and old:GetAttribute("BoxSize")
		local fromTestVersion = old ~= nil and oldOrigin == nil
		if old and not CONFIG.OVERWRITE and not fromTestVersion then
			warn("[CaveBuilder] Workspace.CaveSystem already exists. To rebuild it, end the command with require(M)({ OVERWRITE = true }). That wipes the cave and anything you changed inside it.")
			return false
		end
		pcall(function()
			ChangeHistoryService:SetWaypoint("Before CaveBuilder")
		end)
		if old then
			if fromTestVersion and not CONFIG.OVERWRITE then
				print("[CaveBuilder] Replacing the cave made by an earlier test version of this script.")
			end
			old:Destroy()
		end

		-- Earlier versions put the rock block in other places. If one of those blocks is
		-- still there (a corner of it is solid Slate), clear it out.
		if typeof(oldBoxCenter) == "Vector3" and typeof(oldBoxSize) == "Vector3" then
			Terrain:FillBlock(CFrame.new(oldBoxCenter), oldBoxSize + Vector3.new(8, 8, 8), AIR)
		end
		local OLD_SPOTS = {
			{ origin = Vector3.new(0, -200, 0), probe = Vector3.new(384, -100, 384) }, -- under the Baseplate
			{ origin = Vector3.new(0, 64, -1450), probe = Vector3.new(384, 100, -1068) }, -- past the -Z edge
		}
		for _, spot in ipairs(OLD_SPOTS) do
			if (spot.origin - O).Magnitude > 1 then
				local ok, mats = pcall(function()
					return Terrain:ReadVoxels(Region3.new(spot.probe, spot.probe + Vector3.new(4, 4, 4)), 4)
				end)
				if ok and mats and mats[1] and mats[1][1] and mats[1][1][1] == ROCK then
					Terrain:FillBlock(CFrame.new(spot.origin + Vector3.new(0, 36, 0)), Vector3.new(808, 208, 808), AIR)
					print("[CaveBuilder] Cleared the leftover rock from an earlier attempt.")
				end
			end
		end

		------------------------------------------------------------------------
		-- Small helpers
		------------------------------------------------------------------------
		local function W(v) -- cave-local position -> world position
			return O + v
		end
		local function rand(a, b)
			return rng:NextNumber(a, b)
		end
		local function randInt(a, b)
			return rng:NextInteger(a, b)
		end
		local function pick(list)
			return list[rng:NextInteger(1, #list)]
		end
		local function flat(v)
			return Vector3.new(v.X, 0, v.Z)
		end
		local function lerp(a, b, t)
			return a + (b - a) * t
		end
		local function smooth(t)
			return t * t * (3 - 2 * t)
		end
		local function randDir()
			local a = rand(0, math.pi * 2)
			return Vector3.new(math.cos(a), 0, math.sin(a))
		end

		local stats = { parts = 0, lights = 0, hiding = 0, monster = 0, props = 0 }

		local root = Instance.new("Folder")
		root.Name = "CaveSystem"
		root:SetAttribute("Origin", O)
		local function folder(name)
			local f = Instance.new("Folder")
			f.Name = name
			f.Parent = root
			return f
		end
		local F = {
			spawn = folder("Spawn"),
			monster = folder("MonsterSpawns"),
			hiding = folder("HidingSpots"),
			structures = folder("Structures"),
			decor = folder("Decor"),
			lights = folder("Lights"),
			propSpots = folder("PropSpots"),
			rooms = folder("Rooms"),
		}

		------------------------------------------------------------------------
		-- Layout. Positions are relative to ORIGIN. pos.Y is the floor height.
		-- +Z is "south" (Base Camp), -Z is "north" (the lairs).
		------------------------------------------------------------------------
		-- Base Camp in the south, the Great Cavern in the middle, the Old Mine and Crystal
		-- Grotto out in the far corners. monsterSpawn = a MonsterSpawn at the room's far end.
		-- (Other room kinds still work if you add them: kind = "Lair" for a monster lair,
		-- kind = "Maze" with a cell size for the Backrooms.)
		local ROOMS = {
			{ name = "BaseCamp", kind = "Spawn", pos = Vector3.new(0, 0, 180), rx = 40, rz = 34, h = 32, floor = M.Ground },
			{ name = "GreatCavern", kind = "Big", pos = Vector3.new(0, -8, 0), rx = 105, rz = 80, h = 60, floor = M.Ground, monsterSpawn = true },
			{ name = "OldMine", kind = "Room", pos = Vector3.new(-250, 0, -60), rx = 56, rz = 44, h = 30, floor = M.Ground, wall = M.Sandstone, monsterSpawn = true },
			{ name = "CrystalGrotto", kind = "Room", pos = Vector3.new(250, 4, -60), rx = 52, rz = 46, h = 40, floor = M.Rock, wall = M.Basalt, monsterSpawn = true },
		}

		-- { from, to, radius, lantern every N studs (nil = pitch dark) }
		local TUNNELS = {
			{ "BaseCamp", "GreatCavern", 13, 60 },
			{ "BaseCamp", "OldMine", 11, 70 },
			{ "BaseCamp", "CrystalGrotto", 11, 70 },
			{ "OldMine", "GreatCavern", 11, 80 },
			{ "CrystalGrotto", "GreatCavern", 11, 80 },
		}

		local rooms, ROOM = {}, {}
		for _, r in ipairs(ROOMS) do
			if r.kind == "Maze" then
				r.h = math.floor(r.h * math.max(TS, 1) + 0.5)
			end
			r.wall = r.wall or ROCK
			r.entrances, r.blocks = {}, {}
			table.insert(rooms, r)
			ROOM[r.name] = r
		end

		local function ellipseNorm(room, p) -- < 1 means p is inside the room's floor
			local d = flat(p) - flat(room.pos)
			return math.sqrt((d.X / room.rx) ^ 2 + (d.Z / room.rz) ^ 2)
		end
		local function edgeDist(room, dir) -- distance from the room center to its wall along dir
			return 1 / math.sqrt((dir.X / room.rx) ^ 2 + (dir.Z / room.rz) ^ 2)
		end
		local function inFootprint(room, p, pad) -- is p within the room's floor plus pad studs?
			local d = flat(p) - flat(room.pos)
			if room.kind == "Maze" then
				return math.abs(d.X) < room.rx + pad and math.abs(d.Z) < room.rz + pad
			end
			return (d.X / (room.rx + pad)) ^ 2 + (d.Z / (room.rz + pad)) ^ 2 < 1
		end
		local function insideAnyRoom(p, scale)
			for _, room in ipairs(rooms) do
				if ellipseNorm(room, p) < scale or (room.kind == "Maze" and inFootprint(room, p, 0)) then
					return true
				end
			end
			return false
		end

		------------------------------------------------------------------------
		-- Tunnel paths: a smooth wiggly curve between two points
		------------------------------------------------------------------------
		local tunnels = {}

		local function catmull(p0, p1, p2, p3, t)
			local t2, t3 = t * t, t * t * t
			return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
		end

		local function addTunnel(def)
			local r = def.r * TS
			local delta = def.b - def.a
			local len = delta.Magnitude
			local dir = delta.Unit
			local perp = Vector3.new(-dir.Z, 0, dir.X)
			local ctrl = { def.a }
			local n = math.max(1, math.floor(len / 70))
			for i = 1, n do
				local off = rand(-1, 1) * math.min(def.wiggle, len * 0.15)
				table.insert(ctrl, def.a + delta * (i / (n + 1)) + perp * off)
			end
			table.insert(ctrl, def.b)

			local step = math.max(3, r * 0.45)
			local pts = { def.a }
			for i = 1, #ctrl - 1 do
				local p0, p1, p2, p3 = ctrl[math.max(i - 1, 1)], ctrl[i], ctrl[i + 1], ctrl[math.min(i + 2, #ctrl)]
				local m = math.max(1, math.ceil((p2 - p1).Magnitude / step))
				for j = 1, m do
					table.insert(pts, catmull(p0, p1, p2, p3, j / m))
				end
			end

			local total, dist = 0, { 0 }
			for i = 2, #pts do
				total += (pts[i] - pts[i - 1]).Magnitude
				dist[i] = total
			end
			-- floor stays level inside the rooms, then slopes smoothly with a few gentle bumps
			local ph1, ph2 = rand(0, 6.28), rand(0, 6.28)
			local bump = total > 120 and rand(1, 4) or 0
			local span = math.max(total - def.flatA - def.flatB, 1)
			local samples = {}
			for i, p in ipairs(pts) do
				local s = dist[i]
				local u = math.clamp((s - def.flatA) / span, 0, 1)
				local y = lerp(def.floorA, def.floorB, smooth(u)) + math.sin(u * math.pi) * math.sin(u * math.pi * 3 + ph1) * bump
				local ri = r * (1 + 0.12 * math.sin(s * 0.045 + ph1) + 0.06 * math.sin(s * 0.11 + ph2))
				samples[i] = { pos = Vector3.new(p.X, y, p.Z), r = ri, s = s }
			end
			local t = {
				name = def.name,
				kind = def.kind,
				r = r,
				samples = samples,
				length = total,
				lightEvery = def.lightEvery,
				lightOpts = def.lightOpts,
			}
			table.insert(tunnels, t)
			return t
		end

		for _, def in ipairs(TUNNELS) do
			local A, B = ROOM[def[1]], ROOM[def[2]]
			local d = flat(B.pos - A.pos).Unit
			local ta, tb = edgeDist(A, d), edgeDist(B, -d)
			local t = addTunnel({
				name = A.name .. "_to_" .. B.name,
				kind = "Tunnel",
				a = flat(A.pos) + d * ta * 0.7,
				b = flat(B.pos) - d * tb * 0.7,
				floorA = A.pos.Y,
				floorB = B.pos.Y,
				flatA = ta * 0.3 + 8,
				flatB = tb * 0.3 + 8,
				r = def[3],
				wiggle = 32,
				lightEvery = def[4],
				lightOpts = def[4] and def[4] >= 110 and { brightness = 0.8, range = 20 } or nil,
			})
			t.roomA, t.roomB = A, B
			-- remember where the tunnel breaks through each room's wall (keeps those lanes clear)
			for i = 1, #t.samples do
				if ellipseNorm(A, t.samples[i].pos) >= 1 then
					table.insert(A.entrances, flat(t.samples[i].pos))
					break
				end
			end
			for i = #t.samples, 1, -1 do
				if ellipseNorm(B, t.samples[i].pos) >= 1 then
					table.insert(B.entrances, flat(t.samples[i].pos))
					break
				end
			end
		end

		------------------------------------------------------------------------
		-- Nooks: little dead-end alcoves off the longer tunnels
		------------------------------------------------------------------------
		local nooks = {}
		local mainTunnels = table.clone(tunnels)

		local function nookFits(c, own, idx)
			if math.abs(c.X) > HALF - 50 or math.abs(c.Z) > HALF - 50 then
				return false
			end
			for _, room in ipairs(rooms) do
				if inFootprint(room, c, 30) then
					return false
				end
			end
			for _, t in ipairs(tunnels) do
				for j, s in ipairs(t.samples) do
					if not (t == own and math.abs(j - idx) < 14) and (flat(s.pos) - c).Magnitude < s.r + 28 then
						return false
					end
				end
			end
			return true
		end

		for _, t in ipairs(mainTunnels) do
			if t.length > 130 then
				for _, f in ipairs(t.length > 260 and { 0.33, 0.67 } or { 0.5 }) do
					local idx = math.clamp(math.floor(#t.samples * (f + rand(-0.08, 0.08))), 2, #t.samples - 1)
					local s = t.samples[idx]
					local tan = flat(t.samples[idx + 1].pos - t.samples[idx - 1].pos).Unit
					local side = rand(0, 1) < 0.5 and 1 or -1
					for _ = 1, 2 do
						local c = flat(s.pos) + Vector3.new(-tan.Z, 0, tan.X) * side * (s.r + 20)
						if nookFits(c, t, idx) then
							local nook = {
								name = "Nook" .. (#nooks + 1),
								kind = "Nook",
								pos = Vector3.new(c.X, s.pos.Y, c.Z),
								rx = 13,
								rz = 13,
								h = 16,
								floor = M.Ground,
								wall = ROCK,
								entrances = { flat(s.pos) },
								blocks = {},
							}
							addTunnel({
								name = nook.name .. "_passage",
								kind = "Passage",
								a = flat(s.pos),
								b = c,
								floorA = s.pos.Y,
								floorB = s.pos.Y,
								flatA = 0,
								flatB = 0,
								r = 7,
								wiggle = 0,
							})
							table.insert(rooms, nook)
							table.insert(nooks, nook)
							break
						end
						side = -side
					end
				end
			end
		end

		------------------------------------------------------------------------
		-- TERRAIN: solid rock, carve rooms + tunnels, flatten floors, theme walls
		------------------------------------------------------------------------
		-- Lift anything in Workspace that's where the rock is going onto the top of it,
		-- so nothing ends up buried (your models get moved into the cave afterwards).
		local rockLo = W(Vector3.new(-HALF, ROCK_BOTTOM, -HALF))
		local rockHi = W(Vector3.new(HALF, ROCK_TOP, HALF))
		local function boxOf(inst)
			local lo = Vector3.new(math.huge, math.huge, math.huge)
			local hi = -lo
			local list = inst:IsA("BasePart") and { inst } or {}
			for _, d in ipairs(inst:GetDescendants()) do
				if d:IsA("BasePart") then
					table.insert(list, d)
				end
			end
			for _, part in ipairs(list) do
				local h = part.Size / 2
				for _, sx in ipairs({ -1, 1 }) do
					for _, sy in ipairs({ -1, 1 }) do
						for _, sz in ipairs({ -1, 1 }) do
							local c = part.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
							lo = Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
							hi = Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
						end
					end
				end
			end
			return lo, hi
		end
		local lifted = {}
		local function liftIfBuried(inst)
			if inst:IsA("Terrain") or inst:IsA("Camera") or inst.Name == "Baseplate" then
				return
			end
			if inst:IsA("Folder") then
				for _, c in ipairs(inst:GetChildren()) do
					liftIfBuried(c)
				end
				return
			end
			if not (inst:IsA("Model") or inst:IsA("BasePart")) then
				return
			end
			local lo, hi = boxOf(inst)
			local size = hi - lo
			local overlaps = lo.X < rockHi.X and hi.X > rockLo.X and lo.Y < rockHi.Y and hi.Y > rockLo.Y and lo.Z < rockHi.Z and hi.Z > rockLo.Z
			if lo.X ~= math.huge and overlaps and math.max(size.X, size.Z) < 1000 then
				-- keep the gap to whatever it was standing on (a mesh can stick out of its part's box)
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { inst }
				local hit = workspace:Raycast(Vector3.new((lo.X + hi.X) / 2, hi.Y + 1, (lo.Z + hi.Z) / 2), Vector3.new(0, -(size.Y + 60), 0), params)
				local ground = hit and hit.Position.Y or lo.Y
				inst:PivotTo(inst:GetPivot() + Vector3.new(0, rockHi.Y - ground + 0.05, 0))
				lifted[inst.Name] = (lifted[inst.Name] or 0) + 1
			end
		end
		local rebuildingInPlace = oldOrigin == O
		if not rebuildingInPlace then
			for _, c in ipairs(workspace:GetChildren()) do
				liftIfBuried(c)
			end
		end
		local liftedNames = {}
		for name, n in pairs(lifted) do
			table.insert(liftedNames, n > 1 and (name .. " x" .. n) or name)
		end
		table.sort(liftedNames)

		local CHUNK = 240
		for x = -HALF, HALF - CHUNK, CHUNK do
			for z = -HALF, HALF - CHUNK, CHUNK do
				Terrain:FillBlock(
					CFrame.new(W(Vector3.new(x + CHUNK / 2, (ROCK_TOP + ROCK_BOTTOM) / 2, z + CHUNK / 2))),
					Vector3.new(CHUNK, ROCK_TOP - ROCK_BOTTOM, CHUNK),
					ROCK
				)
			end
		end

		-- A room is a cluster of big air balls. Ball centers sit at 0.4*h above the
		-- floor with radius 0.6*h, so the ceiling is ~h high and the walls reach the
		-- floor at about rx/rz. The bit of each ball under the floor is filled back in.
		local function carveRoom(room)
			room.balls = {}
			if room.kind == "Maze" then -- a plain box; the walls, floor and ceiling are parts
				Terrain:FillBlock(CFrame.new(W(room.pos + Vector3.new(0, (room.h + 2) / 2, 0))), Vector3.new(room.rx * 2, room.h + 2, room.rz * 2), AIR)
				return
			end
			local h = room.h
			local R = 0.6 * h
			local ex = math.max(room.rx - 0.447 * h, 1)
			local ez = math.max(room.rz - 0.447 * h, 1)
			local spacing = math.max(R * 0.6, 4)
			local centers = {}
			local ring = math.max(6, math.ceil(2 * math.pi * math.max(ex, ez) / spacing))
			for i = 1, ring do
				local a = i / ring * math.pi * 2
				table.insert(centers, Vector3.new(math.cos(a) * ex, 0, math.sin(a) * ez))
			end
			local nx, nz = math.floor(ex / spacing), math.floor(ez / spacing)
			for i = -nx, nx do
				for j = -nz, nz do
					local x = i * spacing + rand(-0.2, 0.2) * spacing
					local z = j * spacing + rand(-0.2, 0.2) * spacing
					if (x / ex) ^ 2 + (z / ez) ^ 2 <= 1 then
						table.insert(centers, Vector3.new(x, 0, z))
					end
				end
			end
			room.balls = {}
			for _, c in ipairs(centers) do
				local pos = Vector3.new(room.pos.X + c.X, room.pos.Y + 0.4 * h, room.pos.Z + c.Z)
				local r = R * rand(0.92, 1.1)
				Terrain:FillBall(W(pos), r, AIR)
				table.insert(room.balls, { pos = pos, r = r })
			end
		end

		local function floorRoom(room)
			if room.kind == "Maze" then
				Terrain:FillBlock(CFrame.new(W(room.pos - Vector3.new(0, 4, 0))), Vector3.new(room.rx * 2 + 8, 8, room.rz * 2 + 8), room.floor)
				return
			end
			local lift = 0.4 * room.h
			for _, b in ipairs(room.balls) do
				local depth = b.r - lift + 4
				local spread = math.sqrt(math.max(b.r ^ 2 - lift ^ 2, 0)) + 3
				Terrain:FillCylinder(CFrame.new(W(Vector3.new(b.pos.X, room.pos.Y - depth / 2, b.pos.Z))), depth, spread, room.floor)
			end
		end

		local function carveTunnel(t)
			for _, s in ipairs(t.samples) do
				Terrain:FillBall(W(s.pos + Vector3.new(0, 0.5 * s.r, 0)), s.r, AIR)
			end
		end

		local function floorTunnel(t)
			local n = #t.samples
			for i, s in ipairs(t.samples) do
				local tangent = t.samples[math.min(i + 1, n)].pos - t.samples[math.max(i - 1, 1)].pos
				if tangent.Magnitude > 0.01 then
					local thick = 0.5 * s.r + 4
					local cf = CFrame.lookAt(W(s.pos), W(s.pos) + tangent) * CFrame.new(0, -thick / 2, 0)
					Terrain:FillBlock(cf, Vector3.new(1.75 * s.r + 3, thick, tangent.Magnitude + 2), M.Ground)
				end
			end
		end

		for _, room in ipairs(rooms) do
			carveRoom(room)
		end
		for _, t in ipairs(tunnels) do
			carveTunnel(t)
		end
		for _, room in ipairs(rooms) do
			floorRoom(room)
		end
		for _, t in ipairs(tunnels) do
			floorTunnel(t)
		end
		for _, room in ipairs(rooms) do
			if room.wall ~= ROCK then
				local pad = Vector3.new(room.rx + 24, 0, room.rz + 24)
				local lo = W(room.pos - pad - Vector3.new(0, 30, 0))
				local hi = W(room.pos + pad + Vector3.new(0, room.h + 24, 0))
				Terrain:ReplaceMaterial(Region3.new(lo, hi):ExpandToGrid(4), 4, ROCK, room.wall)
			end
		end

		-- darker, wetter-looking rock. This sets the colour of these terrain materials everywhere
		pcall(function()
			for mat, col in pairs({
				[M.Slate] = Color3.fromRGB(62, 64, 70),
				[M.Basalt] = Color3.fromRGB(38, 38, 44),
				[M.Rock] = Color3.fromRGB(76, 74, 72),
				[M.Ground] = Color3.fromRGB(62, 50, 38),
				[M.Mud] = Color3.fromRGB(44, 36, 28),
				[M.Sand] = Color3.fromRGB(108, 96, 74),
				[M.Limestone] = Color3.fromRGB(112, 108, 96),
				[M.Sandstone] = Color3.fromRGB(112, 84, 60),
			}) do
				Terrain:SetMaterialColor(mat, col)
			end
			Terrain.WaterColor = Color3.fromRGB(20, 38, 42)
			Terrain.WaterTransparency = 0.6
			Terrain.WaterReflectance = 0.4
			Terrain.WaterWaveSize = 0.05
			Terrain.WaterWaveSpeed = 4
		end)

		------------------------------------------------------------------------
		-- Part helpers
		------------------------------------------------------------------------
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = { Terrain }

		-- nudge a floor position onto the visible terrain surface (if the ray finds it)
		local function snapY(pos)
			local ok, hit = pcall(function()
				return workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -8, 0), rayParams)
			end)
			if ok and hit and math.abs(hit.Position.Y - pos.Y) < 1.5 then
				return Vector3.new(pos.X, hit.Position.Y, pos.Z)
			end
			return pos
		end

		local function P(parent, size, cf, color, mat, props)
			local p = Instance.new("Part")
			p.Anchored = true
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Size = size
			p.CFrame = cf
			p.Color = color
			p.Material = mat or M.SmoothPlastic
			if props then
				for k, v in pairs(props) do
					p[k] = v
				end
			end
			p.Parent = parent
			stats.parts += 1
			return p
		end

		local function invisible(p)
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Transparency = 1
			return p
		end

		local function marker(parent, name, cf, size)
			local p = invisible(P(parent, size or Vector3.new(1, 1, 1), cf, C.dark))
			p.Name = name
			return p
		end

		-- a plank/pole from a to b: w = width (sideways), t = thickness
		local function beam(parent, a, b, w, t, color, mat, props)
			local dir = b - a
			local up = math.abs(dir.Unit.Y) > 0.98 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
			return P(parent, Vector3.new(w, t, dir.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, mat, props)
		end

		-- cylinder lying along cf's X axis (cf * UPRIGHT stands it up)
		local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
		local function cyl(parent, length, diameter, cf, color, mat, props)
			local p = P(parent, Vector3.new(length, diameter, diameter), cf, color, mat, props)
			p.Shape = Enum.PartType.Cylinder
			return p
		end

		local GLOW = CONFIG.DARK_CAVE and 0.3 or 1 -- dark mode dims every light except the campfire + Base Camp
		local function addLight(parent, range, brightness, color, full)
			local l = Instance.new("PointLight")
			l.Range = range
			l.Brightness = brightness * (full and 1 or GLOW)
			l.Color = color
			l.Shadows = CONFIG.LIGHT_SHADOWS
			l.Parent = parent
			stats.lights += 1
			return l
		end

		local function newModel(name)
			local m = Instance.new("Model")
			m.Name = name
			return m
		end

		-- wall (bottom-center at cf, width along X) with one rectangular hole in it
		local function wallWithHole(parent, cf, w, h, t, hx, hw, hy, hh, color, mat)
			local function piece(x0, x1, y0, y1)
				if x1 - x0 > 0.05 and y1 - y0 > 0.05 then
					P(parent, Vector3.new(x1 - x0, y1 - y0, t), cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0), color, mat)
				end
			end
			local l, r = hx - hw / 2, hx + hw / 2
			piece(-w / 2, l, 0, h)
			piece(r, w / 2, 0, h)
			piece(l, r, 0, hy)
			piece(l, r, hy + hh, h)
		end

		------------------------------------------------------------------------
		-- Hiding spots. Every builder takes a floor CFrame whose LookVector is
		-- the side players walk up to (the door / opening side).
		------------------------------------------------------------------------
		local function finishHide(m, kind, cf, hideAt, exitAt, parent)
			marker(m, "HidePoint", cf * hideAt) -- where a hidden player is tucked away
			marker(m, "ExitPoint", cf * exitAt) -- where they pop out when found / leaving
			m.PrimaryPart = m:FindFirstChild("Base")
			m:SetAttribute("HideType", kind)
			m:SetAttribute("Occupied", false)
			CollectionService:AddTag(m, "HidingSpot")
			m.Parent = parent or F.hiding
			stats.hiding += 1
			return m
		end

		local function buildWardrobe(cf, parent)
			local m = newModel("Wardrobe")
			local w, h, d = 5, 8, 3
			local midY = 0.4 + (h - 0.4) / 2
			P(m, Vector3.new(w, 0.4, d), cf * CFrame.new(0, 0.2, 0), C.darkWood, M.Wood).Name = "Base"
			P(m, Vector3.new(w, h - 0.4, 0.3), cf * CFrame.new(0, midY, d / 2 - 0.15), C.wood, M.Wood)
			P(m, Vector3.new(0.3, h - 0.4, d), cf * CFrame.new(-w / 2 + 0.15, midY, 0), C.wood, M.Wood)
			P(m, Vector3.new(0.3, h - 0.4, d), cf * CFrame.new(w / 2 - 0.15, midY, 0), C.wood, M.Wood)
			P(m, Vector3.new(w + 0.4, 0.4, d + 0.4), cf * CFrame.new(0, h + 0.2, 0), C.darkWood, M.Wood)
			for i, x in ipairs({ -1, 1 }) do
				local door = P(m, Vector3.new(w / 2 - 0.35, h - 0.7, 0.25), cf * CFrame.new(x * (w / 4 - 0.05), midY, -d / 2 + 0.12), C.plank, M.Wood)
				door.Name = i == 1 and "DoorL" or "DoorR"
				P(m, Vector3.new(0.2, 0.9, 0.2), cf * CFrame.new(x * 0.35, 4.2, -d / 2 - 0.1), C.metal, M.Metal, { CanCollide = false })
			end
			return finishHide(m, "Wardrobe", cf, CFrame.new(0, 3, 0.1), CFrame.new(0, 3, -d / 2 - 3), parent)
		end

		local function buildLocker(cf, parent, color)
			local m = newModel("Locker")
			local col = color or pick({ C.locker, C.lockerAlt, C.metal })
			local w, h, d = 3.2, 8, 2.8
			local midY = 0.3 + (h - 0.3) / 2
			P(m, Vector3.new(w, 0.3, d), cf * CFrame.new(0, 0.15, 0), col, M.Metal).Name = "Base"
			P(m, Vector3.new(w, h - 0.3, 0.2), cf * CFrame.new(0, midY, d / 2 - 0.1), col, M.Metal)
			P(m, Vector3.new(0.2, h - 0.3, d), cf * CFrame.new(-w / 2 + 0.1, midY, 0), col, M.Metal)
			P(m, Vector3.new(0.2, h - 0.3, d), cf * CFrame.new(w / 2 - 0.1, midY, 0), col, M.Metal)
			P(m, Vector3.new(w, 0.3, d), cf * CFrame.new(0, h + 0.15, 0), col, M.Metal)
			P(m, Vector3.new(w - 0.1, h - 0.4, 0.2), cf * CFrame.new(0, midY, -d / 2 + 0.1), col, M.Metal).Name = "Door"
			for i = 0, 2 do
				P(m, Vector3.new(1.8, 0.15, 0.05), cf * CFrame.new(0, 6.6 + i * 0.35, -d / 2 - 0.03), C.dark, M.SmoothPlastic, { CanCollide = false })
			end
			P(m, Vector3.new(0.2, 0.7, 0.2), cf * CFrame.new(w / 2 - 0.5, 4, -d / 2 - 0.12), C.dark, M.Metal, { CanCollide = false })
			return finishHide(m, "Locker", cf, CFrame.new(0, 3, 0), CFrame.new(0, 3, -d / 2 - 3), parent)
		end

		local function buildBarrel(cf, parent)
			local m = newModel("Barrel")
			cyl(m, 6, 5, cf * CFrame.new(0, 3, 0) * UPRIGHT, C.barrel, M.Wood).Name = "Base"
			for _, y in ipairs({ 1.2, 4.8 }) do
				cyl(m, 0.35, 5.2, cf * CFrame.new(0, y, 0) * UPRIGHT, C.metal, M.Metal, { CanCollide = false })
			end
			cyl(m, 0.3, 4.6, cf * CFrame.new(0, 6.15, 0) * UPRIGHT, C.darkWood, M.Wood).Name = "Lid"
			return finishHide(m, "Barrel", cf, CFrame.new(0, 3, 0), CFrame.new(0, 3, -5.5), parent)
		end

		local function buildCrate(cf, parent)
			local m = newModel("Crate")
			P(m, Vector3.new(6, 6, 6), cf * CFrame.new(0, 3, 0), C.crate, M.WoodPlanks).Name = "Base"
			P(m, Vector3.new(6.4, 0.5, 6.4), cf * CFrame.new(0, 6.25, 0), C.wood, M.WoodPlanks).Name = "Lid"
			for _, x in ipairs({ -1, 1 }) do
				for _, z in ipairs({ -1, 1 }) do
					P(m, Vector3.new(0.6, 6, 0.6), cf * CFrame.new(x * 2.85, 3, z * 2.85), C.wood, M.Wood)
				end
			end
			for _, z in ipairs({ -3.08, 3.08 }) do
				beam(m, (cf * CFrame.new(-2.5, 0.6, z)).Position, (cf * CFrame.new(2.5, 5.4, z)).Position, 0.15, 0.6, C.wood, M.Wood, { CanCollide = false })
			end
			return finishHide(m, "Crate", cf, CFrame.new(0, 3, 0), CFrame.new(0, 3, -6), parent)
		end

		local function buildMinecart(cf, parent) -- rolls along its Z axis
			local m = newModel("Minecart")
			local col = pick({ C.rust, C.metal })
			P(m, Vector3.new(3.6, 0.4, 5), cf * CFrame.new(0, 2, 0), col, M.Metal).Name = "Base"
			P(m, Vector3.new(3.6, 2.4, 0.3), cf * CFrame.new(0, 3.4, -2.35), col, M.Metal)
			P(m, Vector3.new(3.6, 2.4, 0.3), cf * CFrame.new(0, 3.4, 2.35), col, M.Metal)
			P(m, Vector3.new(0.3, 2.4, 4.4), cf * CFrame.new(-1.65, 3.4, 0), col, M.Metal)
			P(m, Vector3.new(0.3, 2.4, 4.4), cf * CFrame.new(1.65, 3.4, 0), col, M.Metal)
			for _, x in ipairs({ -1.5, 1.5 }) do
				for _, z in ipairs({ -1.6, 1.6 }) do
					cyl(m, 0.4, 1.5, cf * CFrame.new(x, 1.35, z), C.dark, M.Metal)
				end
			end
			return finishHide(m, "Minecart", cf, CFrame.new(0, 3, 0), CFrame.new(-4.5, 3, 0), parent)
		end

		local HIDE_BUILDERS = {
			Locker = buildLocker,
			Wardrobe = buildWardrobe,
			Barrel = buildBarrel,
			Crate = buildCrate,
		}
		local HIDE_KINDS = { "Locker", "Wardrobe", "Barrel", "Crate" }

		------------------------------------------------------------------------
		-- Structures + decoration
		------------------------------------------------------------------------
		local function buildTable(cf, parent)
			local m = newModel("Table")
			P(m, Vector3.new(4.5, 0.35, 2.6), cf * CFrame.new(0, 3.2, 0), C.wood, M.Wood)
			for _, x in ipairs({ -1.9, 1.9 }) do
				for _, z in ipairs({ -1, 1 }) do
					P(m, Vector3.new(0.35, 3.05, 0.35), cf * CFrame.new(x, 1.5, z), C.darkWood, M.Wood)
				end
			end
			m.Parent = parent
			return m
		end

		local function buildShack(cf)
			local m = newModel("Shack")
			local sw, sd, sh = 14, 12, 9
			local wallC = pick({ C.wood, C.plank, C.darkWood })
			local base = P(m, Vector3.new(sw, 0.6, sd), cf * CFrame.new(0, 0.3, 0), C.darkWood, M.WoodPlanks)
			base.Name = "Base"
			-- front wall with a doorway, back wall, left wall with a window, right wall
			wallWithHole(m, cf * CFrame.new(0, 0.6, -sd / 2 + 0.3), sw, sh + 1.5, 0.6, -3, 4.5, 0, 7.5, wallC, M.WoodPlanks)
			P(m, Vector3.new(sw, sh, 0.6), cf * CFrame.new(0, 0.6 + sh / 2, sd / 2 - 0.3), wallC, M.WoodPlanks)
			wallWithHole(m, cf * CFrame.new(-sw / 2 + 0.3, 0.6, 0) * CFrame.Angles(0, math.pi / 2, 0), sd - 1.2, sh, 0.6, 0, 3, 3.5, 2.5, wallC, M.WoodPlanks)
			P(m, Vector3.new(0.6, sh, sd - 1.2), cf * CFrame.new(sw / 2 - 0.3, 0.6 + sh / 2, 0), wallC, M.WoodPlanks)
			-- sloped tin roof
			beam(m, (cf * CFrame.new(0, sh + 2.4, -sd / 2 - 1)).Position, (cf * CFrame.new(0, sh + 0.9, sd / 2 + 1)).Position, sw + 1.6, 0.4, C.roof, M.CorrodedMetal)
			-- door swung open against the front wall
			P(m, Vector3.new(0.3, 7.4, 4.4), cf * CFrame.new(-5.4, 4.3, -sd / 2 - 2.2), C.plank, M.WoodPlanks).Name = "Door"
			-- inside: a wardrobe to hide in, a table, a crate and a lamp
			buildWardrobe(cf * CFrame.new(sw / 2 - 3.3, 0.6, sd / 2 - 2.3), m)
			buildTable(cf * CFrame.new(-3.6, 0.6, sd / 2 - 2.4), m)
			P(m, Vector3.new(2.6, 2.6, 2.6), cf * CFrame.new(4.4, 1.9, -sd / 2 + 2.4) * CFrame.Angles(0, 0.3, 0), C.crate, M.WoodPlanks)
			local lamp = P(m, Vector3.new(0.8, 1.1, 0.8), cf * CFrame.new(0, sh - 1, 0), C.lamp, M.Neon, { CanCollide = false })
			addLight(lamp, 18, 0.9, C.lampLight)
			m.PrimaryPart = base
			m.Parent = F.structures
			return m
		end

		local function buildLanternPost(cf, opts)
			opts = opts or {}
			local m = newModel("Lantern")
			local h = 7
			P(m, Vector3.new(0.6, h, 0.6), cf * CFrame.new(0, h / 2, 0), C.darkWood, M.Wood)
			P(m, Vector3.new(0.4, 0.4, 2.3), cf * CFrame.new(0, h - 0.2, -0.95), C.darkWood, M.Wood)
			P(m, Vector3.new(0.12, 0.5, 0.12), cf * CFrame.new(0, h - 0.65, -1.9), C.metal, M.Metal, { CanCollide = false })
			local lamp = P(m, Vector3.new(0.8, 1.2, 0.8), cf * CFrame.new(0, h - 1.5, -1.9), C.lamp, M.Neon, { CanCollide = false })
			lamp.Name = "Lamp"
			P(m, Vector3.new(1.1, 0.2, 1.1), cf * CFrame.new(0, h - 0.85, -1.9), C.metal, M.Metal, { CanCollide = false })
			P(m, Vector3.new(1.1, 0.2, 1.1), cf * CFrame.new(0, h - 2.15, -1.9), C.metal, M.Metal, { CanCollide = false })
			addLight(lamp, opts.range or 26, opts.brightness or 1.3, C.lampLight, opts.full)
			m.Parent = F.lights
			return m
		end

		local function buildHangingLantern(top, drop, parent)
			P(parent, Vector3.new(0.12, drop, 0.12), CFrame.new(top - Vector3.new(0, drop / 2, 0)), C.metal, M.Metal, { CanCollide = false })
			local lamp = P(parent, Vector3.new(0.8, 1.2, 0.8), CFrame.new(top - Vector3.new(0, drop + 0.6, 0)), C.lamp, M.Neon, { CanCollide = false })
			addLight(lamp, 24, 1.2, C.lampLight)
			return lamp
		end

		local function buildCampfire(cf)
			local m = newModel("Campfire")
			for i = 1, 8 do
				local a = i / 8 * math.pi * 2
				P(m, Vector3.new(1.3, 0.9, 1.3), cf * CFrame.new(math.cos(a) * 2.4, 0.4, math.sin(a) * 2.4) * CFrame.Angles(0, a, 0), C.stone, M.Slate)
			end
			for i = 1, 3 do
				cyl(m, 3.6, 0.6, cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, i * math.pi / 3, 0.25), C.darkWood, M.Wood, { CanCollide = false })
			end
			local core = marker(m, "FireCore", cf * CFrame.new(0, 0.8, 0))
			local fire = Instance.new("Fire")
			fire.Size = 5
			fire.Heat = 8
			fire.Color = C.fire
			fire.SecondaryColor = Color3.fromRGB(255, 210, 90)
			fire.Parent = core
			addLight(core, 34, 2, C.fire, true)
			for _, a in ipairs({ 0.6, 2.7, 4.6 }) do -- log benches
				cyl(m, 5, 1.4, cf * CFrame.new(math.cos(a) * 6.5, 0.7, math.sin(a) * 6.5) * CFrame.Angles(0, math.pi / 2 - a, 0), C.wood, M.Wood)
			end
			m.Parent = F.decor
			return m
		end

		local function buildTent(cf)
			local m = newModel("Tent")
			local L, hw, h = 8, 3.6, 5
			local col = pick({ C.canvas, C.tentGreen })
			local top = (cf * CFrame.new(0, h, 0)).Position
			for _, side in ipairs({ -1, 1 }) do
				beam(m, (cf * CFrame.new(0, 0.1, side * hw)).Position, top, L, 0.2, col, M.Fabric)
			end
			beam(m, (cf * CFrame.new(-L / 2 - 0.3, h, 0)).Position, (cf * CFrame.new(L / 2 + 0.3, h, 0)).Position, 0.35, 0.35, C.darkWood, M.Wood)
			for _, x in ipairs({ -L / 2 - 0.1, L / 2 + 0.1 }) do
				P(m, Vector3.new(0.3, h, 0.3), cf * CFrame.new(x, h / 2, 0), C.darkWood, M.Wood)
			end
			m.Parent = F.decor
			return m
		end

		local function buildSign(cf, text)
			local m = newModel("Sign")
			for _, x in ipairs({ -3, 3 }) do
				P(m, Vector3.new(0.5, 7, 0.5), cf * CFrame.new(x, 3.5, 0), C.darkWood, M.Wood)
			end
			local board = P(m, Vector3.new(7.4, 2.4, 0.4), cf * CFrame.new(0, 5.6, 0), C.plank, M.WoodPlanks)
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.Parent = board
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = text
			label.TextScaled = true
			label.Font = Enum.Font.Fantasy
			label.TextColor3 = Color3.fromRGB(45, 28, 16)
			label.Parent = gui
			m.Parent = F.decor
			return m
		end

		local function buildClutter(cf)
			local m = newModel("Clutter")
			local roll = rand(0, 1)
			if roll < 0.45 then -- stack of crates
				local s1, s2 = rand(2.8, 3.8), rand(2.4, 3.2)
				P(m, Vector3.new(s1, s1, s1), cf * CFrame.new(-1, s1 / 2, 0) * CFrame.Angles(0, rand(-0.3, 0.3), 0), C.crate, M.WoodPlanks)
				P(m, Vector3.new(s2, s2, s2), cf * CFrame.new(s1 / 2 + 0.6, s2 / 2, rand(-0.6, 0.6)) * CFrame.Angles(0, rand(-0.4, 0.4), 0), C.crate, M.WoodPlanks)
				if rand(0, 1) < 0.5 then
					local s3 = rand(2, 2.6)
					P(m, Vector3.new(s3, s3, s3), cf * CFrame.new(-1, s1 + s3 / 2, 0) * CFrame.Angles(0, rand(-0.5, 0.5), 0), C.wood, M.WoodPlanks)
				end
			elseif roll < 0.8 then -- a few small barrels
				for i = 1, randInt(1, 3) do
					cyl(m, 3.4, 2.6, cf * CFrame.new((i - 2) * 2.8, 1.7, rand(-0.5, 0.5)) * UPRIGHT, C.barrel, M.Wood)
				end
			else
				buildTable(cf, m)
			end
			m.Parent = F.decor
			return m
		end

		local function buildMineSupport(cf) -- a timber frame against the wall
			local m = newModel("MineSupport")
			local w, h = 10, 10
			for _, x in ipairs({ -w / 2, w / 2 }) do
				P(m, Vector3.new(1, h, 1), cf * CFrame.new(x, h / 2, 0), C.wood, M.Wood)
				beam(m, (cf * CFrame.new(x, h - 2.6, 0)).Position, (cf * CFrame.new(x - math.sign(x) * 2.6, h, 0)).Position, 0.6, 0.6, C.darkWood, M.Wood)
			end
			P(m, Vector3.new(w + 1.6, 1.1, 1.2), cf * CFrame.new(0, h + 0.55, 0), C.wood, M.Wood)
			buildHangingLantern((cf * CFrame.new(0, h, -0.7)).Position, 1, m)
			m.Parent = F.structures
			return m
		end

		local function buildRails(a, b)
			local m = newModel("Rails")
			local len = (b - a).Magnitude
			local cf = CFrame.lookAt(a, b)
			for d = 0.8, len - 0.4, 2.4 do
				P(m, Vector3.new(4.4, 0.3, 0.8), cf * CFrame.new(0, 0.15, -d), C.darkWood, M.Wood)
			end
			for _, x in ipairs({ -1.5, 1.5 }) do
				P(m, Vector3.new(0.3, 0.3, len), cf * CFrame.new(x, 0.45, -len / 2), C.metal, M.Metal)
			end
			m.Parent = F.decor
			return m
		end

		local function buildCrystals(cf, scale, color)
			local m = newModel("Crystals")
			for i = 1, randInt(4, 7) do
				local sx = rand(0.7, 1.5) * scale
				local sy = rand(2.5, 7) * scale * (i == 1 and 1.5 or 1)
				local foot = cf * CFrame.new(rand(-1.6, 1.6) * scale, 0, rand(-1.6, 1.6) * scale) * CFrame.Angles(rand(-0.3, 0.3), rand(0, 6.28), rand(-0.3, 0.3))
				P(m, Vector3.new(sx, sy, sx), foot * CFrame.new(0, sy / 2 - 0.8, 0), color, M.Neon, { Transparency = 0.15, CanCollide = scale >= 1.5 })
			end
			addLight(marker(m, "Glow", cf * CFrame.new(0, 3 * scale, 0)), 12 + 7 * scale, 1.4, color)
			m.Parent = F.decor
			return m
		end

		local function buildBones(cf)
			local m = newModel("Bones")
			for _ = 1, randInt(3, 6) do
				cyl(m, rand(1.8, 3.2), 0.45, cf * CFrame.new(rand(-3, 3), 0.22, rand(-3, 3)) * CFrame.Angles(0, rand(0, 6.28), 0), C.bone, M.SmoothPlastic, { CanCollide = false })
			end
			if rand(0, 1) < 0.6 then
				P(m, Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(rand(-2, 2), 0.6, rand(-2, 2)), C.bone, M.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false })
			end
			m.Parent = F.decor
			return m
		end

		local function buildScaffold(cf, withBarrel) -- climbable tower: ladder on the front
			local m = newModel("Scaffold")
			local s, H = 10, 20
			for _, x in ipairs({ -s / 2, s / 2 }) do
				for _, z in ipairs({ -s / 2, s / 2 }) do
					P(m, Vector3.new(0.8, H + 3, 0.8), cf * CFrame.new(x, (H + 3) / 2, z), C.wood, M.Wood)
				end
			end
			for _, y in ipairs({ H / 2, H }) do
				P(m, Vector3.new(s + 0.8, 0.6, s + 0.8), cf * CFrame.new(0, y, 0), C.plank, M.WoodPlanks)
			end
			P(m, Vector3.new(s + 0.8, 0.4, 0.4), cf * CFrame.new(0, H + 2.8, s / 2), C.darkWood, M.Wood)
			P(m, Vector3.new(0.4, 0.4, s + 0.8), cf * CFrame.new(-s / 2, H + 2.8, 0), C.darkWood, M.Wood)
			P(m, Vector3.new(0.4, 0.4, s + 0.8), cf * CFrame.new(s / 2, H + 2.8, 0), C.darkWood, M.Wood)
			beam(m, (cf * CFrame.new(-s / 2, 0.5, s / 2)).Position, (cf * CFrame.new(s / 2, H / 2, s / 2)).Position, 0.4, 0.4, C.darkWood, M.Wood)
			beam(m, (cf * CFrame.new(s / 2, H / 2, s / 2)).Position, (cf * CFrame.new(-s / 2, H, s / 2)).Position, 0.4, 0.4, C.darkWood, M.Wood)
			local truss = Instance.new("TrussPart")
			truss.Anchored = true
			truss.Size = Vector3.new(2, H, 2)
			truss.CFrame = cf * CFrame.new(0, H / 2, -s / 2 - 1.4)
			truss.Color = C.darkWood
			truss.Material = M.Wood
			truss.Parent = m
			stats.parts += 1
			if withBarrel then -- a sneaky hiding spot up top, facing inwards so you exit onto the platform
				buildBarrel(cf * CFrame.new(2, H + 0.3, 2) * CFrame.Angles(0, math.pi / 2, 0), m)
			end
			m.Parent = F.structures
			return m
		end

		------------------------------------------------------------------------
		-- Room planner: random spots that keep clear of walls, lanes + each other
		------------------------------------------------------------------------
		local function segDist(p, a, b)
			local ab = b - a
			local len2 = ab:Dot(ab)
			local t = len2 > 0 and math.clamp((p - a):Dot(ab) / len2, 0, 1) or 0
			return (p - (a + ab * t)).Magnitude
		end

		local function clearance(room, p)
			local center = flat(room.pos)
			local d = p - center
			local c = (1 - math.sqrt((d.X / room.rx) ^ 2 + (d.Z / room.rz) ^ 2)) * math.min(room.rx, room.rz)
			for _, e in ipairs(room.entrances) do
				c = math.min(c, segDist(p, center, e) - LANE_HALF)
			end
			for _, b in ipairs(room.blocks) do
				c = math.min(c, (p - b.p).Magnitude - b.r)
			end
			return c
		end

		local function findSpot(room, need, opts)
			opts = opts or {}
			local lo, hi = opts.rhoMin or 0, opts.rhoMax or 0.92
			local bestP, bestC
			for _ = 1, opts.tries or 60 do
				local a = rand(0, math.pi * 2)
				local rr = math.sqrt(rand(lo * lo, hi * hi))
				local p = flat(room.pos) + Vector3.new(math.cos(a) * room.rx * rr, 0, math.sin(a) * room.rz * rr)
				local c = clearance(room, p)
				if c >= need then
					if not opts.best then
						return p, c
					end
					if not bestC or c > bestC then
						bestP, bestC = p, c
					end
				end
			end
			return bestP, bestC
		end

		local function reserve(room, p, r)
			table.insert(room.blocks, { p = p, r = r })
		end

		local function tryPlace(room, need, opts, build)
			local p, c = findSpot(room, need, opts)
			if not p then
				return false
			end
			reserve(room, p, opts.reserve or need)
			build(p, c)
			return true
		end

		-- world CFrame on the room floor at p, looking toward faceTo (default: room center)
		local function placeAt(room, p, faceTo)
			local pos = snapY(W(Vector3.new(p.X, room.pos.Y, p.Z)))
			local dir = flat((faceTo or flat(room.pos)) - p)
			if dir.Magnitude < 0.5 then
				dir = Vector3.new(0, 0, -1)
			end
			return CFrame.lookAt(pos, pos + dir)
		end

		-- How far the rock is from p (on the floor at height floorY) going along dir:
		-- sideways rays at knee, waist and head height (and halfWidth to each side), so
		-- something that fits this gap doesn't poke into a wall that curves in higher up.
		local function wallGap(floorY, p, dir, halfWidth)
			local base = snapY(W(Vector3.new(p.X, floorY, p.Z)))
			local side = Vector3.new(-dir.Z, 0, dir.X) * halfWidth
			local gap = math.huge
			for s = -1, 1 do
				for _, y in ipairs({ 1, 4, 7, 9 }) do
					local from = base + side * s + Vector3.new(0, y, 0)
					local ok, hit = pcall(function()
						return workspace:Raycast(from, dir * 60, rayParams)
					end)
					if not (ok and hit) then
						return nil -- no wall in reach (or the ray started inside rock)
					end
					gap = math.min(gap, (hit.Position - from):Dot(dir))
				end
			end
			return gap
		end

		-- A bank of lockers standing side by side with their backs to the rock and their
		-- doors facing the middle of the room.
		local addLockerBank
		do
			local WIDTH, DEPTH = 3.4, 2.8
			local function free(room, p, r) -- clear of walking lanes and everything already placed
				local center = flat(room.pos)
				for _, e in ipairs(room.entrances) do
					if segDist(p, center, e) < LANE_HALF + r then
						return false
					end
				end
				for _, b in ipairs(room.blocks) do
					if (p - b.p).Magnitude < b.r + r then
						return false
					end
				end
				return true
			end
			function addLockerBank(room, count)
				local center = flat(room.pos)
				for _ = 1, 40 do
					local dir = randDir() -- from the middle of the room out to the wall
					local along = Vector3.new(-dir.Z, 0, dir.X)
					local reach = 1 / math.sqrt((dir.X / room.rx) ^ 2 + (dir.Z / room.rz) ^ 2) -- the room's radius this way
					local spots, gaps, ok = {}, {}, true
					for i = 1, count do
						spots[i] = center + dir * reach * 0.45 + along * (i - (count + 1) / 2) * WIDTH
						gaps[i] = wallGap(room.pos.Y, spots[i], dir, WIDTH / 2 - 0.2)
						ok = ok and gaps[i] ~= nil -- no wall found that way: try another
					end
					for i = 1, ok and count or 0 do
						-- each one is pushed back on its own, so the bank follows the curve of the wall
						local p = spots[i] + dir * ((gaps[i] or 0) - DEPTH / 2 - 0.3) -- back panel just off the rock
						local d = p - center
						local rho = math.sqrt((d.X / room.rx) ^ 2 + (d.Z / room.rz) ^ 2)
						if rho < 0.55 or rho > 1 or not free(room, p, 2) or not free(room, p - dir * 3.5, 2) then
							ok = false
							break
						end
						spots[i] = p
					end
					if ok then
						local color = pick({ C.locker, C.lockerAlt, C.metal })
						for _, p in ipairs(spots) do
							reserve(room, p, 2.2)
							reserve(room, p - dir * 3.5, 2) -- room to get in and out
							buildLocker(placeAt(room, p, p - dir), nil, color)
						end
						return true
					end
				end
				return false
			end
		end

		local function addLanterns(room, n, opts)
			if CONFIG.DARK_CAVE and room.kind ~= "Spawn" then
				return
			end
			for _ = 1, n do
				tryPlace(room, 2.5, { rhoMin = 0.62, rhoMax = 0.88, reserve = 3 }, function(p)
					buildLanternPost(placeAt(room, p), opts)
				end)
			end
		end

		local function addClutter(room, n)
			for _ = 1, n do
				tryPlace(room, 4.5, { rhoMin = 0.3, rhoMax = 0.88 }, function(p)
					buildClutter(placeAt(room, p, p + randDir()))
				end)
			end
		end

		local function addBoulders(room, n, rMin, rMax)
			for _ = 1, n do
				local r = rand(rMin, rMax)
				tryPlace(room, r + 3, { reserve = r + 1 }, function(p)
					Terrain:FillBall(W(Vector3.new(p.X, room.pos.Y + r * 0.2, p.Z)), r, room.wall)
				end)
			end
		end

		local function addStalagmites(room, n)
			for _ = 1, n do
				tryPlace(room, 5.5, {}, function(p)
					local s = rand(0.8, 1.25)
					for _, seg in ipairs({ { 1, 4 }, { 4.5, 3 }, { 7.5, 2.2 } }) do
						Terrain:FillBall(W(Vector3.new(p.X + rand(-0.4, 0.4), room.pos.Y + seg[1] * s, p.Z + rand(-0.4, 0.4))), seg[2] * s, room.wall)
					end
				end)
			end
		end

		local function addPillars(room, n, rMin, rMax)
			for _ = 1, n do
				local r = rand(rMin, rMax)
				tryPlace(room, r * 1.5 + 6, { rhoMax = 0.75, reserve = r * 1.5 + 1 }, function(p)
					local height = room.h + 30
					Terrain:FillCylinder(CFrame.new(W(Vector3.new(p.X, room.pos.Y - 4 + height / 2, p.Z))), height, r, room.wall)
					Terrain:FillBall(W(Vector3.new(p.X, room.pos.Y, p.Z)), r * 1.5, room.wall)
				end)
			end
		end

		local function makePropSpot(room, p, footprint, height, sizeClass, faceTo)
			local s = marker(F.propSpots, sizeClass .. "PropSpot", placeAt(room, p, faceTo) * CFrame.new(0, 0.1, 0), Vector3.new(4, 0.2, 4))
			s:SetAttribute("SpotSize", sizeClass)
			s:SetAttribute("MaxFootprint", math.floor(footprint))
			s:SetAttribute("MaxHeight", math.floor(height))
			s:SetAttribute("Room", room.name)
			CollectionService:AddTag(s, "PropSpot")
			stats.props += 1
			return s
		end

		-- A big open area for a big asset (like your big room). It ignores the walking
		-- lanes (people just walk around it) but keeps a ring clear around it.
		local function addLargeSpot(room)
			local center = flat(room.pos)
			local bestP, bestC
			for _ = 1, 400 do
				local a = rand(0, math.pi * 2)
				local rr = math.sqrt(rand(0, 0.25))
				local p = center + Vector3.new(math.cos(a) * room.rx * rr, 0, math.sin(a) * room.rz * rr)
				local d = p - center
				local c = (1 - math.sqrt((d.X / room.rx) ^ 2 + (d.Z / room.rz) ^ 2)) * math.min(room.rx, room.rz) - 8
				for _, e in ipairs(room.entrances) do
					c = math.min(c, (p - e).Magnitude - 24)
				end
				for _, b in ipairs(room.blocks) do
					c = math.min(c, (p - b.p).Magnitude - b.r)
				end
				c = math.min(c, 0.55 * math.min(room.rx, room.rz))
				if not bestC or c > bestC then
					bestP, bestC = p, c
				end
			end
			if bestC and bestC >= 20 then
				reserve(room, bestP, bestC)
				makePropSpot(room, bestP, bestC * 2, room.h * 0.7, "Large")
			end
		end

		-- floor space saved for YOUR models (PlaceAssets). Rooms call this right
		-- after their main structures, so these get first pick of the free floor.
		local function addPropSpots(room, n)
			for _ = 1, n do
				local p, c = findSpot(room, 4, { tries = 150, best = true })
				if not p then
					return
				end
				local r = math.min(c, 16)
				reserve(room, p, r)
				makePropSpot(room, p, r * 2, math.min(room.h * 0.6, 26), "Small")
			end
		end

		local function addMonsterSpawn(room, c)
			c = c or flat(room.pos)
			reserve(room, c, 7)
			local cf = placeAt(room, c, room.entrances[1] or flat(room.pos))
			local s = marker(F.monster, "MonsterSpawn_" .. room.name, cf * CFrame.new(0, 0.5, 0), Vector3.new(8, 1, 8))
			s:SetAttribute("Room", room.name)
			s:SetAttribute("DistanceFromPlayerSpawn", math.floor((c - flat(ROOM.BaseCamp.pos)).Magnitude))
			CollectionService:AddTag(s, "MonsterSpawn")
			stats.monster += 1
			addLight(marker(F.lights, "LairGlow", cf * CFrame.new(0, 8, 0)), 34, 0.9, C.lair)
		end

		-- the far end of a room, as seen from Base Camp
		local function addFarMonsterSpawn(room)
			local away = flat(room.pos) - flat(ROOM.BaseCamp.pos)
			away = away.Magnitude > 1 and away.Unit or Vector3.new(0, 0, -1)
			addMonsterSpawn(room, flat(room.pos) + Vector3.new(away.X * room.rx, 0, away.Z * room.rz) * 0.6)
		end

		-- walls of planks or stacked crates that block the view across big rooms
		local function buildBarricade(cf, len)
			local m = newModel("Barricade")
			if rand(0, 1) < 0.5 then
				local n = math.max(2, math.floor(len / 4))
				for i = 0, n do
					P(m, Vector3.new(0.7, 8.5, 0.7), cf * CFrame.new(-len / 2 + i * len / n, 4.25, 0), C.darkWood, M.Wood)
				end
				for y = 1, 7.5, 1.3 do
					P(m, Vector3.new(len + 0.6, 1.1, 0.4), cf * CFrame.new(0, y, 0.35) * CFrame.Angles(0, 0, rand(-0.02, 0.02)), pick({ C.wood, C.plank, C.darkWood }), M.WoodPlanks)
				end
			else
				local x = -len / 2
				while x < len / 2 - 2 do
					local s1, s2 = rand(3.2, 4.2), rand(2.8, 3.6)
					P(m, Vector3.new(s1, s1, s1), cf * CFrame.new(x + s1 / 2, s1 / 2, rand(-0.3, 0.3)) * CFrame.Angles(0, rand(-0.15, 0.15), 0), C.crate, M.WoodPlanks)
					P(m, Vector3.new(s2, s2, s2), cf * CFrame.new(x + s1 / 2, s1 + s2 / 2, rand(-0.3, 0.3)) * CFrame.Angles(0, rand(-0.3, 0.3), 0), C.wood, M.WoodPlanks)
					x += s1 + 0.2
				end
			end
			m.Parent = F.structures
			return m
		end

		local function addBarricades(room, n)
			for _ = 1, n do
				local len = rand(12, 22)
				tryPlace(room, len / 2 + 2, { rhoMin = 0.2, rhoMax = 0.85, reserve = len / 2 + 1 }, function(p)
					buildBarricade(placeAt(room, p, p + randDir()), len)
				end)
			end
		end

		-- floating dust that only shows up where light hits it (like your flashlight beam)
		local function addDust(room)
			local box = marker(F.decor, "Dust", CFrame.new(W(room.pos + Vector3.new(0, room.h * 0.4, 0))), Vector3.new(room.rx * 1.6, room.h * 0.6, room.rz * 1.6))
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			e.Rate = math.clamp(room.rx * room.rz / 250, 4, 40)
			e.Lifetime = NumberRange.new(6, 10)
			e.Speed = NumberRange.new(0.1, 0.4)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Drag = 1
			e.Size = NumberSequence.new(0.12)
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 1) })
			e.Color = ColorSequence.new(Color3.fromRGB(255, 236, 200))
			e.LightEmission = 0.1
			e.LightInfluence = 1
			e.Parent = box
		end

		-- The Backrooms: yellow wallpaper maze, damp carpet, a drop ceiling with buzzing
		-- fluorescent panels (some dead, some flickering). Hiding spots + your models go
		-- in the dead ends.
		local function matOr(name, fallback)
			local ok, mat = pcall(function()
				return Enum.Material[name]
			end)
			return ok and mat or fallback
		end
		local WALLPAPER = Color3.fromRGB(196, 178, 108)
		local CARPET = Color3.fromRGB(142, 128, 84)
		local TILES = Color3.fromRGB(214, 204, 160)
		local TUBE = Color3.fromRGB(255, 247, 214)

		local function dressMaze(room)
			local cell, h = room.cell, room.h
			local cols, rows = math.floor(room.rx * 2 / cell), math.floor(room.rz * 2 / cell)
			local x0, z0 = room.pos.X - room.rx, room.pos.Z - room.rz
			local m = newModel("Backrooms")
			local function at(x, y, z)
				return CFrame.new(W(Vector3.new(x, room.pos.Y + y, z)))
			end
			P(m, Vector3.new(room.rx * 2, 0.4, room.rz * 2), at(room.pos.X, -0.15, room.pos.Z), CARPET, matOr("Carpet", M.Fabric))
			P(m, Vector3.new(room.rx * 2, 0.4, room.rz * 2), at(room.pos.X, h - 0.2, room.pos.Z), TILES, matOr("Plaster", M.SmoothPlastic))

			-- V[c][r]: wall between cell (c, r) and (c+1, r).  S[c][r]: wall between (c, r) and (c, r+1)
			local V, S, seen = {}, {}, {}
			for c = 1, cols do
				V[c], S[c], seen[c] = {}, {}, {}
				for r = 1, rows do
					V[c][r], S[c][r] = c < cols, r < rows
				end
			end
			-- carve a maze (depth first), then knock out extra walls so there are loops to run around
			local stack = { { randInt(1, cols), randInt(1, rows) } }
			seen[stack[1][1]][stack[1][2]] = true
			while #stack > 0 do
				local c, r = stack[#stack][1], stack[#stack][2]
				local options = {}
				for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
					local nc, nr = c + d[1], r + d[2]
					if nc >= 1 and nc <= cols and nr >= 1 and nr <= rows and not seen[nc][nr] then
						table.insert(options, { nc, nr })
					end
				end
				if #options == 0 then
					table.remove(stack)
				else
					local n = pick(options)
					if n[1] ~= c then
						V[math.min(c, n[1])][r] = false
					else
						S[c][math.min(r, n[2])] = false
					end
					seen[n[1]][n[2]] = true
					table.insert(stack, n)
				end
			end
			for c = 1, cols do
				for r = 1, rows do
					if V[c][r] and rand(0, 1) < 0.18 then
						V[c][r] = false
					end
					if S[c][r] and rand(0, 1) < 0.18 then
						S[c][r] = false
					end
				end
			end

			-- where the cave tunnels break in: leave the outer wall open there
			local gaps = {}
			for _, t in ipairs(tunnels) do
				if t.roomA == room or t.roomB == room then
					local first, last, step = 1, #t.samples, 1
					if t.roomB == room then
						first, last, step = #t.samples, 1, -1
					end
					for i = first, last, step do
						local d = t.samples[i].pos - room.pos
						if math.abs(d.X) > room.rx or math.abs(d.Z) > room.rz then
							table.insert(gaps, flat(t.samples[i].pos))
							break
						end
					end
				end
			end
			local function nearGap(x, z)
				for _, g in ipairs(gaps) do
					if (Vector3.new(x, 0, z) - g).Magnitude < cell * 0.9 then
						return true
					end
				end
				return false
			end

			local T = 0.8
			local function wall(x, z, sx, sz)
				P(m, Vector3.new(sx, h, sz), at(x, h / 2, z), WALLPAPER, M.Fabric)
			end
			for c = 1, cols do
				for r = 1, rows do
					local cx, cz = x0 + (c - 0.5) * cell, z0 + (r - 0.5) * cell
					if V[c][r] then
						wall(x0 + c * cell, cz, T, cell + T)
					end
					if S[c][r] then
						wall(cx, z0 + r * cell, cell + T, T)
					end
				end
			end
			for c = 1, cols do
				local cx = x0 + (c - 0.5) * cell
				for _, z in ipairs({ z0, z0 + rows * cell }) do
					if not nearGap(cx, z) then
						wall(cx, z, cell + T, T)
					end
				end
			end
			for r = 1, rows do
				local cz = z0 + (r - 0.5) * cell
				for _, x in ipairs({ x0, x0 + cols * cell }) do
					if not nearGap(x, cz) then
						wall(x, cz, T, cell + T)
					end
				end
			end

			-- fluorescent panels in every other cell; some dead, some flickering
			for c = 1, cols, 2 do
				for r = 1, rows, 2 do
					local roll = rand(0, 1)
					local dead = roll < 0.45
					local panel = P(m, Vector3.new(3, 0.15, 1.6), at(x0 + (c - 0.5) * cell, h - 0.47, z0 + (r - 0.5) * cell), dead and Color3.fromRGB(110, 108, 100) or TUBE, dead and M.SmoothPlastic or M.Neon, { CanCollide = false })
					if not dead then
						local light = Instance.new("SurfaceLight")
						light.Face = Enum.NormalId.Bottom
						light.Range = 12
						light.Angle = 100
						light.Brightness = 1.2 * GLOW
						light.Color = Color3.fromRGB(255, 236, 180)
						light.Parent = panel
						stats.lights += 1
						if roll > 0.65 then
							CollectionService:AddTag(light, "Flicker")
						end
					end
				end
			end
			m.Parent = F.structures

			-- dead ends: one in three gets a hiding spot, the rest are saved for your models
			local deadEnds = {}
			for c = 1, cols do
				for r = 1, rows do
					local opens = {}
					if c > 1 and not V[c - 1][r] then
						table.insert(opens, Vector3.new(-1, 0, 0))
					end
					if c < cols and not V[c][r] then
						table.insert(opens, Vector3.new(1, 0, 0))
					end
					if r > 1 and not S[c][r - 1] then
						table.insert(opens, Vector3.new(0, 0, -1))
					end
					if r < rows and not S[c][r] then
						table.insert(opens, Vector3.new(0, 0, 1))
					end
					local p = Vector3.new(x0 + (c - 0.5) * cell, 0, z0 + (r - 0.5) * cell)
					if #opens == 1 and not nearGap(p.X, p.Z) then
						table.insert(deadEnds, { p = p, open = opens[1] })
					end
				end
			end
			for i = #deadEnds, 2, -1 do
				local j = randInt(1, i)
				deadEnds[i], deadEnds[j] = deadEnds[j], deadEnds[i]
			end
			for i, de in ipairs(deadEnds) do
				local p = de.p - de.open * 1.5
				local faceTo = de.p + de.open * 10
				if i % 3 == 1 then
					HIDE_BUILDERS[pick({ "Locker", "Wardrobe", "Crate" })](placeAt(room, p, faceTo))
				else
					makePropSpot(room, p, cell - 4, h - 1, "Small", faceTo)
				end
			end
		end

		------------------------------------------------------------------------
		-- Dress each room
		------------------------------------------------------------------------
		local spawnPart
		local DRESS = {}

		function DRESS.BaseCamp(room)
			local c = flat(room.pos)
			reserve(room, c, 9)
			local spawn = Instance.new("SpawnLocation")
			spawn.Name = "CaveSpawn"
			spawn.Anchored = true
			spawn.Size = Vector3.new(12, 1, 12)
			spawn.CFrame = placeAt(room, c, ROOM.GreatCavern.pos) * CFrame.new(0, 0.5, 0) -- players face the way in
			spawn.Material = M.WoodPlanks
			spawn.Color = C.plank
			spawn.TopSurface = Enum.SurfaceType.Smooth
			spawn.BottomSurface = Enum.SurfaceType.Smooth
			spawn.Duration = 0
			spawn.Neutral = true
			spawn.Parent = F.spawn
			CollectionService:AddTag(spawn, "PlayerSpawn")
			spawnPart = spawn

			tryPlace(room, 8, { rhoMin = 0.3, rhoMax = 0.6, reserve = 9 }, function(p)
				buildCampfire(placeAt(room, p))
			end)
			for _ = 1, 3 do
				tryPlace(room, 6, { rhoMin = 0.45, rhoMax = 0.85 }, function(p)
					buildTent(placeAt(room, p))
				end)
			end
			tryPlace(room, 4.5, { rhoMin = 0.25, rhoMax = 0.5 }, function(p)
				buildSign(placeAt(room, p), "BASE CAMP")
			end)
			addLanterns(room, 4, { full = true })
			addLockerBank(room, 3)
			addPropSpots(room, 6)
			addClutter(room, 2)
		end

		function DRESS.GreatCavern(room)
			addFarMonsterSpawn(room)
			addLargeSpot(room)
			for _ = 1, 2 do
				tryPlace(room, 12, { rhoMin = 0.3, rhoMax = 0.8 }, function(p)
					buildShack(placeAt(room, p))
				end)
			end
			tryPlace(room, 10, { rhoMin = 0.35, rhoMax = 0.8 }, function(p)
				buildScaffold(placeAt(room, p), true)
			end)
			for _, n in ipairs({ 3, 3, 2, 2 }) do
				addLockerBank(room, n)
			end
			addPillars(room, 3, 6, 9)
			addBarricades(room, 4)
			addPropSpots(room, 22)
			addBoulders(room, 3, 4, 7)
			addStalagmites(room, 6)
			addLanterns(room, 7)
		end

		function DRESS.OldMine(room)
			addFarMonsterSpawn(room)
			local c = flat(room.pos)
			local e = room.entrances[1]
			if e then -- an old rail line running out of one of the exits
				buildRails(snapY(W(Vector3.new(c.X, room.pos.Y, c.Z))), snapY(W(Vector3.new(e.X, room.pos.Y, e.Z))))
			end
			for _ = 1, 2 do -- abandoned carts on short bits of track
				tryPlace(room, 8, { rhoMin = 0.3, rhoMax = 0.8 }, function(p)
					local cf = placeAt(room, p, p + randDir())
					buildRails((cf * CFrame.new(0, 0, 7)).Position, (cf * CFrame.new(0, 0, -7)).Position)
					buildMinecart(cf * CFrame.new(0, 0, rand(-3, 3)))
				end)
			end
			for _, n in ipairs({ 3, 3, 2 }) do -- the miners' lockers
				addLockerBank(room, n)
			end
			for _ = 1, 5 do
				tryPlace(room, 6.5, { rhoMin = 0.68, rhoMax = 0.86 }, function(p)
					buildMineSupport(placeAt(room, p))
				end)
			end
			addBarricades(room, 2)
			addPropSpots(room, 12)
			addLanterns(room, 2)
		end

		function DRESS.CrystalGrotto(room)
			addFarMonsterSpawn(room)
			for _ = 1, 3 do
				tryPlace(room, 8, { rhoMax = 0.85, reserve = 9 }, function(p)
					buildCrystals(placeAt(room, p, p + randDir()), rand(1.6, 2.2), pick({ C.crystalA, C.crystalB }))
				end)
			end
			addLockerBank(room, 2)
			addLockerBank(room, 2)
			addBarricades(room, 1)
			addPropSpots(room, 12)
			for _ = 1, 8 do
				tryPlace(room, 3.5, { reserve = 4.5 }, function(p)
					buildCrystals(placeAt(room, p, p + randDir()), rand(0.6, 1.1), pick({ C.crystalA, C.crystalB }))
				end)
			end
			addBoulders(room, 2, 4, 6)
			addLanterns(room, 2)
		end

		local function dressLair(room)
			addMonsterSpawn(room)
			for _ = 1, 5 do
				tryPlace(room, 3.5, { rhoMin = 0.3, rhoMax = 0.85, reserve = 5 }, function(p)
					buildBones(placeAt(room, p, p + randDir()))
				end)
			end
			addStalagmites(room, 3)
		end

		local nookCount = 0
		local function dressNook(nook)
			local mouth = nook.entrances[1]
			local c = flat(nook.pos)
			local back = (c - mouth).Unit
			nookCount += 1
			if nookCount % 2 == 0 then
				makePropSpot(nook, c + back * 3, 12, 12, "Small", mouth)
			else
				HIDE_BUILDERS[pick(HIDE_KINDS)](placeAt(nook, c + back * 3, mouth))
				makePropSpot(nook, c + Vector3.new(-back.Z, 0, back.X) * 6 - back, 8, 12, "Small", mouth)
			end
			if rand(0, 1) < 0.35 and not CONFIG.DARK_CAVE then
				local side = Vector3.new(-back.Z, 0, back.X) * 6
				buildLanternPost(placeAt(nook, c + side - back * 2), { brightness = 0.7, range = 16 })
			end
		end

		-- if something in one room breaks, keep building the rest and report it at the end
		local problems = {}
		for _, room in ipairs(rooms) do
			local ok, err = pcall(function()
				if room.kind == "Lair" then
					dressLair(room)
				elseif room.kind == "Nook" then
					dressNook(room)
				elseif room.kind == "Maze" then
					dressMaze(room)
				elseif DRESS[room.name] then
					DRESS[room.name](room)
				end
				if room.kind ~= "Nook" and room.kind ~= "Lair" then
					addDust(room)
				end
			end)
			if not ok then
				table.insert(problems, room.name .. ": " .. tostring(err))
			end
		end

		-- spots for your props along the tunnels, alternating sides, clear of rooms and nook entrances
		pcall(function()
			for _, t in ipairs(tunnels) do
				if t.kind == "Tunnel" then
					local nextAt, side = 25, 1
					for i = 2, #t.samples - 1 do
						local s = t.samples[i]
						if s.s >= nextAt then
							nextAt = s.s + 40
							local nearNook = false
							for _, nook in ipairs(nooks) do
								if (flat(s.pos) - nook.entrances[1]).Magnitude < 22 then
									nearNook = true
								end
							end
							if not nearNook and not insideAnyRoom(s.pos, 1.25) then
								-- against one wall, sized to the real width there (tunnels are round, so
								-- the walls lean in) and leaving the middle free to walk through
								local tan = flat(t.samples[i + 1].pos - t.samples[i - 1].pos).Unit
								local out = Vector3.new(-tan.Z, 0, tan.X) * side
								local gap = wallGap(s.pos.Y, flat(s.pos), out, 3)
								local r = gap and math.min(4.5, (gap - 1.5) / 2)
								if r and r >= 2.5 then
									local p = flat(s.pos) + out * (gap - 0.5 - r)
									local spotRoom = { name = t.name, pos = Vector3.new(p.X, s.pos.Y, p.Z) }
									makePropSpot(spotRoom, p, 2 * r, 9, "Small", flat(s.pos))
								end
								side = -side
							end
						end
					end
				end
			end
		end)

		-- lanterns along the tunnels, alternating sides
		local lanternsOk, lanternErr = pcall(function()
			for _, t in ipairs(tunnels) do
				if t.lightEvery and not CONFIG.DARK_CAVE then
					local nextAt, side = t.lightEvery * 0.6, 1
					for i = 2, #t.samples - 1 do
						local s = t.samples[i]
						if s.s >= nextAt then
							nextAt = s.s + t.lightEvery
							if not insideAnyRoom(s.pos, 1.1) then
								local tan = flat(t.samples[i + 1].pos - t.samples[i - 1].pos).Unit
								local p = s.pos + Vector3.new(-tan.Z, 0, tan.X) * side * s.r * 0.6
								local pos = snapY(W(p))
								buildLanternPost(CFrame.lookAt(pos, Vector3.new(O.X + s.pos.X, pos.Y, O.Z + s.pos.Z)), t.lightOpts)
								side = -side
							end
						end
					end
				end
			end
		end)
		if not lanternsOk then
			table.insert(problems, "tunnel lanterns: " .. tostring(lanternErr))
		end

		-- invisible room volumes (handy later for "you are in the Old Mine" UI, round logic, etc.)
		for _, room in ipairs(rooms) do
			local box = marker(F.rooms, room.name, CFrame.new(W(room.pos + Vector3.new(0, room.h / 2, 0))), Vector3.new(room.rx * 2, room.h, room.rz * 2))
			box:SetAttribute("RoomKind", room.kind)
			CollectionService:AddTag(box, "CaveRoom")
		end

		------------------------------------------------------------------------
		-- Finish up
		------------------------------------------------------------------------
		-- Anything of yours in Workspace that the new rock now buries (say you placed it in a
		-- tunnel that's gone after a rebuild) is moved onto the top of the rock.
		local function buried(pos)
			local ok, mats, occ = pcall(function()
				local corner = Vector3.new(math.floor(pos.X / 4) * 4, math.floor(pos.Y / 4) * 4, math.floor(pos.Z / 4) * 4)
				return Terrain:ReadVoxels(Region3.new(corner, corner + Vector3.new(4, 4, 4)), 4)
			end)
			return ok and mats[1][1][1] ~= AIR and mats[1][1][1] ~= M.Water and occ[1][1][1] > 0.5
		end
		local unburied = {}
		local function rescue(inst)
			if inst == root or inst:IsA("Terrain") or inst:IsA("Camera") or inst.Name == "Baseplate" then
				return
			end
			if inst:IsA("Folder") then
				for _, c in ipairs(inst:GetChildren()) do
					rescue(c)
				end
				return
			end
			if not (inst:IsA("Model") or inst:IsA("BasePart")) then
				return
			end
			local lo, hi = boxOf(inst)
			local mid = (lo + hi) / 2
			if lo.X ~= math.huge and math.abs(mid.X - O.X) < HALF and math.abs(mid.Z - O.Z) < HALF and mid.Y > rockLo.Y and mid.Y < rockHi.Y and buried(mid) then
				inst:PivotTo(inst:GetPivot() + Vector3.new(0, rockHi.Y - lo.Y + 0.05, 0))
				table.insert(unburied, inst.Name)
			end
		end
		for _, c in ipairs(workspace:GetChildren()) do
			rescue(c)
		end

		local disabled = {}
		if CONFIG.DISABLE_OTHER_SPAWNS then
			for _, d in ipairs(workspace:GetDescendants()) do
				if d:IsA("SpawnLocation") and d.Enabled then
					d.Enabled = false
					table.insert(disabled, d:GetFullName())
				end
			end
		end

		-- GameScripts' client script uses this box to know when a player is inside the cave
		root:SetAttribute("BoxCenter", W(Vector3.new(0, (ROCK_TOP + ROCK_BOTTOM) / 2, 0)))
		root:SetAttribute("BoxSize", Vector3.new(HALF * 2, ROCK_TOP - ROCK_BOTTOM, HALF * 2))

		root.Parent = workspace

		if CONFIG.MOVE_CAMERA and spawnPart then
			local cam = workspace.CurrentCamera
			local sp = spawnPart.Position
			cam.CFrame = CFrame.lookAt(sp + Vector3.new(0, 14, 26), sp + Vector3.new(0, 3, -20))
			cam.Focus = CFrame.new(sp)
		end

		pcall(function()
			ChangeHistoryService:SetWaypoint("CaveBuilder")
		end)

		print(string.format(
			"[CaveBuilder] Done in %.1fs: %d rooms, %d tunnels, %d nooks, %d hiding spots, %d monster spawns, %d prop spots, %d lights, %d parts.",
			os.clock() - startTime, #ROOMS, #TUNNELS, #nooks, stats.hiding, stats.monster, stats.props, stats.lights, stats.parts
		))
		print("[CaveBuilder] The cave is the big block of rock in the middle of your Baseplate. The camera is now inside it at Base Camp. Press Play to walk around.")
		if #unburied > 0 then
			print("[CaveBuilder] These were inside the new rock, so they're now on top of it: " .. table.concat(unburied, ", "))
		end
		if #liftedNames > 0 then
			print("[CaveBuilder] Lifted these onto the top of the rock so they weren't buried: " .. table.concat(liftedNames, ", "))
		end
		if #disabled > 0 then
			print("[CaveBuilder] Disabled other SpawnLocations so you spawn in the cave: " .. table.concat(disabled, ", "))
		end
		if #problems > 0 then
			warn("[CaveBuilder] The cave is built, but some decorations didn't work. Copy this message and send it to Claude:\n" .. table.concat(problems, "\n"))
		end
		return true
	end

	print("[CaveBuilder] Building the cave. Studio will freeze for 10-30 seconds, that's normal...")
	local ok, result = xpcall(build, debug.traceback)
	if not ok then
		warn("[CaveBuilder] Something went wrong, so the cave wasn't finished. Copy this whole message and send it to Claude:\n" .. tostring(result))
		return false
	end
	return result
end

-- Loaded as a ModuleScript (the GitHub one-liner): hand back run so options can be passed.
-- Pasted straight into the Command Bar: just run it.
if script then
	return run
end
return run()
