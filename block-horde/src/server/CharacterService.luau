--!strict
-- Spawns players and dresses them as blocky heroes: the Roblox avatar is
-- hidden and block parts are welded on top of it. Each player has a slot
-- (1-6) that picks their shirt color. Players outside a run respawn at their
-- home spawn (the lobby); players in a run stay down and spectate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HeroModel = require(ReplicatedStorage.Shared.Models.HeroModel)
local Signal = require(ReplicatedStorage.Shared.Signal)
local RunState = require(script.Parent.RunState)
local WorldSetup = require(script.Parent.WorldSetup)

local CharacterService = {}

CharacterService.Died = Signal.new() -- (player: Player)

-- Where a player who is not in a run spawns, or nil to not spawn them. Set by Main.
CharacterService.homeSpawn = function(_player: Player): CFrame?
	return nil
end

local SHIRT_PARTS: { [string]: boolean } = { Torso = true, LeftArm = true, RightArm = true, Ring = true }

local slots: { [Player]: number } = {}

local function takeFreeSlot(): number
	local taken: { [number]: boolean } = {}
	for _, slot in slots do
		taken[slot] = true
	end
	local slot = 1
	while taken[slot] do
		slot += 1
	end
	return slot
end

function CharacterService.slotOf(player: Player): number
	return slots[player] or 1
end

function CharacterService.shirtFor(slot: number): Color3
	return Config.SHIRT_COLORS[(slot - 1) % #Config.SHIRT_COLORS + 1]
end

local LEG_PARTS = {
	LeftLeg = { "LeftUpperLeg", "Left Leg" }, -- R15, R6
	RightLeg = { "RightUpperLeg", "Right Leg" },
}

local function findLeg(character: Model, which: string): BasePart?
	for _, name in LEG_PARTS[which] do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- Hides one piece of the Roblox avatar. Hero parts are tagged and left alone.
local function hideAvatarPiece(instance: Instance)
	if instance:IsA("Accessory") then
		task.defer(instance.Destroy, instance)
	elseif instance:IsA("BasePart") then
		instance.CollisionGroup = WorldSetup.PLAYER_GROUP
		if not instance:GetAttribute("Hero") then
			instance.Transparency = 1
			instance.CastShadow = false
		end
	elseif instance:IsA("Decal") then
		instance.Transparency = 1
	end
end

-- Name and health bar over the head. Clients keep the bar's fill up to date.
local function addNameTag(head: BasePart, player: Player, shirt: Color3)
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(120, 34)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Name = "PlayerName"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 16
	label.TextColor3 = shirt:Lerp(Color3.new(1, 1, 1), 0.35)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = player.DisplayName
	label.Parent = tag

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 23)
	bar.Size = UDim2.fromOffset(60, 7)
	bar.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
	bar.BorderSizePixel = 0
	bar.Parent = tag
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = bar

	tag.Parent = head
end

local function dress(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	humanoid.WalkSpeed = Config.WALK_SPEED
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = Config.PLAYER_MAX_HEALTH
	humanoid.Health = Config.PLAYER_MAX_HEALTH

	for _, descendant in character:GetDescendants() do
		hideAvatarPiece(descendant)
	end
	character.DescendantAdded:Connect(hideAvatarPiece)

	local shirt = CharacterService.shirtFor(CharacterService.slotOf(player))
	local hero = Instance.new("Folder")
	hero.Name = "Hero"
	for _, spec in HeroModel.parts(shirt) do
		local part = Instance.new("Part")
		part.Name = spec.name
		part.Size = spec.size
		part.Color = spec.color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Transparency = spec.transparency or 0
		if spec.shape then
			part.Shape = spec.shape
			part.CastShadow = false
		end
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part:SetAttribute("Hero", true)
		part:SetAttribute("BaseTransparency", part.Transparency)

		-- Legs ride on the avatar's legs (top edges lined up) so the walk animation swings them.
		local anchor: BasePart = root
		local offset = spec.offset
		if spec.attach ~= "Root" then
			local leg = findLeg(character, spec.attach)
			if leg then
				anchor = leg
				offset = CFrame.new(0, leg.Size.Y / 2 - spec.size.Y / 2, 0)
			end
		end
		part.CFrame = anchor.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = anchor
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part

		part.Parent = hero
		if spec.name == "Head" then
			addNameTag(part, player, shirt)
		end
	end
	hero.Parent = character
end

local function setHeroVisible(character: Model, visible: boolean)
	local hero = character:FindFirstChild("Hero")
	if not hero then
		return
	end
	for _, part in hero:GetChildren() do
		if part:IsA("BasePart") then
			local base = part:GetAttribute("BaseTransparency")
			part.Transparency = if visible and typeof(base) == "number" then base else 1
		end
	end
	local head = hero:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("NameTag")
	if tag and tag:IsA("BillboardGui") then
		tag.Enabled = visible
	end
end

-- Changes a player's slot and recolors their hero's shirt to match.
function CharacterService.setSlot(player: Player, slot: number)
	slots[player] = slot
	local shirt = CharacterService.shirtFor(slot)
	local character = player.Character
	local hero = character and character:FindFirstChild("Hero")
	if not hero then
		return
	end
	for _, part in hero:GetChildren() do
		if part:IsA("BasePart") and SHIRT_PARTS[part.Name] then
			part.Color = shirt
		end
	end
	local head = hero:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("NameTag")
	local label = tag and tag:FindFirstChild("PlayerName")
	if label and label:IsA("TextLabel") then
		label.TextColor3 = shirt:Lerp(Color3.new(1, 1, 1), 0.35)
	end
end

-- Gives a player the lowest free slot again (after a run handed out party slots).
function CharacterService.reassignSlot(player: Player)
	slots[player] = nil
	CharacterService.setSlot(player, takeFreeSlot())
end

-- Puts the player at `cframe` with full health, spawning a new character if
-- they have none or are dead. Yields until done.
function CharacterService.spawnAt(player: Player, cframe: CFrame)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		player:LoadCharacterAsync()
		character = player.Character
	end
	if not character or not player.Parent then
		return
	end
	if not character:IsDescendantOf(workspace) then
		character.AncestryChanged:Wait()
	end
	task.wait() -- let the engine finish placing a fresh character
	character:PivotTo(cframe)
	local current = character:FindFirstChildOfClass("Humanoid")
	if current and current.Health > 0 then
		current.Health = current.MaxHealth
	end
end

local function onCharacterAdded(player: Player, character: Model)
	dress(player, character)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		task.delay(0.15, setHeroVisible, character, false)
		CharacterService.Died:Fire(player)
		if RunState.isParticipant(player) then
			return -- run players spectate until the run ends
		end
		task.delay(Config.HUB_RESPAWN_DELAY, function()
			if player.Parent and player.Character == character and not RunState.isParticipant(player) then
				local home = CharacterService.homeSpawn(player)
				if home then
					CharacterService.spawnAt(player, home)
				end
			end
		end)
	end)
end

local function onPlayerAdded(player: Player)
	slots[player] = takeFreeSlot()
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	local home = CharacterService.homeSpawn(player)
	if home then
		CharacterService.spawnAt(player, home)
	end
end

function CharacterService.start()
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		slots[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return CharacterService
