-- Preview harness: loads the built place in Lune, runs the real ModuleScripts
-- with Roblox datatypes, builds kids, plays the animations, and dumps scenes as JSON
-- for render.html. usage: lune run run.luau <place.rbxlx> <scenes.json>

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local task = require("@lune/task")
local process = require("@lune/process")

local placePath, outPath = process.args[1], process.args[2]
local place = roblox.deserializePlace(fs.readFile(placePath))
local Workspace = place:GetService("Workspace")
-- Put the camera where the game's overview camera sits.
Workspace.CurrentCamera.CFrame = roblox.CFrame.lookAt(roblox.Vector3.new(-4, 8.5, 38), roblox.Vector3.new(-4, 4.2, 0))

local warnings = {}

-- Stubs for engine features Lune doesn't have.
local stepCallbacks = {}
local function stubSignal()
	return {
		Connect = function(_, fn)
			table.insert(stepCallbacks, fn)
			return { Disconnect = function() end }
		end,
	}
end
local RunServiceStub = {
	RenderStepped = stubSignal(),
	Heartbeat = stubSignal(),
	BindToRenderStep = function(_, _name, _priority, fn)
		table.insert(stepCallbacks, fn)
	end,
}
roblox.implementMethod("ParticleEmitter", "Emit", function() end)
roblox.implementMethod("Workspace", "BulkMoveTo", function(_, parts, cframes)
	for i, part in parts do
		part.CFrame = cframes[i]
	end
end)

local gameProxy = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_, name)
				if name == "RunService" then
					return RunServiceStub
				end
				return place:GetService(name)
			end
		end
		return place[key]
	end,
})

local RandomStub = {
	new = function(seed)
		local state = seed or 4242
		local function nextValue()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
		return {
			NextNumber = function(_, a, b)
				a = a or 0
				b = b or 1
				return a + (b - a) * nextValue()
			end,
			NextInteger = function(_, a, b)
				return a + math.floor(nextValue() * (b - a + 1))
			end,
		}
	end,
}

local cache = {}
local function requireModule(module)
	local key = module:GetFullName()
	if cache[key] ~= nil then
		return cache[key]
	end
	local env = {
		script = module,
		require = requireModule,
		game = gameProxy,
		workspace = Workspace,
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		Random = RandomStub,
		task = task,
		warn = function(...)
			table.insert(warnings, table.concat({ ... }, " "))
			print("WARN", ...)
		end,
	}
	local fn = luau.load(module.Source, { debugName = key, environment = env })
	local result = fn()
	cache[key] = result
	return result
end

local ReplicatedStorage = place:GetService("ReplicatedStorage")
local StarterPlayer = place:GetService("StarterPlayer")
local Shared = ReplicatedStorage:FindFirstChild("Shared")
local Character = Shared:FindFirstChild("Character")
local Client = StarterPlayer:FindFirstChild("StarterPlayerScripts"):FindFirstChild("Client")

local CharacterBuilder = requireModule(Character:FindFirstChild("CharacterBuilder"))
local Characters = requireModule(Shared:FindFirstChild("Data"):FindFirstChild("Characters"))
local Outfits = requireModule(Shared:FindFirstChild("Data"):FindFirstChild("Outfits"))
local KidAnimator = requireModule(Client:FindFirstChild("Animation"):FindFirstChild("KidAnimator"))

------------------------------------------------------------------------
-- Serialization

local function color(c)
	return { c.R, c.G, c.B }
end
local function udim2(u)
	return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
end

local function guiNode(obj)
	local node = {
		class = obj.ClassName,
		name = obj.Name,
		position = udim2(obj.Position),
		size = udim2(obj.Size),
		anchor = { obj.AnchorPoint.X, obj.AnchorPoint.Y },
		rotation = obj.Rotation,
		color = color(obj.BackgroundColor3),
		transparency = obj.BackgroundTransparency,
		visible = obj.Visible,
		clips = obj.ClipsDescendants,
		z = obj.ZIndex,
		children = {},
	}
	local corner = obj:FindFirstChildOfClass("UICorner")
	if corner then
		node.corner = { corner.CornerRadius.Scale, corner.CornerRadius.Offset }
	end
	if obj:IsA("TextLabel") then
		node.text = obj.Text
		node.textColor = color(obj.TextColor3)
	end
	for _, child in obj:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(node.children, guiNode(child))
		end
	end
	return node
end

local function serializeModel(model)
	local parts = {}
	local guis = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local mesh = d:FindFirstChildOfClass("SpecialMesh")
			table.insert(parts, {
				name = d.Name,
				cf = { d.CFrame:GetComponents() },
				size = { d.Size.X, d.Size.Y, d.Size.Z },
				color = color(d.Color),
				transparency = d.Transparency,
				shape = if d:IsA("Part") then d.Shape.Name else "Block",
				mesh = if mesh then { type = mesh.MeshType.Name, scale = { mesh.Scale.X, mesh.Scale.Y, mesh.Scale.Z } } else nil,
			})
			local gui = d:FindFirstChildOfClass("SurfaceGui")
			if gui then
				local children = {}
				for _, child in gui:GetChildren() do
					if child:IsA("GuiObject") then
						table.insert(children, guiNode(child))
					end
				end
				table.insert(guis, {
					partIndex = #parts,
					face = gui.Face.Name,
					canvas = { gui.CanvasSize.X, gui.CanvasSize.Y },
					children = children,
				})
			end
		end
	end
	return { name = model.Name, parts = parts, guis = guis }
end

------------------------------------------------------------------------
-- Scenes

local scenes = {}
local function snapshot(sceneName, kids, extra)
	local models = {}
	for _, kid in kids do
		table.insert(models, serializeModel(kid.Model))
	end
	scenes[sceneName] = { models = models, extra = extra or {} }
end

local holder = roblox.Instance.new("Folder")
local lineup = {
	Characters.Extras[1],
	Characters.Extras[2],
	Characters.Heroes[2],
	Characters.Heroes[1],
	Characters.Extras[3],
	Characters.Extras[4],
	Characters.Extras[5],
}
local SPACING = 4.4
local DOCK_Y = 1.4

-- Lineup, standing still (rest pose, facing the camera turned toward +X).
local yaw = roblox.CFrame.Angles(0, math.pi + math.rad(16), 0)
local kids = {}
for i, character in lineup do
	local x = (i - (#lineup + 1) / 2) * SPACING
	local kid = CharacterBuilder.build(Outfits.copy(character.outfit), roblox.CFrame.new(x, DOCK_Y, 0) * yaw, {
		name = character.name,
		parent = holder,
	})
	kids[i] = kid
end
snapshot("lineup", kids)

-- Every expression on Pip and Max (facing straight at the camera).
local straight = roblox.CFrame.Angles(0, math.pi, 0)
for _, id in { "Pip", "Max", "Polly", "Mo", "Rae" } do
	local character = Characters.get(id)
	for _, expression in requireModule(Character:FindFirstChild("Face")).ExpressionOrder do
		local kid = CharacterBuilder.build(Outfits.copy(character.outfit), roblox.CFrame.new(0, 0, 0) * straight, {
			name = id,
			parent = holder,
		})
		kid.Face:SetExpression(expression)
		snapshot("face_" .. id .. "_" .. expression, { kid })
		kid.Model:Destroy()
	end
end

-- Every hat and hair combination on one kid.
local hatIds = {}
for _, item in Outfits.Hats do
	table.insert(hatIds, item.id)
end
for _, hair in Outfits.HairStyles do
	local row = {}
	for j, hatId in hatIds do
		local outfit = Outfits.copy(Characters.get("Kai").outfit)
		outfit.lifeRing = nil
		outfit.hair = { style = hair.id, color = "Chestnut" }
		local hatItem = Outfits.find(Outfits.Hats, hatId)
		outfit.hat = if hatId == "None" then nil else { style = hatId, color = hatItem.color, accent = hatItem.accent }
		local kid = CharacterBuilder.build(outfit, roblox.CFrame.new((j - 3.5) * 4, 0, 0) * yaw, { name = hatId, parent = holder })
		table.insert(row, kid)
	end
	snapshot("hats_" .. hair.id, row)
	for _, kid in row do
		kid.Model:Destroy()
	end
end

-- Animation: simulate frames and capture poses.
local function step(seconds, dt)
	dt = dt or 1 / 60
	local n = math.floor(seconds / dt + 0.5)
	for _ = 1, n do
		for _, fn in stepCallbacks do
			fn(dt)
		end
	end
end

local pipChar = Characters.get("Pip")
local maxChar = Characters.get("Max")
local function freshAnimator(character, x)
	local home = roblox.Vector3.new(x, DOCK_Y, 0)
	local kid = CharacterBuilder.build(Outfits.copy(character.outfit), roblox.CFrame.new(home), { name = character.id, parent = holder })
	local animator = KidAnimator.new(kid, { home = home, facing = 1 })
	return kid, animator
end

local pip, pipAnim = freshAnimator(pipChar, -2.5)
local max, maxAnim = freshAnimator(maxChar, 2.5)
step(0.7)
snapshot("pose_idle", { pip, max })
pipAnim:Aim(true)
maxAnim:Aim(true)
step(0.5)
snapshot("pose_aim", { pip, max })
pipAnim:Fire()
maxAnim:Fire()
step(0.12)
snapshot("pose_fire_windup", { pip, max })
step(0.11)
snapshot("pose_fire_release", { pip, max })
step(0.6)
pipAnim:Hit(1)
maxAnim:Hit(1)
step(0.07)
snapshot("pose_hit", { pip, max })
step(1)
pipAnim:Win(true)
maxAnim:Win(true)
step(0.2)
snapshot("pose_win_air", { pip, max })
step(0.27)
snapshot("pose_win_land", { pip, max })
pipAnim:Win(false)
maxAnim:Win(false)
step(0.5)

local gone = 0
pipAnim.OnGone = function()
	gone += 1
end
maxAnim.OnGone = function()
	gone += 1
end
pipAnim:Knock(pipAnim:LaunchVelocity(-19.5, 20))
maxAnim:Knock(maxAnim:LaunchVelocity(-22, 20))
step(0.35)
snapshot("pose_flying", { pip, max }, { water = true })
step(1.2)
snapshot("pose_water", { pip, max }, { water = true })
print("states after splash:", pipAnim.State, maxAnim.State)
step(3.2)
snapshot("pose_sinking", { pip, max }, { water = true })
step(1.5)
print("states after sinking:", pipAnim.State, maxAnim.State, "gone callbacks:", gone)
pipAnim:DropIn()
maxAnim:DropIn()
step(0.62)
snapshot("pose_landing", { pip, max })
step(1)
print("states after drop in:", pipAnim.State, maxAnim.State)

local effects = Workspace:FindFirstChild("Effects")
print("effect parts left:", if effects then #effects:GetChildren() else 0)
print("highlights:", requireModule(Character:FindFirstChild("Outline")).count())
print("warnings:", #warnings)

fs.writeFile(outPath, serde.encode("json", scenes, false))
print("wrote", outPath)
