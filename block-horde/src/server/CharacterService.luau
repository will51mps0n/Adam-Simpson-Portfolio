--!strict
-- Spawns players on the room's 'P' cells and dresses them as blocky heroes:
-- the Roblox avatar is hidden and block parts are welded on top of it.
-- Each player keeps a slot (1-6) that picks their shirt color and spawn cell.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HeroModel = require(ReplicatedStorage.Shared.Models.HeroModel)
local Arena = require(script.Parent.Arena)
local Loadout = require(script.Parent.Loadout)
local WorldSetup = require(script.Parent.WorldSetup)

local CharacterService = {}

local SPAWN_HEIGHT = 3.5 -- root part height above the floor when placed

local slots: { [Player]: number } = {}

local function takeFreeSlot(): number
	local taken: { [number]: boolean } = {}
	for _, slot in slots do
		taken[slot] = true
	end
	for slot = 1, #Config.SHIRT_COLORS do
		if not taken[slot] then
			return slot
		end
	end
	return 1
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

local function addNameTag(head: BasePart, player: Player, shirt: Color3)
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(160, 24)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 18
	label.TextColor3 = shirt:Lerp(Color3.new(1, 1, 1), 0.35)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = player.DisplayName
	label.Parent = tag

	tag.Parent = head
end

local function dress(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	humanoid.WalkSpeed = Config.WALK_SPEED
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = Config.PLAYER_MAX_HEALTH
	humanoid.Health = Config.PLAYER_MAX_HEALTH

	for _, descendant in character:GetDescendants() do
		hideAvatarPiece(descendant)
	end
	character.DescendantAdded:Connect(hideAvatarPiece)

	local shirt = Config.SHIRT_COLORS[slots[player] or 1]
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

local function spawnCFrame(player: Player): CFrame
	local grid = Arena.grid()
	local cells = grid:find("P")
	if #cells == 0 then
		return CFrame.new(0, SPAWN_HEIGHT, 0)
	end
	local cell = cells[((slots[player] or 1) - 1) % #cells + 1]
	local x, z = grid:cellCenter(cell.c, cell.r)
	return CFrame.new(x, SPAWN_HEIGHT, z) -- facing north
end

local function onCharacterAdded(player: Player, character: Model)
	dress(player, character)
	Loadout.sync(player)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		task.delay(Config.RESPAWN_DELAY, function()
			if player.Parent and player.Character == character then
				player:LoadCharacterAsync()
			end
		end)
	end)

	-- Move to the spawn cell once the engine has finished placing the character.
	task.spawn(function()
		if not character:IsDescendantOf(workspace) then
			character.AncestryChanged:Wait()
		end
		task.wait()
		character:PivotTo(spawnCFrame(player))
	end)
end

local function onPlayerAdded(player: Player)
	slots[player] = takeFreeSlot()
	Loadout.reset(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	else
		player:LoadCharacterAsync()
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
