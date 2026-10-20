--!strict
-- The in-run HUD: health and score (top left), the big multiplier with its
-- draining bar (top center), wave and room (top right), teammates (right),
-- weapon slots 1-0 with ammo (bottom center), a red flash when you are hurt
-- and a SPECTATING label when you are down. Hidden in the lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combo = require(Shared:WaitForChild("Combo"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Rooms = require(Shared:WaitForChild("Rooms"))
local CameraController = require(script.Parent.CameraController)
local Input = require(script.Parent.InputController)
local UI = require(script.Parent.UI)
local WeaponController = require(script.Parent.WeaponController)

local player = Players.LocalPlayer

local HUD = {}

type Slot = { frame: Frame, stroke: UIStroke, key: TextLabel, name: TextLabel, ammo: TextLabel }
type MateRow = { frame: Frame, name: TextLabel, fill: Frame, mult: TextLabel }

local MULT_COLOR = Color3.fromRGB(255, 214, 60)
local HEALTH_GOOD = Color3.fromRGB(80, 220, 90)
local HEALTH_LOW = Color3.fromRGB(230, 50, 40)

local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function bar(parent: Instance, size: UDim2, color: Color3): (Frame, Frame)
	local back = Instance.new("Frame")
	back.Size = size
	back.BackgroundColor3 = UI.DARK
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	UI.round(back, 6)
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	UI.round(fill, 6)
	fill.Parent = back
	return back, fill
end

function HUD.start()
	local gui = UI.screen("HUD", 1)

	-- Health and score
	local healthBack, healthFill = bar(gui, UDim2.fromOffset(240, 22), HEALTH_GOOD)
	healthBack.Position = UDim2.fromOffset(16, 12)
	local healthText = UI.text(healthBack, "100", 16)
	healthText.Size = UDim2.fromScale(1, 1)
	healthText.ZIndex = 2
	local scoreLabel = UI.text(gui, "SCORE 0", 26)
	scoreLabel.Position = UDim2.fromOffset(16, 38)
	scoreLabel.Size = UDim2.fromOffset(300, 32)
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Multiplier
	local multLabel = UI.text(gui, "x1", 64)
	multLabel.AnchorPoint = Vector2.new(0.5, 0)
	multLabel.Position = UDim2.new(0.5, 0, 0, 0)
	multLabel.Size = UDim2.fromOffset(240, 68)
	multLabel.TextColor3 = MULT_COLOR
	local multScale = Instance.new("UIScale")
	multScale.Parent = multLabel
	local multBack, multFill = bar(gui, UDim2.fromOffset(180, 10), MULT_COLOR)
	multBack.AnchorPoint = Vector2.new(0.5, 0)
	multBack.Position = UDim2.new(0.5, 0, 0, 68)

	-- Wave and room
	local waveLabel = UI.text(gui, "WAVE 1", 30)
	waveLabel.AnchorPoint = Vector2.new(1, 0)
	waveLabel.Position = UDim2.new(1, -16, 0, 52)
	waveLabel.Size = UDim2.fromOffset(260, 34)
	waveLabel.TextXAlignment = Enum.TextXAlignment.Right
	local roomLabel = UI.text(gui, "", 16)
	roomLabel.AnchorPoint = Vector2.new(1, 0)
	roomLabel.Position = UDim2.new(1, -16, 0, 84)
	roomLabel.Size = UDim2.fromOffset(260, 20)
	roomLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- Teammates
	local mates = Instance.new("Frame")
	mates.BackgroundTransparency = 1
	mates.AnchorPoint = Vector2.new(1, 0)
	mates.Position = UDim2.new(1, -16, 0, 112)
	mates.Size = UDim2.fromOffset(210, 300)
	mates.Parent = gui
	local mateList = Instance.new("UIListLayout")
	mateList.Padding = UDim.new(0, 6)
	mateList.Parent = mates
	local mateRows: { [Player]: MateRow } = {}

	-- Weapon bar
	local slotsFrame = Instance.new("Frame")
	slotsFrame.BackgroundTransparency = 1
	slotsFrame.AnchorPoint = Vector2.new(0.5, 1)
	slotsFrame.Parent = gui
	local slotLayout = Instance.new("UIListLayout")
	slotLayout.FillDirection = Enum.FillDirection.Horizontal
	slotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	slotLayout.Padding = UDim.new(0, 6)
	slotLayout.Parent = slotsFrame
	local slots: { [string]: Slot } = {}
	for order, id in Config.WEAPON_ORDER do
		local def = Config.WEAPONS[id]
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.BackgroundColor3 = UI.PANEL
		frame.BackgroundTransparency = 0.15
		UI.round(frame, 8)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = UI.DARK
		stroke.Parent = frame
		local key = UI.text(frame, tostring(def.slot % 10), 14)
		key.Position = UDim2.fromOffset(4, 2)
		key.Size = UDim2.fromOffset(14, 14)
		key.TextXAlignment = Enum.TextXAlignment.Left
		local name = UI.text(frame, def.short, 13)
		name.Position = UDim2.fromScale(0, 0.2)
		name.Size = UDim2.fromScale(1, 0.45)
		name.TextScaled = true
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MaxTextSize = 14
		nameLimit.Parent = name
		local ammoLabel = UI.text(frame, "", 14)
		ammoLabel.Position = UDim2.fromScale(0, 0.62)
		ammoLabel.Size = UDim2.fromScale(1, 0.34)
		frame.Parent = slotsFrame
		slots[id] = { frame = frame, stroke = stroke, key = key, name = name, ammo = ammoLabel }
	end

	local function layoutSlots()
		local touch = Input.scheme == "Touch"
		local size = if touch then 46 else 60
		for _, slot in slots do
			slot.frame.Size = UDim2.fromOffset(size, size)
		end
		slotsFrame.Size = UDim2.fromOffset(#Config.WEAPON_ORDER * (size + 6), size)
		if touch then
			slotsFrame.AnchorPoint = Vector2.new(0.5, 0)
			slotsFrame.Position = UDim2.new(0.5, 0, 0, 86)
		else
			slotsFrame.AnchorPoint = Vector2.new(0.5, 1)
			slotsFrame.Position = UDim2.new(0.5, 0, 1, -14)
		end
	end
	layoutSlots()
	Input.SchemeChanged:Connect(layoutSlots)

	local function refreshSlots()
		local equipped = WeaponController.getEquipped()
		for id, slot in slots do
			local owns = WeaponController.owns(id)
			slot.frame.BackgroundTransparency = if owns then 0.15 else 0.6
			slot.name.TextTransparency = if owns then 0 else 0.7
			slot.name.Text = if owns then Config.WEAPONS[id].short else "?"
			slot.stroke.Color = if id == equipped then MULT_COLOR else UI.DARK
			slot.stroke.Thickness = if id == equipped then 3 else 2
			local left = WeaponController.getAmmo(id)
			slot.ammo.Text = if not owns then "" elseif left == nil then "inf" else tostring(left)
			slot.ammo.TextColor3 = if left == 0 then HEALTH_LOW else UI.WHITE
		end
	end
	WeaponController.Changed:Connect(refreshSlots)
	refreshSlots()

	-- Hurt flash
	local hurt = Instance.new("Frame")
	hurt.Size = UDim2.fromScale(1, 1)
	hurt.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	hurt.BackgroundTransparency = 1
	hurt.ZIndex = 0
	hurt.Parent = gui
	local hurtLevel = 0
	Net.event("PlayerHurt").OnClientEvent:Connect(function(amount: number)
		hurtLevel = math.min(0.55, hurtLevel + 0.15 + amount / 100)
	end)

	-- Spectating
	local spectateLabel = UI.text(gui, "", 24)
	spectateLabel.AnchorPoint = Vector2.new(0.5, 1)
	spectateLabel.Position = UDim2.new(0.5, 0, 1, -96)
	spectateLabel.Size = UDim2.fromOffset(500, 30)

	local lastMult = 1
	RunService.RenderStepped:Connect(function(dt: number)
		local inRun = player:GetAttribute("InRun") == true
		gui.Enabled = inRun
		if not inRun then
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local health = if humanoid then math.max(0, humanoid.Health) else 0
		local maxHealth = if humanoid then humanoid.MaxHealth else Config.PLAYER_MAX_HEALTH
		local fraction = math.clamp(health / maxHealth, 0, 1)
		healthFill.Size = UDim2.fromScale(fraction, 1)
		healthFill.BackgroundColor3 = HEALTH_LOW:Lerp(HEALTH_GOOD, fraction)
		healthText.Text = tostring(math.ceil(health))
		local score = player:GetAttribute("Score")
		scoreLabel.Text = "SCORE " .. formatNumber(if typeof(score) == "number" then score else 0)

		-- Work out the multiplier from (base, drain start), like the server does.
		local base, graceEnd = player:GetAttribute("Mult"), player:GetAttribute("MultGraceEnd")
		local now = if workspace:GetAttribute("Paused") == true then -math.huge else workspace:GetServerTimeNow()
		local value, barFill = 1, 0
		if typeof(base) == "number" and typeof(graceEnd) == "number" then
			if now == -math.huge then
				value, barFill = base, 1
			else
				value = Combo.valueAt(base, graceEnd, now)
				barFill = if now < graceEnd then (graceEnd - now) / Config.MULT_DECAY_DELAY else value - math.floor(value)
			end
		end
		local whole = math.floor(value)
		multLabel.Text = "x" .. whole
		if whole > lastMult then
			multScale.Scale = 1.35
		end
		lastMult = whole
		multScale.Scale += (1 - multScale.Scale) * math.min(1, dt * 10)
		multFill.Size = UDim2.fromScale(math.clamp(barFill, 0, 1), 1)

		local wave = ReplicatedStorage:GetAttribute("Wave")
		waveLabel.Text = if typeof(wave) == "number" and wave > 0 then "WAVE " .. wave else "GET READY"
		local roomId, difficulty = ReplicatedStorage:GetAttribute("RoomId"), ReplicatedStorage:GetAttribute("Difficulty")
		local room = if typeof(roomId) == "string" then Rooms.ARENAS[roomId] else nil
		roomLabel.Text = (if room then room.name else "") .. (if typeof(difficulty) == "string" then "  -  " .. string.upper(difficulty) else "")

		-- Teammates
		local seen: { [Player]: boolean } = {}
		for _, other in Players:GetPlayers() do
			if other == player or other:GetAttribute("InRun") ~= true then
				continue
			end
			seen[other] = true
			local row = mateRows[other]
			if not row then
				local frame = Instance.new("Frame")
				frame.Size = UDim2.fromOffset(210, 40)
				frame.BackgroundColor3 = UI.PANEL
				frame.BackgroundTransparency = 0.3
				UI.round(frame, 8)
				local name = UI.text(frame, other.DisplayName, 16)
				name.Position = UDim2.fromOffset(8, 2)
				name.Size = UDim2.fromOffset(140, 20)
				name.TextXAlignment = Enum.TextXAlignment.Left
				local back, fill = bar(frame, UDim2.fromOffset(140, 8), HEALTH_GOOD)
				back.Position = UDim2.fromOffset(8, 25)
				local mult = UI.text(frame, "x1", 22)
				mult.AnchorPoint = Vector2.new(1, 0.5)
				mult.Position = UDim2.new(1, -8, 0.5, 0)
				mult.Size = UDim2.fromOffset(52, 30)
				mult.TextColor3 = MULT_COLOR
				mult.TextXAlignment = Enum.TextXAlignment.Right
				frame.Parent = mates
				row = { frame = frame, name = name, fill = fill, mult = mult }
				mateRows[other] = row
			end
			local current = row :: MateRow
			local otherCharacter = other.Character
			local otherHumanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
			local otherFraction = if otherHumanoid then math.clamp(otherHumanoid.Health / otherHumanoid.MaxHealth, 0, 1) else 0
			current.fill.Size = UDim2.fromScale(otherFraction, 1)
			current.fill.BackgroundColor3 = HEALTH_LOW:Lerp(HEALTH_GOOD, otherFraction)
			local hero = otherCharacter and otherCharacter:FindFirstChild("Hero")
			local torso = hero and hero:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				current.name.TextColor3 = torso.Color:Lerp(Color3.new(1, 1, 1), 0.35)
			end
			local otherBase, otherGrace = other:GetAttribute("Mult"), other:GetAttribute("MultGraceEnd")
			if typeof(otherBase) == "number" and typeof(otherGrace) == "number" and now ~= -math.huge then
				current.mult.Text = "x" .. math.floor(Combo.valueAt(otherBase, otherGrace, now))
			end
		end
		for other, row in mateRows do
			if not seen[other] then
				row.frame:Destroy()
				mateRows[other] = nil
			end
		end

		hurtLevel = math.max(0, hurtLevel - dt * 1.5)
		hurt.BackgroundTransparency = 1 - hurtLevel

		local watching = CameraController.spectating()
		spectateLabel.Text = if watching then "SPECTATING " .. string.upper(watching.DisplayName) .. "   (Q / E to switch)" else ""
	end)
end

return HUD
