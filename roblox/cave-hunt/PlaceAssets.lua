--[[
	==================================================================
	 CAVE HUNT  -  Place your own assets into the cave  (v1)
	==================================================================
	Copies your models onto the PropSpot markers that CaveBuilder left
	around the cave. Run CaveBuilder first.

	SETUP (once):
	  1. In ServerStorage, make a Folder called  CaveAssets
	  2. Inside it, make two Folders:  Hiding  and  Decor
	       Hiding = things players can hide in (shelves, container, ...)
	       Decor  = decoration only
	  3. Drag your models into those folders. Big ones (like your big
	     room) go in Decor, or in Hiding if people can hide inside them.
	     Optional: give a model a number attribute "Count" to choose how
	     many copies get placed (default 3 for hiding, 2 for decor, 1 for
	     anything bigger than 30 studs).

	RUN: paste into the Command Bar (or ModuleScript + require, like
	CaveBuilder). Run it again any time to reshuffle. Only the
	Workspace.CaveSystem.PlacedAssets folder is replaced, so your other
	edits in the cave are kept.

	Things in Hiding get the "HidingSpot" tag plus HidePoint/ExitPoint
	parts (unless they already have them), same as the built-in ones.
]]

local CONFIG = {
	SEED = nil, -- nil = a new arrangement every run. Put a number to get the same one each time
	HIDING_COPIES = 3,
	DECOR_COPIES = 2,
	BIG = 30, -- studs across; anything bigger is placed once unless it has a Count attribute
}

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local cave = workspace:FindFirstChild("CaveSystem")
local spotFolder = cave and cave:FindFirstChild("PropSpots")
if not spotFolder then
	warn("[PlaceAssets] Workspace.CaveSystem.PropSpots not found. Run CaveBuilder first.")
	return false
end
local source = ServerStorage:FindFirstChild("CaveAssets") or workspace:FindFirstChild("CaveAssets")
if not source then
	warn("[PlaceAssets] Make a Folder called CaveAssets in ServerStorage with Hiding and Decor folders inside, and put your models in them.")
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

local function yawOf(look) -- heading angle of a look vector
	return math.atan2(-look.X, -look.Z)
end

-- what to place
local jobs, skippedEmpty = {}, {}
local function collect(folder, hiding)
	if not folder then
		return
	end
	for _, asset in ipairs(folder:GetChildren()) do
		if asset:IsA("Model") or asset:IsA("BasePart") then
			local lo, hi = bounds(asset)
			if lo.X == math.huge then
				table.insert(skippedEmpty, asset.Name)
			else
				local size = hi - lo
				local footprint = math.sqrt(size.X ^ 2 + size.Z ^ 2) -- widest it can be at any rotation
				local count = asset:GetAttribute("Count")
				if type(count) ~= "number" then
					count = footprint > CONFIG.BIG and 1 or (hiding and CONFIG.HIDING_COPIES or CONFIG.DECOR_COPIES)
				end
				for _ = 1, count do
					table.insert(jobs, { asset = asset, hiding = hiding, footprint = footprint, height = size.Y })
				end
			end
		end
	end
end
collect(source:FindFirstChild("Hiding"), true)
collect(source:FindFirstChild("Decor"), false)
collect(source, false) -- models dropped straight into CaveAssets count as decor

if #jobs == 0 then
	warn("[PlaceAssets] No models found in CaveAssets/Hiding or CaveAssets/Decor.")
	return false
end

-- where it can go
local spots = {}
for _, s in ipairs(spotFolder:GetChildren()) do
	if s:IsA("BasePart") then
		table.insert(spots, {
			part = s,
			footprint = s:GetAttribute("MaxFootprint") or 10,
			height = s:GetAttribute("MaxHeight") or 15,
		})
	end
end

local old = cave:FindFirstChild("PlacedAssets")
if old then
	old:Destroy()
end
local out = Instance.new("Folder")
out.Name = "PlacedAssets"
out.Parent = cave

-- biggest things first so they get the big spots
table.sort(jobs, function(a, b)
	return a.footprint > b.footprint
end)

local placed, failed = {}, {}
for _, job in ipairs(jobs) do
	local fits = {}
	for _, s in ipairs(spots) do
		if not s.used and job.footprint <= s.footprint and job.height <= s.height then
			table.insert(fits, s)
		end
	end
	if #fits == 0 then
		failed[job.asset.Name] = failed[job.asset.Name] or { job = job, n = 0 }
		failed[job.asset.Name].n += 1
	else
		local spot = fits[rng:NextInteger(1, #fits)]
		spot.used = true

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
		local floor = spot.part.CFrame * CFrame.new(0, -spot.part.Size.Y / 2, 0)
		local pivot = clone:GetPivot()
		local wantYaw = job.hiding and yawOf(floor.LookVector) or rng:NextNumber(0, math.pi * 2)
		local turn = wantYaw - yawOf(pivot.LookVector)
		clone:PivotTo(CFrame.new(floor.Position) * CFrame.Angles(0, turn, 0) * pivot.Rotation)

		-- then slide it so its bottom-center sits on the spot
		local lo, hi = bounds(clone)
		local center = (lo + hi) / 2
		clone:PivotTo(clone:GetPivot() + Vector3.new(floor.Position.X - center.X, floor.Position.Y - lo.Y - 0.05, floor.Position.Z - center.Z))

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
					p.CFrame = CFrame.lookAt(pos, pos + floor.LookVector)
					p.Parent = clone
				end
			end
			local mid = (lo + hi) / 2
			local halfDepth = math.max(hi.X - lo.X, hi.Z - lo.Z) / 2
			addPoint("HidePoint", Vector3.new(mid.X, math.min(lo.Y + 3, mid.Y), mid.Z))
			addPoint("ExitPoint", Vector3.new(mid.X, lo.Y + 3, mid.Z) + floor.LookVector * (halfDepth + 3))
			if clone:GetAttribute("HideType") == nil then
				clone:SetAttribute("HideType", job.asset.Name)
			end
			clone:SetAttribute("Occupied", false)
			CollectionService:AddTag(clone, "HidingSpot")
		end
		clone.Parent = out
		placed[job.asset.Name] = (placed[job.asset.Name] or 0) + 1
	end
end

local biggest = 0
for _, s in ipairs(spots) do
	biggest = math.max(biggest, s.footprint)
end
for name, count in pairs(placed) do
	print(("[PlaceAssets] Placed %d x %s"):format(count, name))
end
for name, f in pairs(failed) do
	warn(("[PlaceAssets] No free spot left for %d x '%s' (%d studs across, %d tall; the biggest spot in the cave is %d). Place those by hand, or lower its Count."):format(f.n, name, f.job.footprint, f.job.height, biggest))
end
for _, name in ipairs(skippedEmpty) do
	warn("[PlaceAssets] Skipped '" .. name .. "': it has no parts.")
end
return true
