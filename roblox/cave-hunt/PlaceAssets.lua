--[[
	==================================================================
	 CAVE HUNT  -  Place your own assets into the cave  (v1)
	==================================================================
	Copies your models onto the PropSpot markers that CaveBuilder left
	around the cave. Run CaveBuilder first.

	YOUR MODELS: the first time it runs, it picks up the models sitting in
	your Workspace (and in folders there) and moves them into
	ServerStorage.CaveAssets, sorted into
	  Hiding = names like Closet, Hiding Spot, Locker, Minecart, Crate,
	           Shelf, Container (or a folder named like that). Unnamed
	           models count if they're 5+ studs tall and under 30 across.
	  Decor  = names like Light, Crystal, Fire, Lamp, plus everything
	           else, including big things like your big room
	It leaves alone: the Baseplate, SpawnLocations, the CaveSystem, and
	anything with a Humanoid or "monster" in its name (your monster).
	Copies of the models in those folders are what get put in the cave.

	If it guessed wrong, drag the model to the other folder and run again.
	Add new models later by dragging them into those folders.
	Optional attributes on a model:
	  Count    (number) how many copies to place (default up to 6 hiding /
	           4 decor / 1 for anything bigger than 30 studs)
	  CaveRole (string) "Hiding", "Decor" or "Skip" (leave it in Workspace)

	RUN: use the one-line Command Bar command in README.md (or paste
	this whole file into the Command Bar). Run it again any time to
	reshuffle. Only the Workspace.CaveSystem.PlacedAssets folder is
	replaced, so your other edits in the cave are kept.

	Things in Hiding get the "HidingSpot" tag plus HidePoint/ExitPoint
	parts (unless they already have them), same as the built-in ones.
]]

-- Settings. Override any of them from the Command Bar, e.g. require(M)({ SEED = 5 })
local DEFAULTS = {
	SEED = false, -- false = a new arrangement every run. Put a number to get the same one each time
	HIDING_COPIES = 6,
	DECOR_COPIES = 4,
	BIG = 30, -- studs across; anything bigger is placed once unless it has a Count attribute
	COLLECT_FROM_WORKSPACE = "auto", -- "auto" = only the first time (before CaveAssets exists); true = always; false = never
	ASSET_LIGHT_SCALE = 0.35, -- lights inside your models are dimmed to this much in the cave (1 = as bright as you made them)
}

local function run(options)
	local CONFIG = table.clone(DEFAULTS)
	for k, v in pairs(options or {}) do
		if DEFAULTS[k] == nil then
			warn("[PlaceAssets] Unknown option: " .. tostring(k))
		end
		CONFIG[k] = v
	end

	local function place()
		local CollectionService = game:GetService("CollectionService")
		local ServerStorage = game:GetService("ServerStorage")

		local cave = workspace:FindFirstChild("CaveSystem")
		local spotFolder = cave and cave:FindFirstChild("PropSpots")
		if not spotFolder then
			warn("[PlaceAssets] Workspace.CaveSystem.PropSpots not found. Run CaveBuilder first.")
			return false
		end
		local rng = CONFIG.SEED and Random.new(CONFIG.SEED) or Random.new()

		local function partsOf(inst)
			local list = {}
			if inst:IsA("BasePart") then
				table.insert(list, inst)
			end
			for _, d in ipairs(inst:GetDescendants()) do
				if d:IsA("BasePart") then
					table.insert(list, d)
				end
			end
			return list
		end

		-- world-space box around its parts (works for any pivot/orientation). visibleOnly skips
		-- invisible helper parts (hitboxes, roots) so they can't push the model into the floor
		local function bounds(inst, visibleOnly)
			local lo = Vector3.new(math.huge, math.huge, math.huge)
			local hi = -lo
			local list = partsOf(inst)
			if visibleOnly then
				local seen = {}
				for _, p in ipairs(list) do
					if p.Transparency < 0.99 then
						table.insert(seen, p)
					end
				end
				if #seen > 0 then
					list = seen
				end
			end
			for _, p in ipairs(list) do
				local h = p.Size / 2
				for _, sx in ipairs({ -1, 1 }) do
					for _, sy in ipairs({ -1, 1 }) do
						for _, sz in ipairs({ -1, 1 }) do
							local c = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
							lo = Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
							hi = Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
						end
					end
				end
			end
			return lo, hi
		end

		-- widest the model can be at any rotation (the diagonal of its tightest box
		-- seen from above). Measured per model so a rotated model isn't over-sized.
		-- Also returns that box's length and depth and the direction of its long side.
		local function footprintOf(inst)
			local corners = {}
			for _, p in ipairs(partsOf(inst)) do
				local h = p.Size / 2
				for _, sx in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						for _, sy in ipairs({ -1, 1 }) do
							table.insert(corners, p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
						end
					end
				end
			end
			local best, length, depth, axis = math.huge, 0, 0, Vector3.new(1, 0, 0)
			for step = 0, 11 do
				local a = step * math.pi / 12
				local ca, sa = math.cos(a), math.sin(a)
				local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
				for _, c in ipairs(corners) do
					local x, z = c.X * ca - c.Z * sa, c.X * sa + c.Z * ca
					x0, x1, z0, z1 = math.min(x0, x), math.max(x1, x), math.min(z0, z), math.max(z1, z)
				end
				local diagonal = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
				if diagonal < best then
					best = diagonal
					length, depth = math.max(x1 - x0, z1 - z0), math.min(x1 - x0, z1 - z0)
					axis = (x1 - x0 >= z1 - z0) and Vector3.new(ca, 0, -sa) or Vector3.new(sa, 0, ca)
				end
			end
			return best, length, depth, axis
		end

		local function yawOf(look) -- heading angle of a look vector
			return math.atan2(-look.X, -look.Z)
		end

		-- the template library: ServerStorage.CaveAssets/Hiding + /Decor
		local source = ServerStorage:FindFirstChild("CaveAssets") or workspace:FindFirstChild("CaveAssets")
		local collectNow = CONFIG.COLLECT_FROM_WORKSPACE
		if collectNow == "auto" then
			collectNow = source == nil
		end
		if not source then
			source = Instance.new("Folder")
			source.Name = "CaveAssets"
			source.Parent = ServerStorage
		end
		local function folderFor(role)
			local f = source:FindFirstChild(role)
			if not f then
				f = Instance.new("Folder")
				f.Name = role
				f.Parent = source
			end
			return f
		end
		folderFor("Hiding")
		folderFor("Decor")

		-- a model's (or its folder's) name usually says what it is
		local HIDE_WORDS = { "hid", "closet", "locker", "wardrobe", "cabinet", "cart", "barrel", "crate", "container", "shelf", "shelves", "fridge", "dumpster" }
		local DECOR_WORDS = { "light", "lamp", "torch", "lantern", "crystal", "fire", "decor", "sign", "plant" }
		local function roleFromName(name)
			name = name:lower()
			for _, w in ipairs(HIDE_WORDS) do
				if name:find(w, 1, true) then
					return "Hiding"
				end
			end
			for _, w in ipairs(DECOR_WORDS) do
				if name:find(w, 1, true) then
					return "Decor"
				end
			end
			return nil
		end

		-- pick up the models already sitting in Workspace
		if collectNow then
			local found = {}
			local function consider(inst, folderRole)
				if inst == cave or inst:IsA("Terrain") or inst:IsA("Camera") or inst:IsA("SpawnLocation") or inst.Name == "Baseplate" then
					return
				end
				if inst:IsA("Folder") then
					if inst.Name ~= "CaveAssets" then
						for _, c in ipairs(inst:GetChildren()) do
							consider(c, roleFromName(inst.Name) or folderRole)
						end
					end
				elseif inst:IsA("Model") or inst:IsA("BasePart") then
					table.insert(found, { inst = inst, folderRole = folderRole })
				end
			end
			for _, c in ipairs(workspace:GetChildren()) do
				consider(c, nil)
			end

			local moved, leftAlone = { Hiding = {}, Decor = {} }, {}
			for _, entry in ipairs(found) do
				local inst = entry.inst
				local role = inst:GetAttribute("CaveRole")
				local lo, hi = bounds(inst)
				local size = hi - lo
				local why
				if role == "Skip" then
					why = "CaveRole is Skip"
				elseif inst:FindFirstChildWhichIsA("Humanoid", true) or inst:FindFirstChildWhichIsA("AnimationController", true) or inst.Name:lower():find("monster") then
					why = "looks like a character or your monster"
				elseif lo.X == math.huge then
					why = "has no parts"
				elseif inst:IsA("BasePart") and size.Y < 1 then
					why = "flat part"
				elseif math.max(size.X, size.Z) > 400 then
					why = "too big for the cave"
				end
				if why then
					table.insert(leftAlone, inst.Name .. " (" .. why .. ")")
				else
					if role ~= "Hiding" and role ~= "Decor" then
						-- its name, then its folder's name, then its size (tall enough to stand in, not huge)
						role = roleFromName(inst.Name) or entry.folderRole or ((footprintOf(inst) <= CONFIG.BIG and size.Y >= 5) and "Hiding" or "Decor")
					end
					if inst:GetAttribute("FloorOffset") == nil then
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						params.FilterDescendantsInstances = { inst }
						local hit = workspace:Raycast(Vector3.new((lo.X + hi.X) / 2, hi.Y + 1, (lo.Z + hi.Z) / 2), Vector3.new(0, -(size.Y + 60), 0), params)
						if hit then
							inst:SetAttribute("FloorOffset", inst:GetPivot().Y - hit.Position.Y)
						end
					end
					inst.Parent = folderFor(role)
					table.insert(moved[role], inst.Name)
				end
			end
			print("[PlaceAssets] Moved your models from Workspace into ServerStorage.CaveAssets:")
			print("    Hiding: " .. (#moved.Hiding > 0 and table.concat(moved.Hiding, ", ") or "(none)"))
			print("    Decor:  " .. (#moved.Decor > 0 and table.concat(moved.Decor, ", ") or "(none)"))
			if #leftAlone > 0 then
				print("    Left in Workspace: " .. table.concat(leftAlone, ", "))
			end
			print("    Wrong folder? Drag it to the other one in ServerStorage.CaveAssets and run this again.")
		end

		-- How high a model's pivot sat above the ground it stood on (measured when it was picked
		-- up from Workspace). Used to lift a model a little when a mesh sticks out below its part.
		local function floorOffsetOf(asset)
			local v = asset:GetAttribute("FloorOffset")
			return type(v) == "number" and v or nil
		end

		-- what to place. Models with the same name count as one design (your 6 Closets are
		-- 6 copies of a closet, not 6 designs x 3 copies each).
		local jobs, skippedEmpty, skippedPieces = {}, {}, {}
		-- loose building pieces picked up from Workspace (a "Ceiling" or a plain "Part"), not props
		local PIECES = { part = true, ceiling = true, floor = true, wall = true, roof = true, baseplate = true }
		local function collect(folder, hiding)
			if not folder then
				return
			end
			local groups, order = {}, {}
			for _, asset in ipairs(folder:GetChildren()) do
				if (asset:IsA("Model") or asset:IsA("BasePart")) and PIECES[asset.Name:lower()] then
					skippedPieces[asset.Name] = (skippedPieces[asset.Name] or 0) + 1
				elseif asset:IsA("Model") or asset:IsA("BasePart") then
					local lo, hi = bounds(asset)
					if lo.X == math.huge then
						table.insert(skippedEmpty, asset.Name)
					else
						if not groups[asset.Name] then
							groups[asset.Name] = {}
							table.insert(order, asset.Name)
						end
						local footprint, length, depth, axis = footprintOf(asset)
						-- the long side's front: the side the model's own front (its pivot) is on
						local front = Vector3.new(-axis.Z, 0, axis.X)
						if front:Dot(asset:GetPivot().LookVector) < 0 then
							front = -front
						end
						table.insert(groups[asset.Name], {
							asset = asset, footprint = footprint, height = (hi - lo).Y, offset = floorOffsetOf(asset),
							long = length >= 8 and length >= depth * 2, length = length, depth = depth, front = front,
						})
					end
				end
			end
			for _, name in ipairs(order) do
				local group = groups[name]
				table.sort(group, function(a, b)
					return a.footprint > b.footprint
				end)
				local count = group[1].asset:GetAttribute("Count")
				if type(count) ~= "number" then
					local default = hiding and CONFIG.HIDING_COPIES or CONFIG.DECOR_COPIES
					if group[1].footprint > CONFIG.BIG then
						default = 1
					end
					count = math.max(#group, default)
				end
				for copy = 1, count do
					local t = group[(copy - 1) % #group + 1]
					-- "copy" = how many times this particular model has come up, so every model gets its first one in
					table.insert(jobs, {
						asset = t.asset, name = name, hiding = hiding, footprint = t.footprint, height = t.height, offset = t.offset,
						long = t.long, length = t.length, depth = t.depth, front = t.front,
						copy = math.floor((copy - 1) / #group) + 1,
					})
				end
			end
		end
		collect(source:FindFirstChild("Hiding"), true)
		collect(source:FindFirstChild("Decor"), false)
		collect(source, false) -- models dropped straight into CaveAssets count as decor

		if #jobs == 0 then
			warn("[PlaceAssets] No models to place. Put models in ServerStorage.CaveAssets.Hiding / Decor, or run with require(M)({ COLLECT_FROM_WORKSPACE = true }) to pick them up from Workspace.")
			return false
		end

		-- where it can go
		local spots, strips, biggest = {}, {}, 0
		for _, s in ipairs(spotFolder:GetChildren()) do
			if s:IsA("BasePart") and s:GetAttribute("SpotSize") == "Wall" then
				-- a strip of floor along a wall, for long models (shelf rows): they stand in a line, backs to the rock
				local floor = s.CFrame * CFrame.new(0, -s.Size.Y / 2, 0)
				local look = floor.LookVector
				table.insert(strips, {
					pos = floor.Position,
					look = look, -- toward the middle of the room
					along = Vector3.new(-look.Z, 0, look.X),
					length = s:GetAttribute("MaxLength") or 20,
					depth = s:GetAttribute("MaxDepth") or 6,
					height = s:GetAttribute("MaxHeight") or 14,
					used = 0,
				})
			elseif s:IsA("BasePart") then
				local floor = s.CFrame * CFrame.new(0, -s.Size.Y / 2, 0)
				local spot = {
					pos = floor.Position,
					look = floor.LookVector, -- toward the middle of the room
					footprint = s:GetAttribute("MaxFootprint") or 10,
					height = s:GetAttribute("MaxHeight") or 15,
				}
				biggest = math.max(biggest, spot.footprint)
				table.insert(spots, spot)
			end
		end

		local old = cave:FindFirstChild("PlacedAssets")
		if old then
			old:Destroy()
		end
		local out = Instance.new("Folder")
		out.Name = "PlacedAssets"
		out.Parent = cave

		-- one copy of every model before any repeats, biggest first so they get the big spots.
		-- Repeats of hiding models go before repeats of decoration.
		table.sort(jobs, function(a, b)
			if a.copy ~= b.copy then
				return a.copy < b.copy
			end
			if a.copy > 1 and a.hiding ~= b.hiding then
				return a.hiding
			end
			return a.footprint > b.footprint
		end)

		local placed, failed, errors, placedAsset = {}, {}, {}, {}
		local againstWall = 0

		-- Studio may not have applied the new cave's terrain yet when this runs straight after
		-- CaveBuilder (in a live editing session terrain edits are queued), so floor rays could see
		-- the old terrain. Only use them if they agree with the floor height of the spots.
		local floorRays = RaycastParams.new()
		floorRays.FilterType = Enum.RaycastFilterType.Include
		floorRays.FilterDescendantsInstances = { workspace.Terrain }
		local probes = {} -- a few spot floors to test the rays against
		for i, spot in ipairs(spots) do
			if i <= 12 then
				table.insert(probes, spot.pos)
			end
		end
		local function raysAgree()
			local agree = 0
			for _, pos in ipairs(probes) do
				local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), floorRays)
				if hit and math.abs(hit.Position.Y - pos.Y) < 1 then
					agree += 1
				end
			end
			return #probes > 0 and agree >= #probes * 0.6
		end
		local raysWork = raysAgree()
		local placedModels = {}
		for _, job in ipairs(jobs) do
			local ok, err = pcall(function()
				-- free spots it fits in, preferring snug ones so the big spots stay free for big models
				local fits, snug = {}, math.huge
				for _, s in ipairs(spots) do
					if job.footprint <= s.footprint and job.height <= s.height then
						table.insert(fits, s)
						snug = math.min(snug, s.footprint)
					end
				end
				local choices = {}
				for _, s in ipairs(fits) do
					if s.footprint <= snug * 1.6 + 4 then
						table.insert(choices, s)
					end
				end
				-- long models (shelf rows) go along a wall if there's room on a strip
				local strip
				if job.long then
					for _, st in ipairs(strips) do
						if st.length - st.used >= job.length and job.depth <= st.depth and job.height <= st.height then
							strip = st
							break
						end
					end
				end
				if #choices == 0 and not strip then
					failed[job.name] = failed[job.name] or { job = job, n = 0 }
					failed[job.name].n += 1
				else
					local spot = strip or choices[rng:NextInteger(1, #choices)]
					local at, look = spot.pos, spot.look
					local middle, tucked = spot.pos, nil
					if strip then
						-- next free stretch of the strip, pushed back against the rock
						at = strip.pos + strip.along * (-strip.length / 2 + strip.used + job.length / 2) - strip.look * ((strip.depth - job.depth) / 2)
						strip.used += job.length + 1
						againstWall += 1
					elseif spot.footprint >= job.footprint * 2 then
						-- small model in a big spot: tuck it against the wall side of the spot and
						-- keep the rest of the spot free for more models
						local a = rng:NextNumber(-0.9, 0.9)
						local back = -look
						back = Vector3.new(back.X * math.cos(a) - back.Z * math.sin(a), 0, back.X * math.sin(a) + back.Z * math.cos(a))
						tucked = back * ((spot.footprint - job.footprint) / 2)
						at = spot.pos + tucked
						spot.pos = spot.pos - back * ((job.footprint + 1) / 2)
						spot.footprint -= job.footprint + 1
					else
						spot.footprint = 0 -- used up
					end

					local clone = job.asset:Clone()
					if clone:IsA("BasePart") then -- wrap loose parts so they can hold HidePoint/ExitPoint
						local m = Instance.new("Model")
						m.Name = clone.Name
						clone.Parent = m
						m.PrimaryPart = clone
						clone = m
					end
					for _, p in ipairs(partsOf(clone)) do
						p.Anchored = true
					end
					for _, d in ipairs(clone:GetDescendants()) do
						if d:IsA("Light") then
							d.Brightness *= CONFIG.ASSET_LIGHT_SCALE
						end
					end

					-- turn it (around world Y only, so it stays upright) so its front faces the
					-- middle of the room for hiding props, or a random way for decor
					-- (along a wall: its long side against the rock and its front facing the room)
					local pivot = clone:GetPivot()
					local wantYaw = (job.hiding or strip) and yawOf(look) or rng:NextNumber(0, math.pi * 2)
					local front = strip and job.front or pivot.LookVector
					local turn = CFrame.Angles(0, wantYaw - yawOf(front), 0) * pivot.Rotation

					-- then slide it over the spot and find the highest bit of floor under it.
					-- `flat` is false if the floor under it rises or drops more than a stud
					-- (it's on the slope up to a wall) or there's rock right above it
					local function settle(pos)
						clone:PivotTo(CFrame.new(pos) * turn)
						local lo, hi = bounds(clone, true)
						local center = (lo + hi) / 2
						clone:PivotTo(clone:GetPivot() + Vector3.new(pos.X - center.X, 0, pos.Z - center.Z))
						lo, hi = bounds(clone, true)
						local floorY, flat = pos.Y, true
						for _, xz in ipairs(raysWork and { { 0.5, 0.5 }, { 0.1, 0.1 }, { 0.9, 0.1 }, { 0.1, 0.9 }, { 0.9, 0.9 } } or {}) do
							local x = lo.X + (hi.X - lo.X) * xz[1]
							local z = lo.Z + (hi.Z - lo.Z) * xz[2]
							local hit = workspace:Raycast(Vector3.new(x, pos.Y + 12, z), Vector3.new(0, -24, 0), floorRays)
							if hit and math.abs(hit.Position.Y - pos.Y) < 4 then
								floorY = math.max(floorY, hit.Position.Y)
							end
							flat = flat and hit ~= nil and math.abs(hit.Position.Y - pos.Y) <= 1
						end
						return lo, floorY, flat
					end
					local lo, floorY, flat = settle(at)
					if tucked and not flat then
						-- tucked up the slope to a wall: slide it back toward the middle of the spot
						for _, t in ipairs({ 0.66, 0.33, 0 }) do
							at = middle + tucked * t
							lo, floorY, flat = settle(at)
							if flat then
								break
							end
						end
						spot.footprint = 0 -- it may now cover the rest of the spot
					end

					-- and stand its visible bottom on the highest bit of floor under it, so no
					-- part of it is ever below the floor
					local lift = floorY - lo.Y + 0.02
					if job.offset then -- a mesh that hung below its part on your Baseplate: keep that gap (a few studs at most)
						local pivotLift = (at.Y + job.offset) - clone:GetPivot().Y
						if pivotLift > lift and pivotLift < lift + 3 then
							lift = pivotLift
						end
					end
					clone:PivotTo(clone:GetPivot() + Vector3.new(0, lift, 0))

					if job.hiding then
						local hi
						lo, hi = bounds(clone)
						local function addPoint(name, pos)
							if not clone:FindFirstChild(name, true) then
								local p = Instance.new("Part")
								p.Name = name
								p.Anchored = true
								p.CanCollide = false
								p.CanQuery = false
								p.CanTouch = false
								p.CastShadow = false
								p.Transparency = 1
								p.Size = Vector3.new(1, 1, 1)
								p.CFrame = CFrame.lookAt(pos, pos + look)
								p.Parent = clone
							end
						end
						local mid = (lo + hi) / 2
						local halfDepth = math.max(hi.X - lo.X, hi.Z - lo.Z) / 2
						addPoint("HidePoint", Vector3.new(mid.X, math.min(lo.Y + 3, mid.Y), mid.Z))
						addPoint("ExitPoint", Vector3.new(mid.X, lo.Y + 3, mid.Z) + look * (halfDepth + 3))
						if clone:GetAttribute("HideType") == nil then
							clone:SetAttribute("HideType", job.asset.Name)
						end
						clone:SetAttribute("Occupied", false)
						CollectionService:AddTag(clone, "HidingSpot")
					end
					clone.Parent = out
					table.insert(placedModels, clone)
					placed[job.name] = (placed[job.name] or 0) + 1
					placedAsset[job.asset] = true
				end
			end)
			if not ok then
				table.insert(errors, job.name .. ": " .. tostring(err))
			end
		end

		local total, names = 0, {}
		for name, count in pairs(placed) do
			total += count
			table.insert(names, ("%s x%d"):format(name, count))
		end
		table.sort(names)
		print(("[PlaceAssets] Put %d of your models in the cave: %s"):format(total, table.concat(names, ", ")))
		if againstWall > 0 then
			print(("[PlaceAssets] %d long models (like shelf rows) stand along the walls."):format(againstWall))
		end
		local skipped = 0
		for _, f in pairs(failed) do
			skipped += f.n
		end
		local missing, seen = {}, {}
		for _, job in ipairs(jobs) do
			if not placedAsset[job.asset] and not seen[job.asset] then
				seen[job.asset] = true
				table.insert(missing, ("%s (%d studs across)"):format(job.name, job.footprint))
			end
		end
		if #missing > 0 then
			warn(("[PlaceAssets] These didn't fit anywhere (the biggest spot is %d studs across): %s. Place them by hand."):format(biggest, table.concat(missing, ", ")))
		end
		if skipped > 0 then
			print(("[PlaceAssets] Skipped %d extra copies because the cave is full.%s"):format(skipped, #missing == 0 and " Every model is in at least once." or ""))
		end
		if #errors > 0 then
			warn("[PlaceAssets] Some models couldn't be placed because of an error. Copy this message and send it to Claude:\n" .. table.concat(errors, "\n"))
		end
		local pieces = {}
		for name, n in pairs(skippedPieces) do
			table.insert(pieces, n > 1 and ("%s x%d"):format(name, n) or name)
		end
		if #pieces > 0 then
			table.sort(pieces)
			print(("[PlaceAssets] Left out %s: they look like building pieces, not props. Rename one in ServerStorage.CaveAssets to put it in."):format(table.concat(pieces, ", ")))
		end
		-- If the new cave's terrain wasn't there yet, check again once Studio has finished applying
		-- it, and lift anything that dips into the real floor (nothing is ever lowered).
		if not raysWork and task then
			local tries = 0
			local function lateCheck()
				tries += 1
				if not raysAgree() then
					if tries < 8 then
						task.delay(4, lateCheck)
					end
					return
				end
				local lifted = 0
				for _, m in ipairs(placedModels) do
					if m.Parent then
						local lo, hi = bounds(m, true)
						local floorY = -math.huge
						for _, xz in ipairs({ { 0.5, 0.5 }, { 0.1, 0.1 }, { 0.9, 0.1 }, { 0.1, 0.9 }, { 0.9, 0.9 } }) do
							local x, z = lo.X + (hi.X - lo.X) * xz[1], lo.Z + (hi.Z - lo.Z) * xz[2]
							local hit = workspace:Raycast(Vector3.new(x, lo.Y + 5, z), Vector3.new(0, -10, 0), floorRays)
							if hit then
								floorY = math.max(floorY, hit.Position.Y)
							end
						end
						if floorY > lo.Y + 0.05 then
							m:PivotTo(m:GetPivot() + Vector3.new(0, floorY - lo.Y + 0.02, 0))
							lifted += 1
						end
					end
				end
				print(("[PlaceAssets] Checked your models against the finished cave: %s"):format(
					lifted > 0 and ("lifted %d that dipped into the floor."):format(lifted) or "they all stand on the floor."
				))
			end
			task.delay(3, lateCheck)
		end
		for _, name in ipairs(skippedEmpty) do
			warn("[PlaceAssets] Skipped '" .. name .. "': it has no parts.")
		end
		return true
	end

	local ok, result = xpcall(place, debug.traceback)
	if not ok then
		warn("[PlaceAssets] Something went wrong. Copy this whole message and send it to Claude:\n" .. tostring(result))
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
