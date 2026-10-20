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
	      * switches players between hider, monster and spectator for
	        CaveHunt_Rounds (ServerStorage.CaveHunt_Roles)
	  ServerStorage.CaveHunt_Tools
	      the hotbar items. Hiders get a Phone (ring another hider: their
	      phone rings out loud and flashes, even inside a closet). The
	      monster gets Leap, Sense (see hiders through walls), Scent (see
	      where hiders walked) and Roar (shake hiders, knock out their lights).
	      Picking an item uses it; its slot counts down while it recharges.
	      The shop's troll items live here too (Price and Who attributes)
	  ServerScriptService.CaveHunt_Shop
	      coins (on the leaderboard), the shop, the troll items, phone calls
	      and the glowing coins lying around the cave
	  ServerScriptService.CaveHunt_Rounds
	      rounds (one monster, everyone else hides; the monster waits
	      blindfolded while they hide), caught hiders spectate until the round
	      ends, and admin commands: the Admin button or chat ;restart ;monster
	      ;hider ;spectate ;end ;start
	  ServerScriptService.CaveHunt_Hiding
	      hiders press E at any HidingSpot to hide inside it (invisible, light
	      off) and E again to come out. The monster pressing E on a hiding
	      spot ("Search") throws whoever is inside out
	  StarterPlayerScripts.CaveHunt_Client
	      the round timer, the shop and Admin buttons, spectate mode, flashlight
	      aiming, the cave mood (only while you're inside the cave; red night
	      vision for the monster) and flickering lights

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

-- walking / sprinting (Shift, uses stamina) / crouching (C) speeds
local HIDER_SPEEDS = { walk = 16, sprint = 24, crouch = 8 }
local MONSTER_SPEEDS = { walk = 20, sprint = 30, crouch = 10 }
local MONSTER_HEIGHT = 10 -- studs (hiders are about 5). Taller won't fit the tunnels; shack doors are 7.5
local MONSTER_SCALE = 1.9 -- the built-in monster (your own character in black) is this much bigger than a hider
local PUNCH_COOLDOWN = 1 -- seconds between the monster's punches
local PUNCH_REACH = 5 -- studs in front of the monster, on top of its own size
local LIGHT = Color3.fromRGB(255, 238, 210)
local ROAR_COOLDOWN = 25
local ROAR_RANGE = 140
-- built-in Roblox sounds; swap in any sound you like, e.g. "rbxassetid://1234567"
local ROAR_SOUND = "rbxasset://sounds/uuhhh.mp3"
local PUNCH_SOUND = "rbxasset://sounds/action_jump.mp3" -- (the old built-in swoosh.wav is blocked by Roblox now)
local HIT_SOUND = "rbxasset://sounds/action_jump_land.mp3"

local function remote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local toggleLight = remote("CaveHunt_ToggleFlashlight")
local roarRemote = remote("CaveHunt_Roar")
local punchRemote = remote("CaveHunt_Punch")
local shakeRemote = remote("CaveHunt_Shake")
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
local function clearTools(player) -- items bought in the shop are kept (CaveHunt_Shop looks after those)
	for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if holder then
			for _, tool in ipairs(holder:GetChildren()) do
				if tool:IsA("Tool") and not tool:GetAttribute("Item") then
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

-- the client's movement script reads these (sprinting and crouching happen on the client)
local function setSpeeds(character, speeds)
	character:SetAttribute("WalkSpeed", speeds.walk)
	character:SetAttribute("SprintSpeed", speeds.sprint)
	character:SetAttribute("CrouchSpeed", speeds.crouch)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speeds.walk
	end
end

local function setupHider(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	pcall(function()
		humanoid:ApplyDescription(hiderLook(player))
	end)
	setSpeeds(character, HIDER_SPEEDS)
	player.CameraMinZoomDistance = 0.5
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
	character:SetAttribute("Reach", PUNCH_REACH + character:GetExtentsSize().Y * 0.3) -- bigger monsters reach further
	clearTools(player) -- no flashlight or phone for the monster
	giveTools(player, MONSTER_TOOLS)
	setSpeeds(character, MONSTER_SPEEDS)
	-- the camera stays far enough back to see the monster's whole body
	player.CameraMinZoomDistance = math.max(8, character:GetExtentsSize().Y * 1.1)
end

------------------------------------------------------------------ the monster's punch
-- the monster has to hit a hider (click, R2, or the Hit button) to catch them: the closest one in
-- front of it, within reach, that isn't hiding, and not through a wall
local TweenService = game:GetService("TweenService")

-- swing the monster's right arm by turning its shoulder joint, so it works on any rig (no animation needed)
local function armJoint(character)
	local named = character:FindFirstChild("RightShoulder", true) or character:FindFirstChild("Right Shoulder", true)
	if named and named:IsA("Motor6D") then
		return named
	end
	for _, pass in ipairs({ "right", "" }) do -- a custom rig: a joint that moves a (right) arm or hand
		for _, d in ipairs(character:GetDescendants()) do
			local n = d:IsA("Motor6D") and d.Part1 and d.Part1.Name:lower() or ""
			if n:find(pass, 1, true) and (n:find("arm") or n:find("hand")) then
				return d
			end
		end
	end
	return nil
end

local function swingArm(character)
	local joint = armJoint(character)
	if not joint or joint:GetAttribute("Swinging") then
		return
	end
	joint:SetAttribute("Swinging", true)
	local rest = joint.C0
	-- an R6 shoulder turns about its Z axis, everything else about X
	local raised = joint.Name == "Right Shoulder" and rest * CFrame.Angles(0, 0, math.rad(100)) or rest * CFrame.Angles(math.rad(100), 0, 0)
	TweenService:Create(joint, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = raised }):Play()
	task.delay(0.15, function()
		TweenService:Create(joint, TweenInfo.new(0.25), { C0 = rest }):Play()
		task.wait(0.3)
		joint:SetAttribute("Swinging", nil)
	end)
end

-- three red claw marks flash in front of the monster, so everyone sees the swing
local function clawMarks(root, reach, look)
	local base = CFrame.lookAt(root.Position, root.Position + look) * CFrame.new(0, 0.5, -reach * 0.55)
	for i = -1, 1 do
		local claw = Instance.new("Part")
		claw.Name = "MonsterClaw"
		claw.Anchored = true
		claw.CanCollide = false
		claw.CanQuery = false
		claw.CanTouch = false
		claw.CastShadow = false
		claw.Material = Enum.Material.Neon
		claw.Color = Color3.fromRGB(255, 60, 50)
		claw.Transparency = 0.3
		claw.Size = Vector3.new(reach * 0.8, 0.15, 0.15)
		claw.CFrame = base * CFrame.new(0, i * 0.7, 0) * CFrame.Angles(0, 0, math.rad(35))
		claw.Parent = workspace
		TweenService:Create(claw, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		Debris:AddItem(claw, 0.35)
	end
end

local function playSound(parent, id, speed, volume)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed
	s.Volume = volume
	s.RollOffMaxDistance = 120
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 3)
end

local lastPunch = {}
punchRemote.OnServerEvent:Connect(function(player, animated)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if player:GetAttribute("Role") ~= "Monster" or not root or os.clock() - (lastPunch[player] or -math.huge) < PUNCH_COOLDOWN * 0.8 then
		return
	end
	lastPunch[player] = os.clock()
	local reach = character:GetAttribute("Reach") or 8
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	playSound(root, PUNCH_SOUND, 0.6, 1.5)
	if animated ~= true then -- (your own punch animation, if you set one, already moves the arm)
		swingArm(character)
	end
	clawMarks(root, reach, look)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local best, bestDistance
	for _, other in ipairs(Players:GetPlayers()) do
		local otherCharacter = other.Character
		local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
		local humanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
		if other ~= player and other:GetAttribute("Role") == "Hider" and not other:GetAttribute("Hidden") and otherRoot and humanoid and humanoid.Health > 0 then
			local offset = otherRoot.Position - root.Position
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			local distance = flatOffset.Magnitude
			local inFront = distance < 2 or flatOffset.Unit:Dot(look) > 0.3
			if distance <= reach and math.abs(offset.Y) < reach and inFront and (not best or distance < bestDistance) then
				params.FilterDescendantsInstances = { character, otherCharacter }
				if not workspace:Raycast(root.Position, offset, params) then -- nothing in between
					best, bestDistance = other, distance
				end
			end
		end
	end
	if best then
		local humanoid = best.Character:FindFirstChildOfClass("Humanoid")
		playSound(best.Character.HumanoidRootPart, HIT_SOUND, 0.5, 2)
		humanoid.Health = 0
		local reward = ServerStorage:FindFirstChild("CaveHunt_Reward") -- coins, from CaveHunt_Shop
		if reward then
			reward:Fire(player, "Catch")
		end
	end
end)

-- your monster model: ServerStorage.Monster, or the model GameScripts found in your Workspace and moved
-- to ServerStorage for you (it has the CaveHuntMonster attribute)
local function monsterTemplate()
	local named = ServerStorage:FindFirstChild("Monster")
	if named and named:IsA("Model") then
		return named
	end
	for _, d in ipairs(ServerStorage:GetChildren()) do
		if d:IsA("Model") and d:GetAttribute("CaveHuntMonster") then
			return d
		end
	end
	return nil
end

local function stopScripts(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") then
			d.Enabled = false -- its own AI/movement/animation scripts would fight the player's controls
		end
	end
end

local function sizeToMonster(model) -- grown or shrunk to MONSTER_HEIGHT
	local height = model:GetExtentsSize().Y
	if height > 0.5 then
		pcall(function()
			model:ScaleTo(model:GetScale() * math.clamp(MONSTER_HEIGHT / height, 0.25, 6))
		end)
	end
end

-- a model that isn't a rigged character: your character wears it like a costume (welded on, your
-- own body hidden, your character scaled to about its height so it bumps into walls like it looks)
local function wearCostume(character, template)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) then
		return
	end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Accessory") then
			d:Destroy()
		elseif d:IsA("BasePart") or d:IsA("Decal") then
			d.Transparency = 1
		end
	end
	local costume = template:Clone()
	costume.Name = "MonsterCostume"
	stopScripts(costume)
	sizeToMonster(costume)
	pcall(function()
		character:ScaleTo(math.clamp(costume:GetExtentsSize().Y / 5, 0.6, 2.2))
	end)
	-- stand it on the character's feet, facing the same way
	local look = root.CFrame.LookVector
	local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0)
	local pivot = costume:GetPivot()
	costume:PivotTo(CFrame.lookAt(pivot.Position, pivot.Position + Vector3.new(look.X, 0, look.Z)))
	local boxCFrame, boxSize = costume:GetBoundingBox()
	local bottom = boxCFrame.Position - Vector3.new(0, boxSize.Y / 2, 0)
	costume:PivotTo(costume:GetPivot() + (feet - bottom))
	for _, part in ipairs(costume:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	costume.Parent = character
end

local converting = {}
local function becomeMonster(player)
	if converting[player] then
		return
	end
	converting[player] = true
	player:SetAttribute("Role", "Monster")
	local ok, err = pcall(function()
		local template = monsterTemplate()
		local spawnAt = monsterSpawn()
		-- start from a normal character: it brings the Backpack and Roblox's standard walk animations
		player:LoadCharacter()
		local character = player.Character or player.CharacterAdded:Wait()
		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local templateHumanoid = template and template:FindFirstChildOfClass("Humanoid")
		if template and templateHumanoid and template:FindFirstChild("HumanoidRootPart") then
			-- your rigged monster: you play as it
			local body = template:Clone()
			stopScripts(body)
			for _, d in ipairs(body:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = false
				end
			end
			-- animations made by someone else don't load in your game, so a body built like a
			-- normal Roblox character gets Roblox's standard ones (KeepAnimations = true keeps its own)
			local animate = character:FindFirstChild("Animate")
			if animate and humanoid and templateHumanoid.RigType == humanoid.RigType and not template:GetAttribute("KeepAnimations") then
				local own = body:FindFirstChild("Animate")
				if own then
					own:Destroy()
				end
				animate:Clone().Parent = body
			end
			sizeToMonster(body)
			if not templateHumanoid:FindFirstChildOfClass("Animator") then
				Instance.new("Animator").Parent = body:FindFirstChildOfClass("Humanoid") -- so its walk/run (and punch) animations show for everyone
			end
			body.Name = player.Name
			body:PivotTo(spawnAt or character:GetPivot())
			player.Character = body
			body.Parent = workspace
			character:Destroy()
			setupMonster(player, body)
		else
			if template then
				wearCostume(character, template)
			else
				monsterize(character) -- no model of yours: your own character in black with red eyes
			end
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

local function becomeSpectator(player) -- no body; the client watches the others
	player:SetAttribute("Role", "Spectator")
	local character = player.Character
	player.Character = nil
	if character then
		character:Destroy()
	end
end

-- CaveHunt_Rounds (or your own scripts) switch roles with
-- ServerStorage.CaveHunt_Roles:Invoke(player, "Monster" / "Hider" / "Spectator")
local roles = ServerStorage:FindFirstChild("CaveHunt_Roles") or Instance.new("BindableFunction")
roles.Name = "CaveHunt_Roles"
roles.OnInvoke = function(player, role)
	if role == "Monster" then
		becomeMonster(player)
	elseif role == "Hider" then
		becomeHider(player)
	elseif role == "Spectator" then
		becomeSpectator(player)
	end
	return true
end
roles.Parent = ServerStorage

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

------------------------------------------------------------------ joining + respawning
local function onPlayer(player)
	if player:GetAttribute("Role") == nil then
		player:SetAttribute("Role", "Hider")
	end
	player.DevEnableMouseLock = false -- Shift is sprint, not shift lock
	player.CharacterAppearanceLoaded:Connect(function(character)
		if player:GetAttribute("Role") == "Hider" then
			setupHider(player, character)
		end
	end)
	player.CharacterAdded:Connect(function(character)
		-- the monster respawning after dying comes back as the monster
		if player:GetAttribute("Role") == "Monster" and not converting[player] and not character:GetAttribute("IsMonster") then
			task.defer(becomeMonster, player)
		end
	end)
	if player.Character and player:HasAppearanceLoaded() and player:GetAttribute("Role") == "Hider" then
		task.spawn(setupHider, player, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	looks[player] = nil
	converting[player] = nil
	lastRoar[player] = nil
	lastPunch[player] = nil
end)
]==]

SOURCES.Hiding = [==[
-- CaveHunt: hiders press E at any HidingSpot (CollectionService tag) to hide inside it,
-- and E again to come out. The monster pressing E on a spot throws whoever is inside out.
-- ServerStorage.CaveHunt_KnockOut:Invoke(spot) does the same from other scripts.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local hiding = {} -- player -> { spot = Model, prompt = ProximityPrompt, saved = {} }

local function tell(player, text)
	local notify = ReplicatedStorage:FindFirstChild("CaveHunt_Notify")
	if notify then
		notify:FireClient(player, text)
	end
end

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
	h.spot:SetAttribute("OccupantId", nil)
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
	if (spot:GetAttribute("LockedUntil") or 0) > workspace:GetServerTimeNow() then -- a Spot Lock from the shop
		tell(player, "It's jammed! Try again in a few seconds.")
		return
	end
	local saved = {}
	hiding[player] = { spot = spot, prompt = prompt, saved = saved }
	player:SetAttribute("Hidden", true)
	spot:SetAttribute("Occupied", true)
	spot:SetAttribute("OccupantId", player.UserId)
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
			local found = knockOut(spot) -- the monster searches the spot
			if found then
				local reward = ServerStorage:FindFirstChild("CaveHunt_Reward") -- coins, from CaveHunt_Shop
				if reward then
					reward:Fire(player, "Find")
				end
				tell(found, "The monster found you! RUN!")
			elseif spot:GetAttribute("FakeOccupied") then
				tell(player, "Nobody in there. It was a decoy!")
			end
			spot:SetAttribute("FakeOccupied", nil) -- a Fake Hider from the shop
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

SOURCES.Shop = [==[
-- CaveHunt: coins, the shop, the troll items, phone calls and the coins lying around the cave.
-- Each item's price, who can buy it and its description are on its Tool in
-- ServerStorage.CaveHunt_Tools (the Price and Who attributes, and ToolTip).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local FREE_SHOP = true -- for testing: everything in the shop costs nothing. false = charge each item's Price
local START_COINS = 40
local INCOME = 1 -- every hider in the cave earns this many coins...
local INCOME_EVERY = 5 -- ...every this many seconds
local REWARDS = { Catch = 15, Find = 5, Win = 25, Survive = 25 } -- the monster: a catch, pulling one out of a spot, catching everyone; hiders: surviving a round
local PICKUPS = 10 -- glowing coins lying around the cave (hiders pick them up)
local PICKUP_VALUE = 5
local PHONE_COOLDOWN = 8
-- built-in Roblox sounds; swap in any sound you like, e.g. "rbxassetid://1234567"
local RINGTONE = "rbxasset://sounds/electronicpingshort.wav"
local AIRHORN_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local SLIP_SOUND = "rbxasset://sounds/action_jump_land.mp3"

local function remote(name, className)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new(className or "RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local notify = remote("CaveHunt_Notify")
local shake = remote("CaveHunt_Shake")
local ringRemote = remote("CaveHunt_Ring")
local useRemote = remote("CaveHunt_UseItem")
local reveal = remote("CaveHunt_Reveal")
local buy = remote("CaveHunt_Buy", "RemoteFunction")

-- other scripts give out coins with ServerStorage.CaveHunt_Reward:Fire(player, "Catch" or "Find")
local reward = ServerStorage:FindFirstChild("CaveHunt_Reward")
if not reward then
	reward = Instance.new("BindableEvent")
	reward.Name = "CaveHunt_Reward"
	reward.Parent = ServerStorage
end

------------------------------------------------------------------ the catalog
-- the shop sells every Tool in CaveHunt_Tools that has a Price; the client reads ReplicatedStorage.CaveHunt_Shop
local SHOP = {}
local catalog = Instance.new("Folder")
catalog.Name = "CaveHunt_Shop"
local templates = ServerStorage:WaitForChild("CaveHunt_Tools", 10)
for _, tool in ipairs(templates and templates:GetChildren() or {}) do
	local key, price = tool:GetAttribute("Item"), tool:GetAttribute("Price")
	if tool:IsA("Tool") and type(key) == "string" and type(price) == "number" then
		local item = { key = key, template = tool, name = tool.Name, price = FREE_SHOP and 0 or price, who = tool:GetAttribute("Who") or "Any" }
		SHOP[key] = item
		local entry = Instance.new("Configuration")
		entry.Name = key
		entry:SetAttribute("Name", item.name)
		entry:SetAttribute("Price", item.price)
		entry:SetAttribute("Who", item.who)
		entry:SetAttribute("Tip", tool.ToolTip)
		entry:SetAttribute("Order", tool:GetAttribute("Order") or 99)
		entry.Parent = catalog
	end
end
local oldCatalog = ReplicatedStorage:FindFirstChild("CaveHunt_Shop")
if oldCatalog then
	oldCatalog:Destroy()
end
catalog.Parent = ReplicatedStorage

------------------------------------------------------------------ helpers
local function alive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, humanoid, root
	end
	return nil
end

local function isHider(p)
	return typeof(p) == "Instance" and p:IsA("Player") and p.Parent == Players and p:GetAttribute("Role") == "Hider"
end

local function allowed(item, player)
	return item.who ~= "Hider" or player:GetAttribute("Role") ~= "Monster"
end

-- the character a touching part belongs to (works for monster models with nested parts too)
local function characterFrom(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model
end

local function spotPosition(spot)
	local point = spot:FindFirstChild("HidePoint", true)
	return point and point.Position or spot:GetPivot().Position
end

local function nearestSpot(from, range, wanted)
	local best, bestDistance = nil, range
	for _, spot in ipairs(CollectionService:GetTagged("HidingSpot")) do
		if spot:IsDescendantOf(workspace) and (not wanted or wanted(spot)) then
			local d = (spotPosition(spot) - from).Magnitude
			if d < bestDistance then
				best, bestDistance = spot, d
			end
		end
	end
	return best
end

local function spotOf(player) -- the hiding spot someone is in
	for _, spot in ipairs(CollectionService:GetTagged("HidingSpot")) do
		if spot:GetAttribute("OccupantId") == player.UserId then
			return spot
		end
	end
	return nil
end

local function label(parent, text, color, seconds, height)
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(140, 40)
	tag.StudsOffset = Vector3.new(0, height or 3, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 90
	tag.LightInfluence = 0
	local words = Instance.new("TextLabel")
	words.Size = UDim2.fromScale(1, 1)
	words.BackgroundTransparency = 1
	words.Text = text
	words.TextScaled = true
	words.Font = Enum.Font.GothamBlack
	words.TextColor3 = color
	words.TextStrokeTransparency = 0.3
	words.Parent = tag
	tag.Parent = parent
	Debris:AddItem(tag, seconds)
	return tag
end

local function playSound(parent, id, seconds, volume, speed, looped)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed or 1
	sound.Looped = looped or false
	sound.RollOffMaxDistance = 300
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, seconds)
	return sound
end

------------------------------------------------------------------ coins
local function coinsOf(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Coins")
end

local function addCoins(player, n, why)
	local coins = coinsOf(player)
	if coins then
		coins.Value += n
		if why then
			notify:FireClient(player, ("+%d coins: %s"):format(n, why))
		end
	end
end

reward.Event:Connect(function(player, kind)
	local why = { Catch = "you caught a hider", Find = "you found a hider", Win = "you caught everyone", Survive = "you survived the round" }
	if typeof(player) == "Instance" and player:IsA("Player") and REWARDS[kind] then
		addCoins(player, REWARDS[kind], why[kind])
	end
end)

local function inCave(position)
	local cave = workspace:FindFirstChild("CaveSystem")
	local center = cave and cave:GetAttribute("BoxCenter")
	local size = cave and cave:GetAttribute("BoxSize")
	if not (center and size) then
		return true
	end
	local d = position - center
	return math.abs(d.X) < size.X / 2 and math.abs(d.Y) < size.Y / 2 and math.abs(d.Z) < size.Z / 2
end

task.spawn(function() -- hiders earn coins for staying alive in the cave
	while true do
		task.wait(INCOME_EVERY)
		for _, player in ipairs(Players:GetPlayers()) do
			local _, _, root = alive(player)
			if root and player:GetAttribute("Role") ~= "Monster" and inCave(root.Position) then
				addCoins(player, INCOME)
			end
		end
	end
end)

-- glowing coins in front of random hiding spots; hiders grab them by walking into them
local pickupAt = {} -- hiding spot -> coin
local function spawnPickup()
	local spots = CollectionService:GetTagged("HidingSpot")
	if #spots == 0 then
		return
	end
	local spot = spots[math.random(1, #spots)]
	local exit = spot:FindFirstChild("ExitPoint", true)
	if not exit or pickupAt[spot] or not spot:IsDescendantOf(workspace) then
		return
	end
	local coin = Instance.new("Part")
	coin.Name = "CaveCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.3, 1.8, 1.8)
	coin.Color = Color3.fromRGB(255, 196, 40)
	coin.Material = Enum.Material.Metal
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CastShadow = false
	coin.CFrame = CFrame.new(exit.Position - Vector3.new(0, 1, 0))
	local glow = Instance.new("PointLight")
	glow.Color = coin.Color
	glow.Range = 7
	glow.Brightness = 0.7
	glow.Parent = coin
	coin.Parent = workspace
	CollectionService:AddTag(coin, "CaveCoin")
	pickupAt[spot] = coin
	coin.Touched:Connect(function(part)
		local character = characterFrom(part)
		local who = character and Players:GetPlayerFromCharacter(character)
		if who and who:GetAttribute("Role") ~= "Monster" and coin.Parent and alive(who) then
			coin:Destroy()
			pickupAt[spot] = nil
			addCoins(who, PICKUP_VALUE, "you found a coin")
		end
	end)
end

task.spawn(function()
	task.wait(3) -- let the cave and its hiding spots load
	while true do
		local count = 0
		for spot, coin in pairs(pickupAt) do
			if coin.Parent then
				count += 1
			else
				pickupAt[spot] = nil
			end
		end
		for _ = count + 1, PICKUPS do
			spawnPickup()
		end
		task.wait(20)
	end
end)

------------------------------------------------------------------ phones
-- a phone rings out loud and flashes on `part` (a hider's head, or a Fake Noise)
local function ringAt(part, seconds)
	if part:FindFirstChild("Ringtone") then
		return false
	end
	local sound = playSound(part, RINGTONE, seconds, 2, 1, true)
	sound.Name = "Ringtone"
	sound.RollOffMaxDistance = 150
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(120, 180, 255)
	glow.Range = 12
	glow.Brightness = 2
	glow.Parent = part
	Debris:AddItem(glow, seconds)
	label(part, "RING RING", Color3.fromRGB(140, 200, 255), seconds)
	task.spawn(function()
		while glow.Parent do
			glow.Enabled = not glow.Enabled
			task.wait(0.25)
		end
	end)
	return true
end

-- the Phone: ring another hider. It rings for 4 seconds, even inside a closet
local lastCall = {}
ringRemote.OnServerEvent:Connect(function(caller, target)
	if not isHider(caller) or not isHider(target) or target == caller then
		return
	end
	if os.clock() - (lastCall[caller] or -math.huge) < PHONE_COOLDOWN - 1 then
		return
	end
	local head = target.Character and target.Character:FindFirstChild("Head")
	if head and ringAt(head, 4) then
		lastCall[caller] = os.clock()
		notify:FireClient(target, caller.DisplayName .. " is calling you!")
		notify:FireClient(caller, "Calling " .. target.DisplayName .. "...")
	end
end)

------------------------------------------------------------------ what each item does
-- each returns true when it worked (that uses up one charge)
local EFFECTS = {}
local WORKS_WHILE_HIDDEN = { Snitch = true, FakeNoise = true }

-- Snitch: the monster sees another hider (or the spot they're hiding in) for 5 seconds
function EFFECTS.Snitch(player, target)
	if not isHider(target) or target == player or not alive(target) then
		notify:FireClient(player, "Pick another hider.")
		return false
	end
	local monsters = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other:GetAttribute("Role") == "Monster" then
			table.insert(monsters, other)
		end
	end
	if #monsters == 0 then
		notify:FireClient(player, "There's no monster to tell right now.")
		return false
	end
	local where = (target:GetAttribute("Hidden") and spotOf(target)) or target.Character
	for _, monster in ipairs(monsters) do
		reveal:FireClient(monster, where, 5, "Someone snitched on " .. target.DisplayName .. "!")
	end
	notify:FireClient(target, "Someone snitched on you! The monster knows where you are.")
	notify:FireClient(player, "You snitched on " .. target.DisplayName .. ".")
	return true
end

-- Glowstick: thrown where you're looking; lights up the area for 25 seconds
function EFFECTS.Glowstick(player, aim)
	local character, _, root = alive(player)
	local head = character:FindFirstChild("Head") or root
	local dir = (typeof(aim) == "Vector3" and aim.Magnitude > 0.1) and aim.Unit or head.CFrame.LookVector
	local stick = Instance.new("Part")
	stick.Name = "Glowstick"
	stick.Size = Vector3.new(0.3, 0.3, 1.4)
	stick.Color = Color3.fromRGB(90, 255, 120)
	stick.Material = Enum.Material.Neon
	stick.CastShadow = false
	stick.CFrame = CFrame.lookAt(head.Position + dir * 2, head.Position + dir * 3)
	local light = Instance.new("PointLight")
	light.Color = stick.Color
	light.Range = 22
	light.Brightness = 1.2
	light.Parent = stick
	stick.Parent = workspace
	stick:SetNetworkOwner(nil)
	stick.AssemblyLinearVelocity = dir * 60 + Vector3.new(0, 18, 0)
	stick.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
	Debris:AddItem(stick, 25)
	return true
end

-- Fake Noise: a phone rings where you're aiming, for 5 seconds
function EFFECTS.FakeNoise(player, point)
	local _, _, root = alive(player)
	if typeof(point) ~= "Vector3" or (point - root.Position).Magnitude > 200 then
		return false
	end
	local source = Instance.new("Part")
	source.Name = "FakeNoise"
	source.Anchored = true
	source.CanCollide = false
	source.CanQuery = false
	source.CanTouch = false
	source.Transparency = 1
	source.Size = Vector3.new(1, 1, 1)
	source.Position = point
	source.Parent = workspace
	Debris:AddItem(source, 6)
	ringAt(source, 5)
	notify:FireClient(player, "A phone is ringing over there...")
	return true
end

-- Spot Lock: the nearest hiding spot is jammed for 10 seconds; nobody can get in
function EFFECTS.SpotLock(player)
	local _, _, root = alive(player)
	local now = workspace:GetServerTimeNow()
	local spot = nearestSpot(root.Position, 14, function(s)
		return (s:GetAttribute("LockedUntil") or 0) < now
	end)
	if not spot then
		notify:FireClient(player, "Stand next to a hiding spot to jam it.")
		return false
	end
	spot:SetAttribute("LockedUntil", now + 10)
	local anchor = spot:FindFirstChild("HidePoint", true) or spot.PrimaryPart or spot:FindFirstChildWhichIsA("BasePart", true)
	if anchor then
		label(anchor, "JAMMED", Color3.fromRGB(255, 90, 70), 10, 5)
	end
	notify:FireClient(player, "Jammed! Nobody can get in there for 10 seconds.")
	return true
end

-- Swap: you and another hider swap places
function EFFECTS.Swap(player, target)
	if not isHider(target) or target == player or not alive(target) then
		notify:FireClient(player, "Pick another hider.")
		return false
	end
	if target:GetAttribute("Hidden") then
		notify:FireClient(player, target.DisplayName .. " is hiding right now. Try again in a bit.")
		return false
	end
	local mine, theirs = player.Character:GetPivot(), target.Character:GetPivot()
	player.Character:PivotTo(theirs)
	target.Character:PivotTo(mine)
	notify:FireClient(target, player.DisplayName .. " swapped places with you!")
	notify:FireClient(player, "You swapped places with " .. target.DisplayName .. "!")
	return true
end

-- Banana Peel: dropped at your feet; the next person who steps on it (not you) slips for 2 seconds
local slipping = {}
local function slip(victim, humanoid, owner)
	if slipping[humanoid] then
		return
	end
	slipping[humanoid] = true
	local speed, power, height = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
	humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 0, 0, 0
	humanoid.Parent:SetAttribute("Stunned", true) -- the client's movement script holds you still
	humanoid.Sit = true
	local root = humanoid.Parent:FindFirstChild("HumanoidRootPart")
	if root then
		playSound(root, SLIP_SOUND, 3, 2, 0.8)
	end
	notify:FireClient(victim, "You slipped on " .. owner .. "'s banana peel!")
	task.delay(2, function()
		slipping[humanoid] = nil
		if humanoid.Parent then
			humanoid.Parent:SetAttribute("Stunned", nil)
		end
		if humanoid.Parent and humanoid.WalkSpeed == 0 then
			humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = speed, power, height
			humanoid.Sit = false
		end
	end)
end

function EFFECTS.Banana(player)
	local character, _, root = alive(player)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	if not hit then
		notify:FireClient(player, "Stand on the ground to drop it.")
		return false
	end
	local cf = CFrame.new(hit.Position) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local peel = Instance.new("Part")
	peel.Name = "BananaPeel"
	peel.Size = Vector3.new(1.6, 0.25, 0.9)
	peel.Color = Color3.fromRGB(245, 215, 60)
	peel.Material = Enum.Material.SmoothPlastic
	peel.Anchored = true
	peel.CanCollide = false
	peel.CanQuery = false
	peel.CFrame = cf * CFrame.new(0, 0.12, 0)
	local trigger = Instance.new("Part")
	trigger.Name = "Trigger"
	trigger.Size = Vector3.new(2.4, 2, 2.4)
	trigger.Transparency = 1
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.CFrame = cf * CFrame.new(0, 1, 0)
	trigger.Parent = peel
	peel.Parent = workspace
	Debris:AddItem(peel, 90)
	local owner = player.DisplayName
	trigger.Touched:Connect(function(part)
		local victimCharacter = characterFrom(part)
		local victim = victimCharacter and Players:GetPlayerFromCharacter(victimCharacter)
		local humanoid = victimCharacter and victimCharacter:FindFirstChildOfClass("Humanoid")
		if not victim or victim == player or not humanoid or humanoid.Health <= 0 or not peel.Parent then
			return
		end
		peel:Destroy()
		slip(victim, humanoid, owner)
		if player.Parent then
			notify:FireClient(player, victim.DisplayName .. " slipped on your banana peel!")
		end
	end)
	notify:FireClient(player, "Banana peel down. The next person to step on it slips.")
	return true
end

-- Air Horn: HONK. Everyone within 60 studs gets their screen shaken, and the monster hears it from far away
function EFFECTS.AirHorn(player)
	local character, _, root = alive(player)
	local horn = playSound(root, AIRHORN_SOUND, 1.5, 6, 0.3, true)
	horn.RollOffMaxDistance = 400
	label(character:FindFirstChild("Head") or root, "HONK!", Color3.fromRGB(255, 230, 80), 2.5)
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if otherRoot and (otherRoot.Position - root.Position).Magnitude < 60 then
			shake:FireClient(other, player.DisplayName .. " blasted an air horn!")
		end
	end
	return true
end

-- Fake Hider: the nearest empty hiding spot shows up as taken in the monster's Sense for 60 seconds
local decoys = {}
function EFFECTS.FakeHider(player)
	local _, _, root = alive(player)
	local spot = nearestSpot(root.Position, 20, function(s)
		return not s:GetAttribute("Occupied") and not s:GetAttribute("FakeOccupied")
	end)
	if not spot then
		notify:FireClient(player, "No empty hiding spot nearby.")
		return false
	end
	local token = {}
	decoys[spot] = token
	spot:SetAttribute("FakeOccupied", true)
	task.delay(60, function()
		if decoys[spot] == token then
			decoys[spot] = nil
			spot:SetAttribute("FakeOccupied", nil)
		end
	end)
	notify:FireClient(player, "Decoy set: the monster's Sense shows someone in that " .. tostring(spot:GetAttribute("HideType") or "spot") .. " for 60s.")
	return true
end

------------------------------------------------------------------ buying + using
local inventory = {} -- player -> { [item key] = charges }

-- make the hotbar match what you own: one Tool per item ("Glowstick x3"), only the ones your role can use
local function syncTools(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local bag = inventory[player] or {}
	local holders = { backpack }
	if player.Character then
		table.insert(holders, player.Character)
	end
	local have = {}
	for _, holder in ipairs(holders) do
		for _, tool in ipairs(holder:GetChildren()) do
			local key = tool:IsA("Tool") and tool:GetAttribute("Item")
			if key then
				local item = SHOP[key]
				if have[key] or not item or (bag[key] or 0) <= 0 or not allowed(item, player) then
					tool:Destroy()
				else
					have[key] = true
					tool:SetAttribute("Charges", bag[key])
				end
			end
		end
	end
	for key, n in pairs(bag) do
		local item = SHOP[key]
		if item and n > 0 and not have[key] and allowed(item, player) then
			local tool = item.template:Clone()
			tool:SetAttribute("Charges", n)
			tool.Parent = backpack
		end
	end
end

buy.OnServerInvoke = function(player, key)
	local item = type(key) == "string" and SHOP[key]
	if not item then
		return false, "That's not in the shop."
	end
	if not allowed(item, player) then
		return false, "Only hiders can use " .. item.name .. "."
	end
	local coins = coinsOf(player)
	if not coins or coins.Value < item.price then
		return false, "Not enough coins."
	end
	coins.Value -= item.price
	local bag = inventory[player] or {}
	inventory[player] = bag
	bag[key] = (bag[key] or 0) + 1
	syncTools(player)
	return true, ("Bought %s! It's in your hotbar."):format(item.name)
end

local lastUse = {}
useRemote.OnServerEvent:Connect(function(player, key, arg)
	local item = type(key) == "string" and SHOP[key]
	local bag = inventory[player]
	if not item or not EFFECTS[key] or not bag or (bag[key] or 0) <= 0 or not allowed(item, player) or not alive(player) then
		return
	end
	if os.clock() - (lastUse[player] or 0) < 0.5 then
		return
	end
	lastUse[player] = os.clock()
	if player:GetAttribute("Hidden") and not WORKS_WHILE_HIDDEN[key] then
		notify:FireClient(player, "You can't use that while you're hiding.")
		return
	end
	local ok, worked = pcall(EFFECTS[key], player, arg)
	if not ok then
		warn("[CaveHunt] " .. key .. " didn't work: " .. tostring(worked))
	elseif worked then
		bag[key] -= 1
		syncTools(player)
	end
end)

------------------------------------------------------------------ joining
local function onPlayer(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	if not stats:FindFirstChild("Coins") then
		local coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = START_COINS
		coins.Parent = stats
	end
	inventory[player] = inventory[player] or {}
	-- a respawn or a role switch empties the hotbar; put bought items back
	local function resync()
		task.delay(1, function()
			if player.Parent then
				syncTools(player)
			end
		end)
	end
	player.CharacterAdded:Connect(resync)
	player:GetAttributeChangedSignal("Role"):Connect(resync)
	resync()
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	inventory[player] = nil
	lastUse[player] = nil
	lastCall[player] = nil
end)
]==]

SOURCES.Rounds = [==[
-- CaveHunt: rounds, admin commands and spectating.
-- A round: one player is the monster and everyone else hides. The monster waits, frozen and
-- blindfolded, for HIDE_TIME while the hiders hide, then hunts for ROUND_TIME. Caught hiders
-- spectate until the round ends. Admins (everyone in Studio, the game's owner, and ADMINS below)
-- use the Admin button or chat commands that start with ";" (;restart ;monster ;hider ;spectate ;end ;start).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local HIDE_TIME = 20 -- seconds the hiders get before the monster is let loose
local ROUND_TIME = 300 -- how long the monster has to catch everyone
local INTERMISSION = 15 -- break between rounds
local AFTER_ROUND = 8 -- how long the result shows before everyone's back at Base Camp
local MIN_PLAYERS = 2 -- rounds start by themselves once this many people are in the game
local AUTO_ROUNDS = true
local RESPAWN_TIME = 3 -- outside a round (and for the monster), how long until you come back
local ADMINS = {} -- admins besides the game's owner: user IDs or usernames, e.g. { 12345678, "MyFriend" }

Players.CharacterAutoLoads = false -- this script decides who spawns, so caught hiders can spectate

local function remote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local notify = remote("CaveHunt_Notify")
local adminRemote = remote("CaveHunt_Admin")

-- the round's state, for the timer at the top of everyone's screen
local info = ReplicatedStorage:FindFirstChild("CaveHunt_Round") or Instance.new("Configuration")
info.Name = "CaveHunt_Round"
info.Parent = ReplicatedStorage
local function setState(state, seconds, message)
	info:SetAttribute("State", state)
	info:SetAttribute("EndsAt", seconds and workspace:GetServerTimeNow() + seconds or 0)
	info:SetAttribute("Message", message or "")
end
setState("Waiting")
info:SetAttribute("Monster", "")
info:SetAttribute("HidersLeft", 0)

-- roles are switched by CaveHunt_Players
local roles = ServerStorage:WaitForChild("CaveHunt_Roles", 30)
local function setRole(player, role)
	if roles and player.Parent == Players then
		local ok, err = pcall(roles.Invoke, roles, player, role)
		if not ok then
			warn("[CaveHunt] Couldn't make " .. player.Name .. " a " .. role .. ": " .. tostring(err))
		end
	end
end

local function reward(player, kind) -- coins, from CaveHunt_Shop
	local r = ServerStorage:FindFirstChild("CaveHunt_Reward")
	if r then
		r:Fire(player, kind)
	end
end

local function isAlive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function hidersLeft()
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Role") == "Hider" and isAlive(p) then
			n += 1
		end
	end
	return n
end

local function freeze(player, on)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = on
	end
end

local function inRound()
	local state = info:GetAttribute("State")
	return state == "Starting" or state == "Hiding" or state == "Hunting"
end

------------------------------------------------------------------ rounds
local generation = 0 -- goes up whenever a round starts or is stopped, so an older round quietly gives up
local monster = nil -- this round's monster
local paused = false -- an admin stopped rounds; they don't start by themselves until ;start

-- spectators and the monster go back to Base Camp as hiders
local function everyoneHides()
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Role") ~= "Hider" or not isAlive(p) then
			task.spawn(setRole, p, "Hider")
		end
	end
end

local function runRound(my, chosen)
	local players = Players:GetPlayers()
	if #players == 0 then
		setState("Waiting")
		return
	end
	local m = (chosen and chosen.Parent == Players) and chosen or players[math.random(1, #players)]
	monster = m
	info:SetAttribute("Monster", m.DisplayName)
	setState("Starting", nil, m.DisplayName .. " is the monster!")
	notify:FireAllClients(m.DisplayName .. " is the monster! Go hide!")
	for _, p in ipairs(players) do
		if p ~= m then
			task.spawn(setRole, p, "Hider") -- everyone else starts at Base Camp
		end
	end
	setRole(m, "Monster") -- the monster starts at one of the lairs
	if generation ~= my then
		return
	end

	-- the monster waits, frozen and blindfolded, while the hiders hide
	setState("Hiding", HIDE_TIME)
	local start = os.clock()
	while os.clock() - start < HIDE_TIME do
		if generation ~= my then
			return
		end
		freeze(m, os.clock() - start > 1.5) -- let it land first
		task.wait(0.25)
	end
	freeze(m, false)

	setState("Hunting", ROUND_TIME)
	notify:FireAllClients("The monster is loose!")
	local hadHiders = hidersLeft() > 0
	local finishAt = os.clock() + ROUND_TIME
	local result, winner
	while not result do
		if generation ~= my then
			return
		end
		local left = hidersLeft()
		info:SetAttribute("HidersLeft", left)
		if m.Parent ~= Players then
			result, winner = "The monster left the game. Hiders win!", "Hiders"
		elseif hadHiders and left == 0 then
			result, winner = m.DisplayName .. " caught everyone. The monster wins!", "Monster"
		elseif os.clock() >= finishAt then
			if left > 0 then
				result, winner = ("Time's up! %d hider%s survived. Hiders win!"):format(left, left == 1 and "" or "s"), "Hiders"
			else
				result = "Time's up!"
			end
		else
			task.wait(0.5)
		end
	end

	setState("Over", AFTER_ROUND, result)
	notify:FireAllClients(result)
	if winner == "Monster" then
		reward(m, "Win")
	elseif winner == "Hiders" then
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("Role") == "Hider" and isAlive(p) then
				reward(p, "Survive")
			end
		end
	end
	task.wait(AFTER_ROUND)
	if generation ~= my then
		return
	end
	monster = nil
	info:SetAttribute("Monster", "")
	everyoneHides()
	setState("Waiting")
end

local function startRound(chosen)
	generation += 1
	paused = false
	freeze(monster, false)
	task.spawn(runRound, generation, chosen)
end

local function stopRound(message)
	generation += 1
	paused = true
	freeze(monster, false)
	monster = nil
	info:SetAttribute("Monster", "")
	everyoneHides()
	setState("Waiting", nil, message)
end

-- rounds start by themselves once there are enough players
task.spawn(function()
	while true do
		task.wait(1)
		if info:GetAttribute("State") == "Waiting" and AUTO_ROUNDS and not paused then
			if #Players:GetPlayers() >= MIN_PLAYERS then
				local my = generation
				setState("Intermission", INTERMISSION)
				local startAt = os.clock() + INTERMISSION
				while os.clock() < startAt and generation == my and #Players:GetPlayers() >= MIN_PLAYERS do
					task.wait(0.5)
				end
				if generation == my then
					if #Players:GetPlayers() >= MIN_PLAYERS then
						startRound(nil)
					else
						setState("Waiting")
					end
				end
			else
				info:SetAttribute("Message", ("Free play: rounds start when %d players are here"):format(MIN_PLAYERS))
			end
		end
	end
end)

------------------------------------------------------------------ dying + spectating
local function onDied(player)
	local role = player:GetAttribute("Role")
	local state = info:GetAttribute("State")
	if role == "Hider" and (state == "Hiding" or state == "Hunting") then
		notify:FireAllClients(player.DisplayName .. " was caught!")
		task.wait(2)
		if player.Parent and player:GetAttribute("Role") == "Hider" and not isAlive(player) then
			setRole(player, "Spectator")
			notify:FireClient(player, "You were caught! You're spectating until the round ends.")
		end
		return
	end
	if role == "Spectator" then
		return
	end
	task.wait(RESPAWN_TIME) -- outside a round, or the monster: come back
	if player.Parent and not isAlive(player) and player:GetAttribute("Role") == role then
		setRole(player, role)
	end
end

local function watch(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			onDied(player)
		end)
	end
end

------------------------------------------------------------------ admin commands
local function isAdmin(player)
	if RunService:IsStudio() then
		return true
	end
	for _, who in ipairs(ADMINS) do
		if who == player.UserId or (type(who) == "string" and who:lower() == player.Name:lower()) then
			return true
		end
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		return ok and rank >= 255
	end
	return player.UserId == game.CreatorId
end

local function findPlayer(text) -- exact name first, then the start of a username or display name
	text = text:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == text or p.DisplayName:lower() == text then
			return p
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1, text:len()) == text or p.DisplayName:lower():sub(1, text:len()) == text then
			return p
		end
	end
	return nil
end

local HELP = "Admin: ;restart [name]  ;monster [name]  ;hider [name]  ;spectate [name]  ;end  ;start"

local function command(admin, verb, arg)
	verb = verb:lower()
	arg = arg or ""
	-- the player a command is about: the name given, or you
	local function target()
		if arg == "" or arg:lower() == "me" then
			return admin
		end
		local p = findPlayer(arg)
		if not p then
			notify:FireClient(admin, "There's nobody called " .. arg .. " here.")
		end
		return p
	end

	if verb == "restart" or verb == "start" or verb == "round" then
		-- a new round with a random monster, or the one named
		local chosen = nil
		if arg ~= "" and arg:lower() ~= "random" then
			chosen = target()
			if not chosen then
				return
			end
		end
		startRound(chosen)
		notify:FireAllClients(admin.DisplayName .. " started a new round.")
	elseif verb == "monster" then
		-- a new round with you (or the one named) as the monster
		local who = target()
		if who then
			startRound(who)
		end
	elseif verb == "hider" or verb == "revive" then
		local who = target()
		if not who then
			return
		end
		if who == monster and inRound() then
			-- the monster stepping down: a new round with someone else as the monster
			local others = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= who then
					table.insert(others, p)
				end
			end
			if #others > 0 then
				startRound(others[math.random(1, #others)])
			else
				stopRound("Rounds paused by an admin. Use ;start for a new round.")
			end
		else
			task.spawn(setRole, who, "Hider") -- back at Base Camp (brings a caught hider back too)
		end
	elseif verb == "spectate" then
		local who = target()
		if who == monster and inRound() then
			notify:FireClient(admin, "The monster can't spectate. Use ;hider to swap the monster.")
		elseif who then
			task.spawn(setRole, who, "Spectator")
		end
	elseif verb == "end" or verb == "stop" then
		stopRound("Rounds paused by an admin. Use ;start for a new round.")
		notify:FireAllClients(admin.DisplayName .. " stopped the round.")
	else
		notify:FireClient(admin, HELP)
	end
end

adminRemote.OnServerEvent:Connect(function(player, verb, arg)
	if player:GetAttribute("IsAdmin") and type(verb) == "string" and (arg == nil or type(arg) == "string") then
		command(player, verb, arg)
	end
end)

------------------------------------------------------------------ joining
local function onPlayer(player)
	player:SetAttribute("IsAdmin", isAdmin(player))
	player.CharacterAdded:Connect(function(character)
		watch(player, character)
	end)
	if player.Character then
		task.spawn(watch, player, player.Character)
	end
	player.Chatted:Connect(function(message)
		local verb, arg = message:match("^[;/](%a+)%s*(.-)%s*$")
		if verb and player:GetAttribute("IsAdmin") then
			command(player, verb, arg)
		end
	end)
	if inRound() then
		player:SetAttribute("Role", "Spectator") -- joins in when the round is over
	elseif not player.Character then
		task.spawn(setRole, player, "Hider")
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	if player == monster then
		monster = nil
	end
end)
]==]

SOURCES.Client = [==[
-- CaveHunt client: round timer, shop + Admin buttons, spectating, flashlight controls, the cave mood
-- (the monster's night vision), flickering lights.
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

-- small UI helpers
local function round(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = obj
end
local function make(className, parent, props)
	local t = Instance.new(className)
	if t:IsA("GuiObject") then
		t.BackgroundTransparency = 1
	end
	if className:find("^Text") then
		t.TextColor3 = Color3.fromRGB(235, 235, 240)
		t.Font = Enum.Font.GothamBold
		t.TextSize = 16
	end
	for k, v in pairs(props) do
		t[k] = v
	end
	t.Parent = parent
	return t
end
local function clock(seconds)
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end
local cameraShake = Vector3.new() -- the roar / air horn shake, added to the camera by the movement code

-- Movement: hold Shift to sprint (it uses stamina), C to crouch and sneak (slow and quiet). The
-- speeds come from the server (attributes on your character); stamina is kept here. Phones get
-- Run and Crouch buttons, gamepads use L3 and B.
local STAMINA_DRAIN = { Hider = 20, Monster = 14 } -- per second while sprinting (100 is full)
local STAMINA_REGEN = { Hider = 15, Monster = 18 } -- per second, starting a second after you stop sprinting
local CROUCH_ANIMATION = "" -- an animation you made, e.g. "rbxassetid://1234567", plays while crouching
local move = { stamina = 100, sprinting = false, crouching = false, wantSprint = false, restAt = 0, offset = Vector3.new() }
local crouchTrack
local function setCrouch(on)
	move.crouching = on
	if crouchTrack then
		crouchTrack:Stop()
		crouchTrack = nil
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if on and animator and CROUCH_ANIMATION ~= "" then
		local animation = Instance.new("Animation")
		animation.AnimationId = CROUCH_ANIMATION
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if ok and track then
			track.Looped = true
			track:Play()
			crouchTrack = track
		end
	end
end
ContextActionService:BindActionAtPriority("CaveHunt_Sprint", function(_, state)
	move.wantSprint = state == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("CaveHunt_Sprint", "Run")
ContextActionService:BindAction("CaveHunt_Crouch", function(_, state)
	if state == Enum.UserInputState.Begin then
		setCrouch(not move.crouching)
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("CaveHunt_Crouch", "Crouch")
player.CharacterAdded:Connect(function()
	move.stamina = 100
	setCrouch(false)
end)
RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local role = isMonster() and "Monster" or "Hider"
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local wants = move.wantSprint and moving and not move.crouching and not player:GetAttribute("Hidden")
	if wants and move.stamina > (move.sprinting and 0 or 20) then -- once you're out, wait until it's back to 20
		move.sprinting = true
		move.stamina = math.max(0, move.stamina - STAMINA_DRAIN[role] * dt)
		move.restAt = os.clock() + 1
	else
		move.sprinting = false
		if os.clock() > move.restAt then
			move.stamina = math.min(100, move.stamina + STAMINA_REGEN[role] * dt)
		end
	end
	local walk = character:GetAttribute("WalkSpeed") or 16
	local speed = walk
	if character:GetAttribute("Stunned") then
		speed = 0 -- slipped on a banana peel
	elseif move.sprinting then
		speed = character:GetAttribute("SprintSpeed") or walk * 1.5
	elseif move.crouching then
		speed = character:GetAttribute("CrouchSpeed") or walk * 0.5
	end
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
	-- crouching lowers your view
	move.offset = move.offset:Lerp(move.crouching and Vector3.new(0, -1.5, 0) or Vector3.new(), math.min(1, dt * 10))
	humanoid.CameraOffset = move.offset + cameraShake
end)

-- the stamina bar (only while it isn't full) and a CROUCHING tag, just above the hotbar
task.spawn(function()
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), { Name = "CaveHunt_Stamina", ResetOnSpawn = false })
	local back = make("Frame", gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(220, 8),
		BackgroundTransparency = 0.4,
		BackgroundColor3 = Color3.fromRGB(10, 10, 14),
	})
	round(back, 4)
	local fill = make("Frame", back, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(120, 220, 140) })
	round(fill, 4)
	local tag = make("TextLabel", gui, {
		Text = "CROUCHING",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(220, 18),
		TextSize = 13,
		TextColor3 = Color3.fromRGB(190, 200, 215),
		Visible = false,
	})
	while true do
		local alive = player.Character ~= nil
		back.Visible = alive and (move.stamina < 99.5 or move.sprinting)
		fill.Size = UDim2.fromScale(move.stamina / 100, 1)
		fill.BackgroundColor3 = move.stamina < 25 and Color3.fromRGB(230, 90, 70) or Color3.fromRGB(120, 220, 140)
		tag.Visible = alive and move.crouching
		task.wait(0.05)
	end
end)

-- Footsteps: everyone's steps play on every player's computer (like Roblox's own footsteps), from
-- where that character is. Running is louder and carries further than walking, and crouching is
-- almost silent. The monster's steps are deep, heavy stomps. Swap in your own sounds here.
local STEP_SOUNDS = {
	Hider = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", pitch = 1.3 },
	Monster = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", pitch = 0.55, stomp = "rbxasset://sounds/action_jump_land.mp3", stride = 6 },
}
local STEP_LOUDNESS = { -- { volume, heard up to this many studs away }; the monster is 1.6x both
	crouch = { 0.05, 16 },
	walk = { 0.6, 70 },
	sprint = { 1.3, 150 },
}
local steps = setmetatable({}, { __mode = "k" })
RunService.Heartbeat:Connect(function(dt)
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			local st = steps[character]
			if not st then
				st = { walked = 0 }
				st.loop = make("Sound", root, { Name = "CaveHunt_Steps", Looped = true })
				st.stomp = make("Sound", root, { Name = "CaveHunt_Stomp" })
				steps[character] = st
			end
			local default = root:FindFirstChild("Running") -- Roblox's own footsteps: these replace them
			if default and default:IsA("Sound") and default.Volume > 0 then
				default.Volume = 0
			end
			local monster = other:GetAttribute("Role") == "Monster"
			local kind = STEP_SOUNDS[monster and "Monster" or "Hider"]
			if st.loop.SoundId ~= kind.id then
				st.loop.SoundId = kind.id
			end
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			if speed > 2 and math.abs(v.Y) < 6 and humanoid.Health > 0 and not other:GetAttribute("Hidden") then
				local walk = character:GetAttribute("WalkSpeed") or 16
				local crouch = character:GetAttribute("CrouchSpeed") or walk * 0.5
				local sprint = character:GetAttribute("SprintSpeed") or walk * 1.5
				local mode = speed > (walk + sprint) / 2 and "sprint" or (speed < (crouch + walk) / 2 and "crouch" or "walk")
				local volume = STEP_LOUDNESS[mode][1] * (monster and 1.6 or 1)
				local reach = STEP_LOUDNESS[mode][2] * (monster and 1.6 or 1)
				st.loop.Volume = volume
				st.loop.RollOffMaxDistance = reach
				st.loop.RollOffMinDistance = reach / 10
				st.loop.PlaybackSpeed = kind.pitch * math.clamp(speed / walk, 0.6, 1.5)
				if not st.loop.IsPlaying then
					st.loop:Play()
				end
				if kind.stomp then
					st.walked += speed * dt
					if st.walked >= kind.stride then
						st.walked = 0
						st.stomp.SoundId = kind.stomp
						st.stomp.PlaybackSpeed = 0.6
						st.stomp.Volume = volume
						st.stomp.RollOffMaxDistance = reach
						st.stomp.RollOffMinDistance = reach / 10
						st.stomp:Play()
					end
				end
			elseif st.loop.IsPlaying then
				st.loop:Stop()
			end
		end
	end
end)

-- The monster's punch: click (R2 on a gamepad, the Hit button on a phone). The server decides
-- who gets hit: the closest hider in front of the monster, within reach, not through a wall, and
-- swings the monster's arm. A punch animation you made plays instead of that swing:
local PUNCH_ANIMATION = "" -- e.g. "rbxassetid://1234567" (Roblox only plays animations you own)
task.spawn(function()
	local punch = ReplicatedStorage:WaitForChild("CaveHunt_Punch", 30)
	if not punch then
		return
	end
	local readyAt = 0
	local function swing()
		if os.clock() < readyAt then
			return
		end
		readyAt = os.clock() + 1
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		local animated = false
		if animator and PUNCH_ANIMATION ~= "" then
			local animation = Instance.new("Animation")
			animation.AnimationId = PUNCH_ANIMATION
			local ok, track = pcall(animator.LoadAnimation, animator, animation)
			if ok and track then
				track:Play(0.05)
				animated = true
			end
		end
		punch:FireServer(animated)
	end
	local bound = false
	local function update()
		if isMonster() and not bound then
			ContextActionService:BindAction("CaveHunt_Punch", function(_, state)
				if state == Enum.UserInputState.Begin then
					swing()
				end
				return Enum.ContextActionResult.Pass
			end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
			ContextActionService:SetTitle("CaveHunt_Punch", "Hit")
			bound = true
		elseif not isMonster() and bound then
			ContextActionService:UnbindAction("CaveHunt_Punch")
			bound = false
		end
	end
	player:GetAttributeChangedSignal("Role"):Connect(update)
	update()
end)

-- The round timer at the top of the screen, the monster's blindfold while the hiders hide,
-- and the result when a round ends
task.spawn(function()
	local info = ReplicatedStorage:WaitForChild("CaveHunt_Round", 30)
	if not info then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local blindGui = make("ScreenGui", playerGui, { Name = "CaveHunt_Blindfold", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4 })
	local blind = make("Frame", blindGui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(0, 0, 0), Visible = false })
	local blindText = make("TextLabel", blind, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 120),
		TextSize = 30,
		TextColor3 = Color3.fromRGB(255, 80, 70),
	})
	local gui = make("ScreenGui", playerGui, { Name = "CaveHunt_Round", ResetOnSpawn = false, DisplayOrder = 5 })
	local bar = make("TextLabel", gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Color3.fromRGB(12, 12, 16),
		TextSize = 18,
	})
	round(bar, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	pad.Parent = bar
	local result = make("TextLabel", gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(700, 60),
		TextSize = 34,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 225, 140),
		TextStrokeTransparency = 0.4,
		Visible = false,
	})
	while true do
		local state = info:GetAttribute("State") or "Waiting"
		local left = math.max(0, math.ceil((info:GetAttribute("EndsAt") or 0) - workspace:GetServerTimeNow()))
		local monsterName = info:GetAttribute("Monster") or ""
		local message = info:GetAttribute("Message") or ""
		local text
		if state == "Hiding" then
			text = isMonster() and "You're the monster. Wait..." or ("Hide! %s comes out in %s"):format(monsterName, clock(left))
		elseif state == "Hunting" then
			local n = info:GetAttribute("HidersLeft") or 0
			text = ("%s is hunting   |   %d hider%s left   |   %s"):format(monsterName, n, n == 1 and "" or "s", clock(left))
		elseif state == "Intermission" then
			text = "Next round in " .. clock(left)
		else
			text = message ~= "" and message or "Free play"
		end
		bar.Text = text
		blind.Visible = state == "Hiding" and isMonster()
		blindText.Text = ("You're the monster.\nThe hiders are hiding... %d"):format(left)
		result.Visible = state == "Over"
		result.Text = message
		task.wait(0.2)
	end
end)

-- Spectate mode: once you're caught you watch the others until the round ends.
-- The arrows at the bottom of the screen (or Q and E) switch who you're watching.
task.spawn(function()
	local camera = workspace.CurrentCamera
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), { Name = "CaveHunt_Spectate", ResetOnSpawn = false, Enabled = false })
	local frame = make("Frame", gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(420, 48),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Color3.fromRGB(12, 12, 16),
	})
	round(frame, 10)
	local label = make("TextLabel", frame, { Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -104, 1, 0), TextSize = 17 })
	local prev = make("TextButton", frame, { Text = "<", Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(40, 36), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(40, 40, 52), TextSize = 22 })
	local nxt = make("TextButton", frame, { Text = ">", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(40, 36), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(40, 40, 52), TextSize = 22 })
	round(prev, 6)
	round(nxt, 6)

	local watching
	local function humanoidOf(other)
		local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
		local role = other:GetAttribute("Role")
		if humanoid and humanoid.Health > 0 and (role == "Hider" or role == "Monster") then
			return humanoid
		end
		return nil
	end
	local function watch(step)
		local list = {}
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and humanoidOf(other) then
				table.insert(list, other)
			end
		end
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
		local i = table.find(list, watching)
		if not i then
			i = 1
		elseif step ~= 0 then
			i = (i - 1 + step) % #list + 1
		end
		watching = list[i]
		if watching then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoidOf(watching)
			local what = watching:GetAttribute("Role") == "Monster" and "the monster" or (watching:GetAttribute("Hidden") and "hiding" or "hider")
			label.Text = ("Spectating %s (%s)"):format(watching.DisplayName, what)
		else
			label.Text = "Spectating: nobody left to watch"
		end
	end
	prev.Activated:Connect(function()
		watch(-1)
	end)
	nxt.Activated:Connect(function()
		watch(1)
	end)

	local spectating = false
	local function update()
		local now = player:GetAttribute("Role") == "Spectator"
		if now ~= spectating then
			spectating = now
			gui.Enabled = now
			watching = nil
			if now then
				ContextActionService:BindAction("CaveHunt_SpectatePrev", function(_, state)
					if state == Enum.UserInputState.Begin then
						watch(-1)
					end
					return Enum.ContextActionResult.Sink
				end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
				ContextActionService:BindAction("CaveHunt_SpectateNext", function(_, state)
					if state == Enum.UserInputState.Begin then
						watch(1)
					end
					return Enum.ContextActionResult.Sink
				end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonR1)
				watch(0)
			else
				ContextActionService:UnbindAction("CaveHunt_SpectatePrev")
				ContextActionService:UnbindAction("CaveHunt_SpectateNext")
			end
		end
		if spectating then
			local humanoid = watching and humanoidOf(watching)
			if not humanoid then
				watch(0) -- they were caught or left: watch someone else
			elseif camera.CameraSubject ~= humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end
	player:GetAttributeChangedSignal("Role"):Connect(update)
	while true do
		update()
		task.wait(0.3)
	end
end)

-- The Admin panel (admins only: everyone in Studio, the game's owner, and ADMINS in CaveHunt_Rounds).
-- The same things work as chat commands: ;restart ;monster ;hider ;spectate ;end ;start
task.spawn(function()
	local admin = ReplicatedStorage:WaitForChild("CaveHunt_Admin", 30)
	if not admin then
		return
	end
	while not player:GetAttribute("IsAdmin") do
		player:GetAttributeChangedSignal("IsAdmin"):Wait()
	end
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), { Name = "CaveHunt_AdminUI", ResetOnSpawn = false })
	local open = make("TextButton", gui, {
		Text = "Admin",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 60),
		Size = UDim2.fromOffset(170, 36),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Color3.fromRGB(40, 12, 12),
		TextColor3 = Color3.fromRGB(255, 222, 210),
	})
	round(open, 8)
	local panel = make("Frame", gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 104),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		BackgroundColor3 = Color3.fromRGB(16, 16, 22),
		Visible = false,
	})
	round(panel, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local order = 0
	local function add(text, color, onClick)
		order += 1
		local b = make(onClick and "TextButton" or "TextLabel", panel, {
			Text = text,
			Size = UDim2.new(1, 0, 0, onClick and 32 or 22),
			BackgroundTransparency = onClick and 0 or 1,
			BackgroundColor3 = color or Color3.fromRGB(40, 40, 52),
			TextSize = onClick and 15 or 13,
			TextWrapped = true,
			LayoutOrder = order,
		})
		if onClick then
			round(b, 6)
			b.Activated:Connect(onClick)
		end
		return b
	end
	local function send(verb, arg)
		return function()
			admin:FireServer(verb, arg)
		end
	end
	add("Restart round (random monster)", Color3.fromRGB(46, 100, 60), send("restart"))
	add("Make me the monster", Color3.fromRGB(110, 30, 30), send("monster"))
	add("Make me a hider", nil, send("hider"))
	add("Spectate", nil, send("spectate"))
	add("Stop rounds", nil, send("end"))
	add("Make someone the monster:")
	local first = order
	local playerButtons = {}
	local function refreshPlayers()
		for _, b in ipairs(playerButtons) do
			b:Destroy()
		end
		playerButtons = {}
		order = first
		for _, other in ipairs(Players:GetPlayers()) do
			table.insert(playerButtons, add(other.DisplayName, Color3.fromRGB(70, 30, 30), send("monster", other.Name)))
		end
		local help = add("Chat: ;restart [name]  ;monster [name]  ;hider [name]  ;spectate [name]  ;end  ;start")
		help.TextColor3 = Color3.fromRGB(160, 165, 180)
		help.Size = UDim2.new(1, 0, 0, 36)
		table.insert(playerButtons, help)
	end
	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			refreshPlayers()
		end
	end)
end)

-- messages at the top of the screen ("Bob is calling you!"), the screen shake (the monster's
-- roar, an air horn) and the monster seeing a hider someone snitched on
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
	shake.OnClientEvent:Connect(function(message)
		show(message or "The monster roared nearby!")
		local stopAt = os.clock() + 1.2
		while os.clock() < stopAt do
			cameraShake = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 1.2
			RunService.RenderStepped:Wait()
		end
		cameraShake = Vector3.new()
	end)
	local reveal = ReplicatedStorage:WaitForChild("CaveHunt_Reveal", 30)
	if reveal then
		reveal.OnClientEvent:Connect(function(target, seconds, message)
			if message then
				show(message)
			end
			if typeof(target) ~= "Instance" or not target.Parent then
				return
			end
			local h = Instance.new("Highlight")
			h.FillColor = Color3.fromRGB(255, 150, 30)
			h.OutlineColor = Color3.fromRGB(255, 220, 120)
			h.FillTransparency = 0.4
			h.OutlineTransparency = 0
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Adornee = target
			h.Parent = target
			game:GetService("Debris"):AddItem(h, seconds or 5)
		end)
	end
end)

-- The shop: the "Shop" button in the top-right corner (or B) opens it. Coins are on the
-- leaderboard. Bought items go in your hotbar, and each use spends one.
task.spawn(function()
	local buy = ReplicatedStorage:WaitForChild("CaveHunt_Buy", 30)
	local catalog = ReplicatedStorage:WaitForChild("CaveHunt_Shop", 30)
	local stats = player:WaitForChild("leaderstats", 30)
	local coins = stats and stats:WaitForChild("Coins", 30)
	if not (buy and catalog and coins) then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CaveHunt_ShopUI"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local open = make("TextButton", gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(170, 36),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Color3.fromRGB(60, 46, 10),
		TextColor3 = Color3.fromRGB(255, 225, 140),
	})
	round(open, 8)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, 460, 0.8, 0)
	panel.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	round(panel, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 600)
	limit.Parent = panel
	make("TextLabel", panel, {
		Text = "Troll Shop",
		TextSize = 22,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -170, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local wallet = make("TextLabel", panel, {
		TextColor3 = Color3.fromRGB(255, 210, 90),
		Position = UDim2.new(1, -156, 0, 10),
		Size = UDim2.fromOffset(104, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local close = make("TextButton", panel, {
		Text = "X",
		Position = UDim2.new(1, -42, 0, 10),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(90, 30, 30),
	})
	round(close, 6)
	local status = make("TextLabel", panel, {
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(190, 200, 215),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -8),
		Size = UDim2.new(1, -32, 0, 30),
	})
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 50)
	list.Size = UDim2.new(1, -24, 1, -96)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local rows = {}
	local function refresh()
		open.Text = ("Shop  \u{00B7}  %d coins"):format(coins.Value)
		wallet.Text = ("%d coins"):format(coins.Value)
		for _, r in ipairs(rows) do
			local hidersOnly = r.who == "Hider" and isMonster()
			local can = not hidersOnly and coins.Value >= r.price
			r.button.Text = hidersOnly and "Hiders only" or r.price == 0 and "Free" or ("%d coins"):format(r.price)
			r.button.AutoButtonColor = can
			r.button.BackgroundColor3 = can and Color3.fromRGB(46, 120, 60) or Color3.fromRGB(55, 55, 62)
		end
	end
	local entries = catalog:GetChildren()
	table.sort(entries, function(a, b)
		return (a:GetAttribute("Order") or 99) < (b:GetAttribute("Order") or 99)
	end)
	for i, entry in ipairs(entries) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 62)
		row.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		row.LayoutOrder = i
		row.Parent = list
		round(row, 8)
		make("TextLabel", row, {
			Text = entry:GetAttribute("Name") or entry.Name,
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -136, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		make("TextLabel", row, {
			Text = entry:GetAttribute("Tip") or "",
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(170, 175, 190),
			Position = UDim2.fromOffset(12, 26),
			Size = UDim2.new(1, -136, 0, 32),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local button = make("TextButton", row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(108, 36),
			BackgroundTransparency = 0,
		})
		round(button, 6)
		table.insert(rows, { button = button, price = entry:GetAttribute("Price") or 0, who = entry:GetAttribute("Who") or "Any" })
		local waiting = false
		button.Activated:Connect(function()
			if waiting then
				return
			end
			waiting = true
			status.Text = "..."
			local ok, _, message = pcall(buy.InvokeServer, buy, entry.Name)
			status.Text = ok and tostring(message) or "The shop didn't answer. Try again."
			waiting = false
			refresh()
		end)
	end

	local function setOpen(on)
		panel.Visible = on
		if on then
			status.Text = "Bought items go in your hotbar. Each use spends one."
			refresh()
		end
	end
	open.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	coins.Changed:Connect(refresh)
	player:GetAttributeChangedSignal("Role"):Connect(refresh)
	ContextActionService:BindAction("CaveHunt_Shop", function(_, state)
		if state == Enum.UserInputState.Begin then
			setOpen(not panel.Visible)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.B)
	refresh()
end)

-- the coins lying around the cave spin slowly
RunService.RenderStepped:Connect(function(dt)
	for _, coin in ipairs(CollectionService:GetTagged("CaveCoin")) do
		coin.CFrame *= CFrame.Angles(0, dt * 2, 0)
	end
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

-- Cave mood while you're inside the cave's rock block: no fog, and no sun, sky or ambient light,
-- so hiders only see what a light shines on (flashlights, lanterns, glowing crystals).
-- The monster gets green night vision instead (N switches it off and on).
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

local nightVision = true
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
		local seeing = monster and nightVision
		saved = {
			lighting = {
				Ambient = Lighting.Ambient,
				OutdoorAmbient = Lighting.OutdoorAmbient,
				Brightness = Lighting.Brightness,
				EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
				EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
				ExposureCompensation = Lighting.ExposureCompensation,
				FogStart = Lighting.FogStart,
				FogEnd = Lighting.FogEnd,
			},
		}
		local ambient = seeing and Color3.fromRGB(170, 190, 170) or (monster and Color3.fromRGB(30, 8, 8) or Color3.new(0, 0, 0))
		Lighting.Ambient = ambient
		Lighting.OutdoorAmbient = ambient
		Lighting.Brightness = 0 -- the sun and moon would light the cave through the rock
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
		Lighting.ExposureCompensation = seeing and 0.6 or 0
		Lighting.FogStart = 0
		Lighting.FogEnd = 100000 -- no fog
		if atmosphere then -- an Atmosphere glows like daylight haze even inside the cave: switch it off
			saved.atmosphere = {
				Density = atmosphere.Density,
				Offset = atmosphere.Offset,
				Glare = atmosphere.Glare,
				Haze = atmosphere.Haze,
			}
			atmosphere.Density = 0
			atmosphere.Offset = 0
			atmosphere.Glare = 0
			atmosphere.Haze = 0
		end
		grade.Contrast = seeing and 0.1 or 0.15
		grade.Saturation = seeing and -1 or (monster and -0.7 or -0.4)
		grade.Brightness = seeing and 0.1 or -0.05
		grade.TintColor = seeing and Color3.fromRGB(150, 255, 160) or (monster and Color3.fromRGB(255, 200, 200) or Color3.fromRGB(222, 230, 255))
		bloom.Intensity = seeing and 0.25 or 0.7
		bloom.Threshold = seeing and 0.97 or 0.85
	end
	grade.Enabled = on
	bloom.Enabled = on
end

-- night vision also lights up the rock around the monster (a light only the monster's own screen has)
local function updateNightLight(on)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local light = root and root:FindFirstChild("CaveHunt_NightLight")
	if on and root and not light then
		make("PointLight", root, { Name = "CaveHunt_NightLight", Range = 60, Brightness = 1.2, Color = Color3.fromRGB(200, 255, 210), Shadows = false })
	elseif not on and light then
		light:Destroy()
	end
end

local inCave = false
player:GetAttributeChangedSignal("Role"):Connect(function()
	if inCave then
		setCaveMood(true) -- switch between hider and monster vision
	end
end)
ContextActionService:BindAction("CaveHunt_NightVision", function(_, state)
	if not isMonster() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		nightVision = not nightVision
		if inCave then
			setCaveMood(true)
		end
		updateNightLight(inCave and nightVision and isMonster())
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.N)
task.spawn(function()
	while true do
		task.wait(0.5)
		local cave = workspace:FindFirstChild("CaveSystem")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local center = cave and cave:GetAttribute("BoxCenter")
		local size = cave and cave:GetAttribute("BoxSize")
		local at = root and root.Position or workspace.CurrentCamera.Focus.Position -- spectators: where the camera is looking
		local now = false
		if center and size then
			local d = at - center
			now = math.abs(d.X) < size.X / 2 and math.abs(d.Y) < size.Y / 2 and math.abs(d.Z) < size.Z / 2
		end
		if now ~= inCave then
			inCave = now
			setCaveMood(now)
		end
		updateNightLight(inCave and nightVision and isMonster())
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local tool = script.Parent
local NAME = tool.Name
local readyAt = 0

-- the slot shows "Glowstick x3" for shop items you have several of, and counts down while recharging
local function refreshName()
	local name = NAME
	local charges = tool:GetAttribute("Charges")
	if charges and charges > 1 then
		name = ("%s x%d"):format(name, charges)
	end
	if os.clock() < readyAt then
		name = ("%s (%d)"):format(name, math.ceil(readyAt - os.clock()))
	end
	tool.Name = name
end
tool:GetAttributeChangedSignal("Charges"):Connect(refreshName)
refreshName()

local function cooldown(seconds)
	readyAt = os.clock() + seconds
	task.spawn(function()
		while os.clock() < readyAt do
			refreshName()
			task.wait(0.25)
		end
		refreshName()
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

-- shop items: the server checks you still have one, does the effect and takes one away
local function useItem(arg)
	local remote = ReplicatedStorage:FindFirstChild("CaveHunt_UseItem")
	if remote then
		remote:FireServer(tool:GetAttribute("Item"), arg)
	end
end

-- a little list of other players to pick from; onPick gets the one you click
local function pickPlayer(title, wanted, onPick)
	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("CaveHunt_Picker")
	if old then
		old:Destroy()
	end
	local people = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and wanted(other) then
			table.insert(people, other)
		end
	end
	local picker = Instance.new("ScreenGui")
	picker.Name = "CaveHunt_Picker"
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
	row(#people > 0 and title or "Nobody to pick right now", Color3.new(), 0)
	for i, other in ipairs(people) do
		row(other.DisplayName, Color3.fromRGB(40, 70, 120), i, function()
			picker:Destroy()
			onPick(other)
		end)
	end
	row("Cancel", Color3.fromRGB(90, 30, 30), #people + 1, function()
		picker:Destroy()
	end)
	picker.Parent = playerGui
end

local function otherHider(other)
	return other:GetAttribute("Role") == "Hider" and other.Character ~= nil
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
		if spot:GetAttribute("Occupied") or spot:GetAttribute("FakeOccupied") then
			glow(spot, Color3.fromRGB(255, 190, 40)) -- someone is in there (or a Fake Hider from the shop)
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
local ring = ReplicatedStorage:WaitForChild("CaveHunt_Ring")
onUse(function()
	pickPlayer("Who do you want to call?", otherHider, function(other)
		ring:FireServer(other)
		cooldown(8)
	end)
end)
]==],
	},
}

-- Shop items (troll items). Bought with coins in the shop; each use spends one. `key` is how the
-- shop knows the item, `who` = "Hider" means the monster can't buy or use it.
local USE_NOW = [==[
onUse(function()
	useItem()
	cooldown(1)
end)
]==]
local SHOP_ITEMS = {
	{
		key = "Snitch",
		name = "Snitch",
		price = 30,
		who = "Hider",
		tip = "Pick a hider: the monster sees them (or the spot they're hiding in) for 5s",
		source = [==[
onUse(function()
	pickPlayer("Who do you want to snitch on?", otherHider, function(other)
		useItem(other)
		cooldown(1)
	end)
end)
]==],
	},
	{
		key = "Glowstick",
		name = "Glowstick",
		price = 10,
		who = "Any",
		tip = "Throw a green glowstick where you're looking. It lights the area for 25s",
		source = [==[
onUse(function()
	useItem(workspace.CurrentCamera.CFrame.LookVector)
	cooldown(1)
end)
]==],
	},
	{
		key = "FakeNoise",
		name = "Fake Noise",
		price = 15,
		who = "Any",
		tip = "A phone rings where you're aiming for 5s. Works from inside a hiding spot",
		source = [==[
onUse(function(character)
	local camera = workspace.CurrentCamera.CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(camera.Position, camera.LookVector * 150, params)
	useItem(hit and hit.Position - camera.LookVector * 2 or camera.Position + camera.LookVector * 60)
	cooldown(1)
end)
]==],
	},
	{ key = "SpotLock", name = "Spot Lock", price = 20, who = "Hider", tip = "Jam the nearest hiding spot for 10s so nobody can get in", source = USE_NOW },
	{
		key = "Swap",
		name = "Swap",
		price = 35,
		who = "Hider",
		tip = "Pick a hider (not one who's hiding) and swap places with them",
		source = [==[
onUse(function()
	pickPlayer("Who do you want to swap with?", otherHider, function(other)
		useItem(other)
		cooldown(1)
	end)
end)
]==],
	},
	{ key = "Banana", name = "Banana Peel", price = 15, who = "Any", tip = "Drop a peel at your feet. The next person to step on it slips for 2s", source = USE_NOW },
	{ key = "AirHorn", name = "Air Horn", price = 10, who = "Any", tip = "HONK. Shakes everyone within 60 studs, and the monster hears it from far away", source = USE_NOW },
	{ key = "FakeHider", name = "Fake Hider", price = 20, who = "Hider", tip = "The nearest empty hiding spot shows up as taken in the monster's Sense for 60s", source = USE_NOW },
}
for i, item in ipairs(SHOP_ITEMS) do
	item.order = i
	table.insert(ITEMS, item)
end

-- Your monster model. If ServerStorage doesn't have one yet, find it in Workspace and move it there:
-- a model with "monster" in its name, or else a character model (one with a Humanoid, like the NPCs
-- from the Toolbox), the tallest if there are several. Returns a line for the Output.
local function adoptMonster()
	local ServerStorage = game:GetService("ServerStorage")
	local named = ServerStorage:FindFirstChild("Monster")
	if named and named:IsA("Model") then
		return "Your monster: ServerStorage.Monster."
	end
	for _, d in ipairs(ServerStorage:GetChildren()) do
		if d:IsA("Model") and d:GetAttribute("CaveHuntMonster") then
			return ("Your monster: ServerStorage.%s."):format(d.Name)
		end
	end
	local best, bestScore, bestHeight
	local function consider(m)
		local name = m.Name:lower()
		local score = (name:find("monster") and 4 or 0) + (m:FindFirstChildOfClass("Humanoid") and 2 or 0) + (m:FindFirstChild("HumanoidRootPart") and 1 or 0)
		if name == "rig" or name == "dummy" then
			score -= 1 -- probably a test dummy
		end
		if score >= 2 then
			local height = m:GetExtentsSize().Y
			if not best or score > bestScore or (score == bestScore and height > bestHeight) then
				best, bestScore, bestHeight = m, score, height
			end
		end
	end
	local function scan(parent)
		for _, c in ipairs(parent:GetChildren()) do
			if c:IsA("Model") and c.Name ~= "CaveSystem" then
				consider(c)
			elseif c:IsA("Folder") and c.Name ~= "CaveSystem" then
				scan(c)
			end
		end
	end
	scan(workspace)
	if not best then
		return "No monster model found, so the monster is your own character in black with red eyes. To use yours, put it in ServerStorage, name it Monster and run this again."
	end
	local from = best:GetFullName()
	best.Parent = ServerStorage
	best:SetAttribute("CaveHuntMonster", true)
	return ("Your monster: %s. Moved it from %s to ServerStorage so whoever is the monster plays as it. Wrong model? Drag it back, put the right one in ServerStorage named Monster, and run this again."):format(best.Name, from)
end

local function run()
	local monsterNote = ""
	local ok, err = pcall(function()
		monsterNote = adoptMonster()
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
			if item.key then -- sold in the shop
				tool:SetAttribute("Item", item.key)
				tool:SetAttribute("Price", item.price)
				tool:SetAttribute("Who", item.who)
				tool:SetAttribute("Order", item.order)
			end
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
		install(ServerScriptService, "Script", "CaveHunt_Shop", SOURCES.Shop)
		install(ServerScriptService, "Script", "CaveHunt_Rounds", SOURCES.Rounds)
		install(playerScripts, "LocalScript", "CaveHunt_Client", SOURCES.Client)
	end)
	if not ok then
		warn("[GameScripts] Something went wrong. Copy this message and send it to Claude:\n" .. tostring(err))
		return false
	end
	print("[GameScripts] " .. monsterNote)
	print("[GameScripts] Installed: same-size hiders with their own heads, flashlights (F), hiding (E), phones, the monster and its abilities, rounds with spectating, admin commands (Admin button or ;help in chat), the troll shop (Shop button or B), and the cave mood. Press Play to try them.")
	return true
end

-- Loaded as a ModuleScript (the GitHub one-liner): hand back run. Pasted straight into the Command Bar: just run it.
if script then
	return run
end
return run()
