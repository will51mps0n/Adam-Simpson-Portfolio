--[[
	==================================================================
	 CAVE HUNT  -  Gameplay scripts installer  (v2)
	==================================================================
	Installs (or updates) these scripts:

	  ServerScriptService.CaveHunt_Players
	      * hiders get the plain blocky Roblox body (everyone the same size)
	        with their own head, face, hair/hats, skin colours and clothes
	      * hiders get a flashlight on their head (F to switch it). If
	        StarterPack has a Tool with "flash" in its name, that's used
	        instead and the head flashlight stays off
	      * the monster: tall, fast, no flashlight, sees in the dark, and
	        touching a hider kills them. If ServerStorage has a rigged model
	        called "Monster" (Humanoid + HumanoidRootPart) that's its body;
	        otherwise your own character turns into a tall black creature
	        with red eyes. It spawns at a random MonsterSpawn (a lair)
	      * the "Play as Monster" / "Play as Hider" button switches roles
	        (for testing until there's a round system)
	  ServerStorage.CaveHunt_Tools
	      the hotbar items. Hiders get a Phone (ring another hider: their
	      phone rings out loud and flashes, even inside a closet). The
	      monster gets Leap, Sense (see hiders through walls), Scent (see
	      where hiders walked) and Roar (shake hiders, knock out their lights).
	      Picking an item uses it; its slot counts down while it recharges
	  ServerScriptService.CaveHunt_Hiding
	      hiders press E at any HidingSpot to hide inside it (invisible, light
	      off) and E again to come out. The monster pressing E on a hiding
	      spot ("Search") throws whoever is inside out
	  StarterPlayerScripts.CaveHunt_Client
	      the role button, flashlight aiming, the cave mood (only while you're
	      inside the cave; red night vision for the monster) and flickering lights

	Running it again replaces these scripts with the latest version.
]]

local SOURCES = {}

SOURCES.Players = [==[
-- CaveHunt: roles, avatars, the monster and the hiders' flashlights.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")
local CollectionService = game:GetService("CollectionService")

local HIDER_SPEED = 16
local MONSTER_SPEED = 26
local MONSTER_SCALE = 1.5 -- the built-in monster is 1.5x as tall as a hider
local LIGHT = Color3.fromRGB(255, 238, 210)
local PHONE_COOLDOWN = 8
local ROAR_COOLDOWN = 25
local ROAR_RANGE = 140
-- built-in Roblox sounds; swap in any sound you like, e.g. "rbxassetid://1234567"
local RINGTONE = "rbxasset://sounds/electronicpingshort.wav"
local ROAR_SOUND = "rbxasset://sounds/uuhhh.mp3"

local function remote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local setRole = remote("CaveHunt_SetRole")
local toggleLight = remote("CaveHunt_ToggleFlashlight")
local ringRemote = remote("CaveHunt_Ring")
local roarRemote = remote("CaveHunt_Roar")
local shakeRemote = remote("CaveHunt_Shake")
local notify = remote("CaveHunt_Notify")
local Debris = game:GetService("Debris")

-- hotbar items: Tools that GameScripts keeps in ServerStorage.CaveHunt_Tools
local HIDER_TOOLS = { "Phone" }
local MONSTER_TOOLS = { "Leap", "Sense", "Scent", "Roar" }
local function giveTools(player, names)
	local templates = ServerStorage:FindFirstChild("CaveHunt_Tools")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not (templates and backpack) then
		return
	end
	for _, name in ipairs(names) do
		local has = backpack:FindFirstChild(name) or (player.Character and player.Character:FindFirstChild(name))
		local template = templates:FindFirstChild(name)
		if template and not has then
			template:Clone().Parent = backpack
		end
	end
end
local function clearTools(player)
	for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if holder then
			for _, tool in ipairs(holder:GetChildren()) do
				if tool:IsA("Tool") then
					tool:Destroy()
				end
			end
		end
	end
end

-- a flashlight Tool in StarterPack replaces the head flashlight
local usingTool = false
for _, item in ipairs(StarterPack:GetChildren()) do
	if item:IsA("Tool") and item.Name:lower():find("flash") then
		usingTool = true
	end
end
toggleLight:SetAttribute("UsingToolFlashlight", usingTool)

------------------------------------------------------------------ hiders
-- plain blocky body at the standard size, keeping the player's head, face,
-- hair/hats, skin colours and clothes
local looks = {}
local function hiderLook(player)
	if looks[player] then
		return looks[player]
	end
	local d = Instance.new("HumanoidDescription")
	local ok, mine = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)
	if ok and mine then
		for _, prop in ipairs({
			"Head", "Face", "HatAccessory", "HairAccessory", "FaceAccessory",
			"Shirt", "Pants", "GraphicTShirt",
			"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor",
		}) do
			d[prop] = mine[prop]
		end
	end
	d.BodyTypeScale = 0
	d.ProportionScale = 0
	d.HeightScale = 1
	d.WidthScale = 1
	d.DepthScale = 1
	d.HeadScale = 1
	looks[player] = d
	return d
end

local function addFlashlight(character)
	local head = character:FindFirstChild("Head")
	if usingTool or not head or head:FindFirstChild("Flashlight") then
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

local function setupHider(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	pcall(function()
		humanoid:ApplyDescription(hiderLook(player))
	end)
	humanoid.WalkSpeed = HIDER_SPEED
	addFlashlight(character) -- after the new look, because that can replace the head
	giveTools(player, HIDER_TOOLS)
end

toggleLight.OnServerEvent:Connect(function(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	local mount = head and head:FindFirstChild("Flashlight")
	if mount and not player:GetAttribute("Hidden") then
		local on = not mount.Beam.Enabled
		mount.Beam.Enabled = on
		mount.Spill.Enabled = on
	end
end)

------------------------------------------------------------------ the monster
local function monsterSpawn()
	local spots = CollectionService:GetTagged("MonsterSpawn")
	if #spots == 0 then
		return nil
	end
	return spots[math.random(1, #spots)].CFrame + Vector3.new(0, 8, 0)
end

-- the built-in monster: the player's own character, black, red eyes, 1.5x tall
local function monsterize(character)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Accessory") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("SurfaceAppearance") or (d:IsA("Decal") and d.Name == "face") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Color = Color3.fromRGB(12, 12, 14)
			d.Material = Enum.Material.SmoothPlastic
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
		end
	end
	local head = character:FindFirstChild("Head")
	if head then
		for _, x in ipairs({ -0.22, 0.22 }) do
			local eye = Instance.new("Part")
			eye.Name = "Eye"
			eye.Size = Vector3.new(0.18, 0.1, 0.05)
			eye.Color = Color3.fromRGB(255, 30, 20)
			eye.Material = Enum.Material.Neon
			eye.CanCollide = false
			eye.Massless = true
			eye.CFrame = head.CFrame * CFrame.new(x, 0.1, -head.Size.Z / 2 - 0.02)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = eye
			weld.Parent = eye
			eye.Parent = character
		end
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 40, 30)
		glow.Range = 8
		glow.Brightness = 0.6
		glow.Parent = head
	end
	pcall(function()
		character:ScaleTo(MONSTER_SCALE)
	end)
end

local function setupMonster(player, character)
	character:SetAttribute("IsMonster", true)
	clearTools(player) -- no flashlight or phone for the monster
	giveTools(player, MONSTER_TOOLS)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = MONSTER_SPEED
	end
	-- one touch kills a hider who isn't hiding
	local lastHit = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				local victimCharacter = hit:FindFirstAncestorOfClass("Model")
				local victim = victimCharacter and Players:GetPlayerFromCharacter(victimCharacter)
				if not victim or victim == player or victim:GetAttribute("Role") == "Monster" or victim:GetAttribute("Hidden") then
					return
				end
				local victimHumanoid = victimCharacter:FindFirstChildOfClass("Humanoid")
				if victimHumanoid and victimHumanoid.Health > 0 and os.clock() - (lastHit[victim] or 0) > 1 then
					lastHit[victim] = os.clock()
					victimHumanoid.Health = 0
				end
			end)
		end
	end
end

local converting = {}
local function becomeMonster(player)
	if converting[player] then
		return
	end
	converting[player] = true
	player:SetAttribute("Role", "Monster")
	local ok, err = pcall(function()
		local template = ServerStorage:FindFirstChild("Monster")
		local spawnAt = monsterSpawn()
		if template and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") and template:FindFirstChild("HumanoidRootPart") then
			local body = template:Clone()
			for _, d in ipairs(body:GetDescendants()) do
				if d.ClassName == "Script" then
					d.Enabled = false -- its own AI/movement script would fight the player's controls (LocalScripts like Animate keep running)
				elseif d:IsA("BasePart") then
					d.Anchored = false
				end
			end
			body.Name = player.Name
			if spawnAt then
				body:PivotTo(spawnAt)
			end
			local previous = player.Character
			body.Parent = workspace
			player.Character = body
			if previous and previous ~= body then
				previous:Destroy()
			end
			setupMonster(player, body)
		else
			player:LoadCharacter()
			local character = player.Character or player.CharacterAdded:Wait()
			if not player:HasAppearanceLoaded() then
				player.CharacterAppearanceLoaded:Wait()
			end
			monsterize(character)
			if spawnAt then
				character:PivotTo(spawnAt)
			end
			setupMonster(player, character)
		end
	end)
	converting[player] = nil
	if not ok then
		warn("[CaveHunt] Couldn't make " .. player.Name .. " the monster: " .. tostring(err))
	end
end

local function becomeHider(player)
	player:SetAttribute("Role", "Hider")
	player:LoadCharacter() -- spawns at Base Camp; the hider look is applied when it loads
end

local busy = {}
setRole.OnServerEvent:Connect(function(player, role)
	if busy[player] or (role ~= "Monster" and role ~= "Hider") or role == player:GetAttribute("Role") then
		return
	end
	busy[player] = true
	if role == "Monster" then
		becomeMonster(player)
	else
		becomeHider(player)
	end
	task.wait(1)
	busy[player] = nil
end)

------------------------------------------------------------------ the monster's roar
-- shakes nearby hiders' screens and knocks out their lights for 5 seconds
local lastRoar = {}
roarRemote.OnServerEvent:Connect(function(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if player:GetAttribute("Role") ~= "Monster" or not root or os.clock() - (lastRoar[player] or -math.huge) < ROAR_COOLDOWN - 1 then
		return
	end
	lastRoar[player] = os.clock()
	local sound = Instance.new("Sound")
	sound.SoundId = ROAR_SOUND
	sound.PlaybackSpeed = 0.35
	sound.Volume = 3
	sound.RollOffMaxDistance = 400
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 8)
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local otherRoot = character and character:FindFirstChild("HumanoidRootPart")
		if other ~= player and other:GetAttribute("Role") ~= "Monster" and otherRoot and (otherRoot.Position - root.Position).Magnitude < ROAR_RANGE then
			shakeRemote:FireClient(other)
			local wasOn = {}
			for _, light in ipairs(character:GetDescendants()) do
				if light:IsA("Light") and light.Enabled then
					wasOn[light] = true
					light.Enabled = false
				end
			end
			task.delay(5, function()
				if other:GetAttribute("Hidden") then
					return -- hiding keeps lights off; they come back when they leave the spot
				end
				for light in pairs(wasOn) do
					if light.Parent then
						light.Enabled = true
					end
				end
			end)
		end
	end
end)

------------------------------------------------------------------ hider phones
-- ring another hider: their phone rings out loud and flashes for 4 seconds, even in a closet
local lastCall = {}
ringRemote.OnServerEvent:Connect(function(caller, target)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target == caller or target.Parent ~= Players then
		return
	end
	if caller:GetAttribute("Role") == "Monster" or target:GetAttribute("Role") == "Monster" then
		return
	end
	if os.clock() - (lastCall[caller] or -math.huge) < PHONE_COOLDOWN - 1 then
		return
	end
	local head = target.Character and target.Character:FindFirstChild("Head")
	if not head or head:FindFirstChild("Ringtone") then
		return
	end
	lastCall[caller] = os.clock()
	notify:FireClient(target, caller.DisplayName .. " is calling you!")
	notify:FireClient(caller, "Calling " .. target.DisplayName .. "...")

	local sound = Instance.new("Sound")
	sound.Name = "Ringtone"
	sound.SoundId = RINGTONE
	sound.Looped = true
	sound.Volume = 2
	sound.RollOffMaxDistance = 150
	sound.Parent = head
	sound:Play()

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(120, 180, 255)
	glow.Range = 12
	glow.Brightness = 2
	glow.Parent = head

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(140, 40)
	tag.StudsOffset = Vector3.new(0, 3, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 90
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "RING RING"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(140, 200, 255)
	label.TextStrokeTransparency = 0.3
	label.Parent = tag
	tag.Parent = head

	task.spawn(function()
		for i = 1, 16 do
			glow.Enabled = i % 2 == 1
			task.wait(0.25)
		end
		sound:Destroy()
		glow:Destroy()
		tag:Destroy()
	end)
end)

------------------------------------------------------------------ joining + respawning
local function onPlayer(player)
	if player:GetAttribute("Role") == nil then
		player:SetAttribute("Role", "Hider")
	end
	player.CharacterAppearanceLoaded:Connect(function(character)
		if player:GetAttribute("Role") ~= "Monster" then
			setupHider(player, character)
		end
	end)
	player.CharacterAdded:Connect(function(character)
		-- the monster respawning after dying comes back as the monster
		if player:GetAttribute("Role") == "Monster" and not converting[player] and not character:GetAttribute("IsMonster") then
			task.defer(becomeMonster, player)
		end
	end)
	if player.Character and player:HasAppearanceLoaded() and player:GetAttribute("Role") ~= "Monster" then
		task.spawn(setupHider, player, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	looks[player] = nil
	busy[player] = nil
	converting[player] = nil
	lastRoar[player] = nil
	lastCall[player] = nil
end)
]==]

SOURCES.Hiding = [==[
-- CaveHunt: hiders press E at any HidingSpot (CollectionService tag) to hide inside it,
-- and E again to come out. The monster pressing E on a spot throws whoever is inside out.
-- ServerStorage.CaveHunt_KnockOut:Invoke(spot) does the same from other scripts.
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

local function knockOut(spot)
	for player, h in pairs(hiding) do
		if h.spot == spot then
			leave(player)
			return player
		end
	end
	return nil
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
		if player:GetAttribute("Role") == "Monster" then
			knockOut(spot) -- the monster searches the spot
			return
		end
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
knock.OnInvoke = knockOut
]==]

SOURCES.Client = [==[
-- CaveHunt client: role button, flashlight controls, the cave mood, flickering lights.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local function isMonster()
	return player:GetAttribute("Role") == "Monster"
end

-- "Play as Monster" / "Play as Hider" button (for testing until there's a round system)
task.spawn(function()
	local setRole = ReplicatedStorage:WaitForChild("CaveHunt_SetRole", 30)
	if not setRole then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CaveHunt_UI"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -16, 0, 16)
	button.Size = UDim2.fromOffset(170, 40)
	button.BackgroundColor3 = Color3.fromRGB(40, 12, 12)
	button.BackgroundTransparency = 0.15
	button.TextColor3 = Color3.fromRGB(255, 222, 210)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	local function refresh()
		button.Text = isMonster() and "Play as Hider" or "Play as Monster"
	end
	refresh()
	player:GetAttributeChangedSignal("Role"):Connect(refresh)
	button.Activated:Connect(function()
		setRole:FireServer(isMonster() and "Hider" or "Monster")
	end)
end)

-- messages at the top of the screen ("Bob is calling you!") and the roar's screen shake
task.spawn(function()
	local notify = ReplicatedStorage:WaitForChild("CaveHunt_Notify", 30)
	local shake = ReplicatedStorage:WaitForChild("CaveHunt_Shake", 30)
	if not (notify and shake) then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CaveHunt_Toast"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 70)
	toast.Size = UDim2.fromOffset(360, 40)
	toast.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	toast.BackgroundTransparency = 0.2
	toast.TextColor3 = Color3.fromRGB(235, 235, 240)
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 18
	toast.Visible = false
	toast.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toast
	local shown = 0
	local function show(text)
		shown += 1
		local mine = shown
		toast.Text = text
		toast.Visible = true
		task.delay(3, function()
			if shown == mine then
				toast.Visible = false
			end
		end)
	end
	notify.OnClientEvent:Connect(show)
	shake.OnClientEvent:Connect(function()
		show("The monster roared nearby!")
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local stopAt = os.clock() + 1.2
		while os.clock() < stopAt do
			humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 1.2
			RunService.RenderStepped:Wait()
		end
		humanoid.CameraOffset = Vector3.new()
	end)
end)

-- Flashlight: F, the on-screen "Light" button, or L1 switches it on and off
task.spawn(function()
	local toggle = ReplicatedStorage:WaitForChild("CaveHunt_ToggleFlashlight", 30)
	if not toggle or toggle:GetAttribute("UsingToolFlashlight") then
		return -- a flashlight Tool from StarterPack is being used instead
	end
	ContextActionService:BindAction("CaveHunt_Flashlight", function(_, state)
		if toggle:GetAttribute("UsingToolFlashlight") then
			return Enum.ContextActionResult.Pass
		end
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

-- the monster sees "Search" on hiding spots instead of "Hide"
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Name == "HidePrompt" and isMonster() then
		prompt.ActionText = "Search"
	end
end)

-- Cave mood: near-black, short fog and a washed-out, contrasty grade while you're
-- inside the cave's rock block (a dim red night vision for the monster).
-- Everything goes back to normal when you leave.
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "CaveHunt_Grade"
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
	if saved then -- put things back first
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
	if on then
		local monster = isMonster()
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
		Lighting.Ambient = monster and Color3.fromRGB(46, 16, 16) or Color3.fromRGB(2, 2, 4)
		Lighting.OutdoorAmbient = monster and Color3.fromRGB(46, 16, 16) or Color3.fromRGB(4, 4, 6)
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0.1
		Lighting.FogColor = monster and Color3.fromRGB(20, 4, 4) or Color3.fromRGB(5, 5, 7)
		Lighting.FogStart = 0
		Lighting.FogEnd = monster and 180 or 90
		if atmosphere then -- with an Atmosphere, Roblox ignores the Fog settings, so darken it instead
			saved.atmosphere = {
				Density = atmosphere.Density,
				Offset = atmosphere.Offset,
				Color = atmosphere.Color,
				Decay = atmosphere.Decay,
				Glare = atmosphere.Glare,
				Haze = atmosphere.Haze,
			}
			atmosphere.Density = monster and 0.35 or 0.62
			atmosphere.Offset = 0
			atmosphere.Color = monster and Color3.fromRGB(40, 8, 8) or Color3.fromRGB(14, 14, 18)
			atmosphere.Decay = monster and Color3.fromRGB(20, 4, 4) or Color3.fromRGB(8, 8, 10)
			atmosphere.Glare = 0
			atmosphere.Haze = 0
		end
		grade.Contrast = 0.18
		grade.Saturation = monster and -0.7 or -0.4
		grade.Brightness = -0.02
		grade.TintColor = monster and Color3.fromRGB(255, 200, 200) or Color3.fromRGB(222, 230, 255)
	end
	grade.Enabled = on
	bloom.Enabled = on
end

local inCave = false
player:GetAttributeChangedSignal("Role"):Connect(function()
	if inCave then
		setCaveMood(true) -- switch between hider and monster vision
	end
end)
task.spawn(function()
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

-- Hotbar items. Picking one (its number key, or clicking its slot) uses it straight away and
-- puts it back; while it's recharging, its slot counts down the seconds.
local ITEM_PREFIX = [==[
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local tool = script.Parent
local NAME = tool.Name
local readyAt = 0

local function cooldown(seconds)
	readyAt = os.clock() + seconds
	task.spawn(function()
		while os.clock() < readyAt do
			tool.Name = ("%s (%d)"):format(NAME, math.ceil(readyAt - os.clock()))
			task.wait(0.25)
		end
		tool.Name = NAME
	end)
end

local function onUse(use)
	tool.Equipped:Connect(function()
		local character = tool.Parent
		if os.clock() >= readyAt then
			use(character)
		end
		task.defer(function()
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and tool.Parent == character then
				humanoid:UnequipTools()
			end
		end)
	end)
end
]==]

local ITEMS = {
	{
		name = "Leap",
		tip = "Lunge forward (6s)",
		source = [==[
onUse(function(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root then
		return
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local ahead = Vector3.new(look.X, 0, look.Z)
	ahead = ahead.Magnitude > 0.1 and ahead.Unit or root.CFrame.LookVector
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
	root.AssemblyLinearVelocity = ahead * 90 + Vector3.new(0, 55, 0)
	cooldown(6)
end)
]==],
	},
	{
		name = "Sense",
		tip = "See hiders through walls for 4s (15s)",
		source = [==[
local CollectionService = game:GetService("CollectionService")
onUse(function()
	local made = {}
	local function glow(target, color)
		local h = Instance.new("Highlight")
		h.FillColor = color
		h.OutlineColor = color
		h.FillTransparency = 0.55
		h.OutlineTransparency = 0
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Adornee = target
		h.Parent = target
		table.insert(made, h)
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other:GetAttribute("Role") ~= "Monster" and other.Character and not other:GetAttribute("Hidden") then
			glow(other.Character, Color3.fromRGB(255, 50, 40))
		end
	end
	for _, spot in ipairs(CollectionService:GetTagged("HidingSpot")) do
		if spot:GetAttribute("Occupied") then
			glow(spot, Color3.fromRGB(255, 190, 40)) -- someone is in there
		end
	end
	task.delay(4, function()
		for _, h in ipairs(made) do
			h:Destroy()
		end
	end)
	cooldown(15)
end)
]==],
	},
	{
		name = "Scent",
		tip = "Smell where hiders walked in the last 30s (20s)",
		source = [==[
local MEMORY = 30
local trails = {}
task.spawn(function() -- keep remembering where everyone walked
	while tool.Parent do
		for _, other in ipairs(Players:GetPlayers()) do
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if other ~= player and other:GetAttribute("Role") ~= "Monster" and root then
				local list = trails[other] or {}
				trails[other] = list
				local last = list[#list]
				if not last or (last.pos - root.Position).Magnitude > 3 then
					table.insert(list, { pos = root.Position, t = os.clock() })
				end
			end
		end
		for other, list in pairs(trails) do
			while list[1] and os.clock() - list[1].t > MEMORY do
				table.remove(list, 1)
			end
			if not other.Parent then
				trails[other] = nil
			end
		end
		task.wait(0.4)
	end
end)
onUse(function()
	local folder = Instance.new("Folder")
	folder.Name = "CaveHunt_Scent"
	for _, list in pairs(trails) do
		for _, point in ipairs(list) do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromRGB(110, 255, 140)
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.new(0.7, 0.7, 0.7)
			p.Transparency = 0.25 + 0.6 * (os.clock() - point.t) / MEMORY -- older = fainter
			p.CFrame = CFrame.new(point.pos - Vector3.new(0, 2.4, 0))
			p.Parent = folder
		end
	end
	folder.Parent = workspace
	game:GetService("Debris"):AddItem(folder, 8)
	cooldown(20)
end)
]==],
	},
	{
		name = "Roar",
		tip = "Shake nearby hiders and knock out their lights for 5s (25s)",
		source = [==[
local roar = game:GetService("ReplicatedStorage"):WaitForChild("CaveHunt_Roar")
onUse(function()
	roar:FireServer()
	cooldown(25)
end)
]==],
	},
	{
		name = "Phone",
		tip = "Ring another hider's phone (8s)",
		source = [==[
local ring = game:GetService("ReplicatedStorage"):WaitForChild("CaveHunt_Ring")
local picker
local function close()
	if picker then
		picker:Destroy()
		picker = nil
	end
end
onUse(function()
	close()
	local people = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other:GetAttribute("Role") ~= "Monster" then
			table.insert(people, other)
		end
	end
	picker = Instance.new("ScreenGui")
	picker.Name = "CaveHunt_Phone"
	picker.ResetOnSpawn = false
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -110)
	frame.Size = UDim2.fromOffset(240, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	frame.BackgroundTransparency = 0.1
	frame.Parent = picker
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	local function row(text, color, order, onClick)
		local b = Instance.new(onClick and "TextButton" or "TextLabel")
		b.Size = UDim2.new(1, 0, 0, 34)
		b.BackgroundColor3 = color
		b.BackgroundTransparency = onClick and 0 or 1
		b.TextColor3 = Color3.fromRGB(235, 235, 240)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 16
		b.Text = text
		b.LayoutOrder = order
		b.Parent = frame
		if onClick then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = b
			b.Activated:Connect(onClick)
		end
	end
	row(#people > 0 and "Who do you want to call?" or "No one to call", Color3.new(), 0)
	for i, other in ipairs(people) do
		row(other.DisplayName, Color3.fromRGB(40, 70, 120), i, function()
			ring:FireServer(other)
			close()
			cooldown(8)
		end)
	end
	row("Hang up", Color3.fromRGB(90, 30, 30), #people + 1, close)
	picker.Parent = player:WaitForChild("PlayerGui")
end)
]==],
	},
}

local function run()
	local ok, err = pcall(function()
		local ServerScriptService = game:GetService("ServerScriptService")
		local ServerStorage = game:GetService("ServerStorage")
		local items = ServerStorage:FindFirstChild("CaveHunt_Tools")
		if items then
			items:Destroy()
		end
		items = Instance.new("Folder")
		items.Name = "CaveHunt_Tools"
		for _, item in ipairs(ITEMS) do
			local tool = Instance.new("Tool")
			tool.Name = item.name
			tool.ToolTip = item.tip
			tool.RequiresHandle = false
			tool.CanBeDropped = false
			local s = Instance.new("LocalScript")
			s.Name = "Use"
			s.Source = ITEM_PREFIX .. item.source
			s.Parent = tool
			tool.Parent = items
		end
		items.Parent = ServerStorage
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
		local oldFlashlights = ServerScriptService:FindFirstChild("CaveHunt_Flashlights") -- merged into CaveHunt_Players
		if oldFlashlights then
			oldFlashlights:Destroy()
		end
		install(ServerScriptService, "Script", "CaveHunt_Players", SOURCES.Players)
		install(ServerScriptService, "Script", "CaveHunt_Hiding", SOURCES.Hiding)
		install(playerScripts, "LocalScript", "CaveHunt_Client", SOURCES.Client)
	end)
	if not ok then
		warn("[GameScripts] Something went wrong. Copy this message and send it to Claude:\n" .. tostring(err))
		return false
	end
	print("[GameScripts] Installed: same-size hiders with their own heads, flashlights (F), hiding (E), phones, the monster and its abilities (button in the top-right corner), and the cave mood. Press Play to try them.")
	return true
end

-- Loaded as a ModuleScript (the GitHub one-liner): hand back run. Pasted straight into the Command Bar: just run it.
if script then
	return run
end
return run()
