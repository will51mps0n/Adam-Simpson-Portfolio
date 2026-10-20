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
	           2 decor / 1 for anything bigger than 30 studs)
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
	DECOR_COPIES = 2,
	BIG = 30, -- studs across; anything bigger is placed once unless it has a Count attribute
	COLLECT_FROM_WORKSPACE = "auto", -- "auto" = only the first time (before CaveAssets exists); true = always; false = never
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

		-- world-space box around everything (works for any pivot/orientation)
		local function bounds(inst)
			local lo = Vector3.new(math.huge, math.huge, math.huge)
			local hi = -lo
			for _, p in ipairs(partsOf(inst)) do
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
			local best = math.huge
			for step = 0, 11 do
				local a = step * math.pi / 12
				local ca, sa = math.cos(a), math.sin(a)
				local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
				for _, c in ipairs(corners) do
					local x, z = c.X * ca - c.Z * sa, c.X * sa + c.Z * ca
					x0, x1, z0, z1 = math.min(x0, x), math.max(x1, x), math.min(z0, z), math.max(z1, z)
				end
				best = math.min(best, math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2))
			end
			return best
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

		-- How high a model's pivot sat above the ground it stood on. Placing it at the same
	-- height keeps it looking right even when a mesh sticks out of its part's box.
	local function floorOffsetOf(asset, lo, hi)
		local v = asset:GetAttribute("FloorOffset")
		if type(v) == "number" then
			return v
		end
		-- models an earlier version already moved here: they were standing on the Baseplate
		local bp = workspace:FindFirstChild("Baseplate")
		if bp and bp:IsA("BasePart") then
			local top = bp.Position.Y + bp.Size.Y / 2
			if hi.Y > top and lo.Y < top + 6 then
				return asset:GetPivot().Y - top
			end
		end
		return nil
	end

	-- what to place. Models with the same name count as one design (your 6 Closets are
		-- 6 copies of a closet, not 6 designs x 3 copies each).
		local jobs, skippedEmpty = {}, {}
		local function collect(folder, hiding)
			if not folder then
				return
			end
			local groups, order = {}, {}
			for _, asset in ipairs(folder:GetChildren()) do
				if asset:IsA("Model") or asset:IsA("BasePart") then
					local lo, hi = bounds(asset)
					if lo.X == math.huge then
						table.insert(skippedEmpty, asset.Name)
					else
						if not groups[asset.Name] then
							groups[asset.Name] = {}
							table.insert(order, asset.Name)
						end
						table.insert(groups[asset.Name], { asset = asset, footprint = footprintOf(asset), height = (hi - lo).Y, offset = floorOffsetOf(asset, lo, hi) })
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
					table.insert(jobs, { asset = t.asset, name = name, hiding = hiding, footprint = t.footprint, height = t.height, offset = t.offset, copy = copy })
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
		local spots, biggest = {}, 0
		for _, s in ipairs(spotFolder:GetChildren()) do
			if s:IsA("BasePart") then
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

		local placed, failed, errors = {}, {}, {}
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
				if #choices == 0 then
					failed[job.name] = failed[job.name] or { job = job, n = 0 }
					failed[job.name].n += 1
				else
					local spot = choices[rng:NextInteger(1, #choices)]
					local at, look = spot.pos, spot.look
					if spot.footprint >= job.footprint * 2 then
						-- small model in a big spot: tuck it against the wall side of the spot and
						-- keep the rest of the spot free for more models
						local a = rng:NextNumber(-0.9, 0.9)
						local back = -look
						back = Vector3.new(back.X * math.cos(a) - back.Z * math.sin(a), 0, back.X * math.sin(a) + back.Z * math.cos(a))
						at = spot.pos + back * ((spot.footprint - job.footprint) / 2)
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

					-- turn it (around world Y only, so it stays upright) so its front faces the
					-- middle of the room for hiding props, or a random way for decor
					local pivot = clone:GetPivot()
					local wantYaw = job.hiding and yawOf(look) or rng:NextNumber(0, math.pi * 2)
					local turn = wantYaw - yawOf(pivot.LookVector)
					clone:PivotTo(CFrame.new(at) * CFrame.Angles(0, turn, 0) * pivot.Rotation)

					-- then slide it over the spot, at the same height it stood at before
					-- (or with the bottom of its box on the floor if we don't know that)
					local lo, hi = bounds(clone)
					local center = (lo + hi) / 2
					local lift = at.Y - lo.Y - 0.05
					if job.offset and lo.Y + job.offset > at.Y - 4 then
						lift = job.offset
					end
					clone:PivotTo(clone:GetPivot() + Vector3.new(at.X - center.X, lift, at.Z - center.Z))

					if job.hiding then
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
					placed[job.name] = (placed[job.name] or 0) + 1
				end
			end)
			if not ok then
				table.insert(errors, job.name .. ": " .. tostring(err))
			end
		end

		local total, extras, missing = 0, 0, 0
		local names = {}
		for name, count in pairs(placed) do
			total += count
			table.insert(names, ("%s x%d"):format(name, count))
		end
		table.sort(names)
		print(("[PlaceAssets] Put %d of your models in the cave: %s"):format(total, table.concat(names, ", ")))
		for name, f in pairs(failed) do
			if placed[name] then
				extras += f.n
			else
				missing += 1
				warn(("[PlaceAssets] '%s' didn't fit anywhere (%d studs across, %d tall; the biggest spot is %d). Place it by hand."):format(name, f.job.footprint, f.job.height, biggest))
			end
		end
		if extras > 0 then
			print(("[PlaceAssets] Skipped %d extra copies because the cave is full.%s"):format(extras, missing == 0 and " Every model is in at least once." or ""))
		end
		if #errors > 0 then
			warn("[PlaceAssets] Some models couldn't be placed because of an error. Copy this message and send it to Claude:\n" .. table.concat(errors, "\n"))
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
