--[[
	==================================================================
	 CAVE HUNT  -  Gameplay scripts installer  (v1)
	==================================================================
	Installs (or updates) three scripts:

	  ServerScriptService.CaveHunt_Flashlights
	      every player gets a flashlight on their head. F (or the on-screen
	      "Light" button, or L1 on a controller) switches it on and off
	  ServerScriptService.CaveHunt_Hiding
	      walk up to any HidingSpot and press E to hide inside it (you go
	      invisible and your light goes out), press E again to come out.
	      ServerStorage.CaveHunt_KnockOut:Invoke(spot) throws whoever is in
	      a spot out. That's what the monster's attack will use later
	  StarterPlayerScripts.CaveHunt_Client
	      flashlight aiming, the cave mood (near-black, fog, colour grade,
	      only while you're inside the cave) and flickering lights

	Running it again replaces these three scripts with the latest version.
]]

local SOURCES = {}

SOURCES.Flashlights = [==[
-- CaveHunt: gives every player a flashlight on their head.
-- CaveHunt_Client switches it with F; this script owns the light so everyone sees it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local toggle = ReplicatedStorage:FindFirstChild("CaveHunt_ToggleFlashlight")
if not toggle then
	toggle = Instance.new("RemoteEvent")
	toggle.Name = "CaveHunt_ToggleFlashlight"
	toggle.Parent = ReplicatedStorage
end

local LIGHT = Color3.fromRGB(255, 238, 210)

local function addFlashlight(character)
	local head = character:WaitForChild("Head", 10)
	if not head or head:FindFirstChild("Flashlight") then
		return
	end
	local mount = Instance.new("Attachment")
	mount.Name = "Flashlight"
	mount.Position = Vector3.new(0, 0.2, -0.7)
	mount.Parent = head

	local beam = Instance.new("SpotLight")
	beam.Name = "Beam"
	beam.Face = Enum.NormalId.Front
	beam.Angle = 45
	beam.Range = 45
	beam.Brightness = 2.5
	beam.Color = LIGHT
	beam.Shadows = true
	beam.Parent = mount

	local spill = Instance.new("PointLight") -- a faint glow so you can see your own feet
	spill.Name = "Spill"
	spill.Range = 7
	spill.Brightness = 0.25
	spill.Color = LIGHT
	spill.Parent = mount
end

local function onPlayer(player)
	player.CharacterAdded:Connect(addFlashlight)
	if player.Character then
		task.spawn(addFlashlight, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end

toggle.OnServerEvent:Connect(function(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	local mount = head and head:FindFirstChild("Flashlight")
	if mount and not player:GetAttribute("Hidden") then
		local on = not mount.Beam.Enabled
		mount.Beam.Enabled = on
		mount.Spill.Enabled = on
	end
end)
]==]

SOURCES.Hiding = [==[
-- CaveHunt: press E at any HidingSpot (CollectionService tag) to hide inside it.
-- Press E again to come out. ServerStorage.CaveHunt_KnockOut:Invoke(spot) throws the
-- hider out (for the monster's attack later).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local hiding = {} -- player -> { spot = Model, prompt = ProximityPrompt, saved = {} }

-- hide/show a character and switch its lights off/on, remembering how it was
local function setHidden(character, hide, saved)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			if hide then
				saved[d] = d.Transparency
				d.Transparency = 1
			elseif saved[d] ~= nil then
				d.Transparency = saved[d]
			end
		elseif d:IsA("Light") then
			if hide then
				saved[d] = d.Enabled
				d.Enabled = false
			elseif saved[d] ~= nil then
				d.Enabled = saved[d]
			end
		end
	end
end

local function leave(player)
	local h = hiding[player]
	if not h then
		return
	end
	hiding[player] = nil
	player:SetAttribute("Hidden", nil)
	h.spot:SetAttribute("Occupied", false)
	h.prompt.ActionText = "Hide"
	local character = player.Character
	if character and character.Parent then
		setHidden(character, false, h.saved)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = false
		end
		local exit = h.spot:FindFirstChild("ExitPoint", true)
		if exit then
			character:PivotTo(exit.CFrame + Vector3.new(0, 0.5, 0))
		end
	end
end

local function hide(player, spot, prompt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local point = spot:FindFirstChild("HidePoint", true)
	if not (root and humanoid and point) or humanoid.Health <= 0 or spot:GetAttribute("Occupied") then
		return
	end
	local saved = {}
	hiding[player] = { spot = spot, prompt = prompt, saved = saved }
	player:SetAttribute("Hidden", true)
	spot:SetAttribute("Occupied", true)
	character:PivotTo(point.CFrame)
	root.Anchored = true
	setHidden(character, true, saved)
	prompt.ActionText = "Leave"
end

local function setup(spot)
	if not spot:IsA("Model") or spot:FindFirstChild("HidePrompt", true) then
		return
	end
	local anchor = spot:FindFirstChild("HidePoint", true) or spot.PrimaryPart or spot:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HidePrompt"
	prompt.ActionText = "Hide"
	prompt.ObjectText = tostring(spot:GetAttribute("HideType") or spot.Name)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		local h = hiding[player]
		if h then
			if h.spot == spot then
				leave(player)
			end
		else
			hide(player, spot, prompt)
		end
	end)
end

for _, spot in ipairs(CollectionService:GetTagged("HidingSpot")) do
	setup(spot)
end
CollectionService:GetInstanceAddedSignal("HidingSpot"):Connect(setup)

local function onPlayer(player)
	player.CharacterRemoving:Connect(function()
		leave(player)
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(leave)

local knock = ServerStorage:FindFirstChild("CaveHunt_KnockOut")
if not knock then
	knock = Instance.new("BindableFunction")
	knock.Name = "CaveHunt_KnockOut"
	knock.Parent = ServerStorage
end
knock.OnInvoke = function(spot)
	for player, h in pairs(hiding) do
		if h.spot == spot then
			leave(player)
			return player
		end
	end
	return nil
end
]==]

SOURCES.Client = [==[
-- CaveHunt client: flashlight controls, the cave mood, flickering lights.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer

-- Flashlight: F, the on-screen "Light" button, or L1 switches it on and off
task.spawn(function()
	local toggle = ReplicatedStorage:WaitForChild("CaveHunt_ToggleFlashlight", 30)
	if not toggle then
		return
	end
	ContextActionService:BindAction("CaveHunt_Flashlight", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggle:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL1)
	ContextActionService:SetTitle("CaveHunt_Flashlight", "Light")
end)

-- your own beam points where your camera looks (other players see it follow your head)
RunService.RenderStepped:Connect(function()
	local head = player.Character and player.Character:FindFirstChild("Head")
	local mount = head and head:FindFirstChild("Flashlight")
	if mount then
		local look = head.CFrame:VectorToObjectSpace(workspace.CurrentCamera.CFrame.LookVector)
		mount.CFrame = CFrame.lookAt(mount.Position, mount.Position + look)
	end
end)

-- Cave mood: near-black, short fog and a washed-out, contrasty grade while you're
-- inside the cave's rock block. Everything goes back to normal when you leave.
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "CaveHunt_Grade"
grade.Contrast = 0.18
grade.Saturation = -0.4
grade.Brightness = -0.02
grade.TintColor = Color3.fromRGB(222, 230, 255)
grade.Enabled = false
grade.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name = "CaveHunt_Bloom"
bloom.Intensity = 0.7
bloom.Size = 28
bloom.Threshold = 0.85
bloom.Enabled = false
bloom.Parent = Lighting

local saved
local function setCaveMood(on)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if on then
		saved = {
			lighting = {
				Ambient = Lighting.Ambient,
				OutdoorAmbient = Lighting.OutdoorAmbient,
				EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
				EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
				FogColor = Lighting.FogColor,
				FogStart = Lighting.FogStart,
				FogEnd = Lighting.FogEnd,
			},
		}
		Lighting.Ambient = Color3.fromRGB(2, 2, 4)
		Lighting.OutdoorAmbient = Color3.fromRGB(4, 4, 6)
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0.1
		Lighting.FogColor = Color3.fromRGB(5, 5, 7)
		Lighting.FogStart = 0
		Lighting.FogEnd = 160
		if atmosphere then -- with an Atmosphere, Roblox ignores the Fog settings, so darken it instead
			saved.atmosphere = {
				Density = atmosphere.Density,
				Offset = atmosphere.Offset,
				Color = atmosphere.Color,
				Decay = atmosphere.Decay,
				Glare = atmosphere.Glare,
				Haze = atmosphere.Haze,
			}
			atmosphere.Density = 0.45
			atmosphere.Offset = 0
			atmosphere.Color = Color3.fromRGB(14, 14, 18)
			atmosphere.Decay = Color3.fromRGB(8, 8, 10)
			atmosphere.Glare = 0
			atmosphere.Haze = 0
		end
	elseif saved then
		for k, v in pairs(saved.lighting) do
			Lighting[k] = v
		end
		if atmosphere and saved.atmosphere then
			for k, v in pairs(saved.atmosphere) do
				atmosphere[k] = v
			end
		end
		saved = nil
	end
	grade.Enabled = on
	bloom.Enabled = on
end

task.spawn(function()
	local inCave = false
	while true do
		task.wait(0.5)
		local cave = workspace:FindFirstChild("CaveSystem")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local center = cave and cave:GetAttribute("BoxCenter")
		local size = cave and cave:GetAttribute("BoxSize")
		local now = false
		if root and center and size then
			local d = root.Position - center
			now = math.abs(d.X) < size.X / 2 and math.abs(d.Y) < size.Y / 2 and math.abs(d.Z) < size.Z / 2
		end
		if now ~= inCave then
			inCave = now
			setCaveMood(now)
		end
	end
end)

-- Lights tagged "Flicker" stutter every few seconds
local function flicker(light)
	if not light:IsA("Light") then
		return
	end
	task.spawn(function()
		local base = light.Brightness
		while light.Parent do
			task.wait(0.5 + math.random() * 4)
			for _ = 1, math.random(2, 6) do
				light.Brightness = base * (math.random() < 0.5 and 0.05 or 0.5)
				task.wait(0.03 + math.random() * 0.08)
				light.Brightness = base
				task.wait(0.03 + math.random() * 0.12)
			end
		end
	end)
end
for _, light in ipairs(CollectionService:GetTagged("Flicker")) do
	flicker(light)
end
CollectionService:GetInstanceAddedSignal("Flicker"):Connect(flicker)
]==]

local function run()
	local ok, err = pcall(function()
		local ServerScriptService = game:GetService("ServerScriptService")
		local StarterPlayer = game:GetService("StarterPlayer")
		local playerScripts = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
		if not playerScripts then
			playerScripts = Instance.new("StarterPlayerScripts")
			playerScripts.Parent = StarterPlayer
		end
		local function install(parent, className, name, source)
			local old = parent:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			local s = Instance.new(className)
			s.Name = name
			s.Source = source
			s.Parent = parent
		end
		install(ServerScriptService, "Script", "CaveHunt_Flashlights", SOURCES.Flashlights)
		install(ServerScriptService, "Script", "CaveHunt_Hiding", SOURCES.Hiding)
		install(playerScripts, "LocalScript", "CaveHunt_Client", SOURCES.Client)
	end)
	if not ok then
		warn("[GameScripts] Something went wrong. Copy this message and send it to Claude:\n" .. tostring(err))
		return false
	end
	print("[GameScripts] Installed flashlights (F), hiding (E) and the cave mood. Press Play to try them.")
	return true
end

-- Loaded as a ModuleScript (the GitHub one-liner): hand back run. Pasted straight into the Command Bar: just run it.
if script then
	return run
end
return run()
