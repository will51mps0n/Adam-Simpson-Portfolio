--!strict
-- Milestone 1 test stage: the whole cast stands on a dock so you can look
-- closely at them, try every expression and move, and dress them up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Outfits = require(ReplicatedStorage.Shared.Data.Outfits)
local Characters = require(ReplicatedStorage.Shared.Data.Characters)
local CharacterBuilder = require(ReplicatedStorage.Shared.Character.CharacterBuilder)
local KidAnimator = require(script.Parent.Animation.KidAnimator)
local CameraRig = require(script.Parent.CameraRig)
local Stage = require(script.Stage)
local ShowcaseUI = require(script.ShowcaseUI)

type Entry = {
	id: string,
	name: string,
	outfit: Outfits.Outfit,
	original: Outfits.Outfit,
	home: Vector3,
	kid: CharacterBuilder.Kid?,
	animator: KidAnimator.Animator?,
	tag: TextLabel?,
}

local Showcase = {}

local SPACING = 4.4
local random = Random.new()

local entries: { Entry } = {}
local selected = 0 -- 0 = everyone
local closeUp = false
local spinning = false
local stage: Folder
local ui: ShowcaseUI.UI

local function targets(): { Entry }
	if selected == 0 then
		return entries
	end
	return { entries[selected] }
end

local function refreshTags()
	for i, entry in entries do
		local tag = entry.tag
		if tag then
			local isSelected = i == selected
			tag.Text = if isSelected then "v " .. entry.name .. " v" else entry.name
			tag.TextColor3 = if isSelected then Color3.fromRGB(255, 214, 58) else Color3.new(1, 1, 1)
			tag.Visible = not closeUp
		end
	end
end

local function spawnKid(entry: Entry)
	if entry.animator then
		entry.animator:Destroy()
	end
	if entry.kid then
		entry.kid.Model:Destroy()
	end
	local kid = CharacterBuilder.build(entry.outfit, CFrame.new(entry.home), { name = entry.name, parent = stage :: Instance })
	local animator = KidAnimator.new(kid, { home = entry.home, facing = 1 })
	animator.Turntable = spinning and (selected == 0 or entries[selected] == entry)
	animator.OnGone = function()
		task.delay(1.0, function()
			if entry.animator == animator then
				animator:DropIn()
			end
		end)
	end
	entry.kid = kid
	entry.animator = animator

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Adornee = kid.Root
	billboard.Size = UDim2.fromOffset(170, 30)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, kid.Dims.height + 1.7, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = kid.Model
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromScale(1, 1)
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.FredokaOne
	tag.TextSize = 22
	tag.TextColor3 = Color3.new(1, 1, 1)
	tag.TextStrokeColor3 = Color3.fromRGB(34, 22, 36)
	tag.TextStrokeTransparency = 0
	tag.Parent = billboard
	entry.tag = tag
	refreshTags()
end

------------------------------------------------------------------------
-- Wardrobe

local function cycle(list: { string }, current: string?, step: number): string
	local index = table.find(list, current or "") or 0
	return list[(index - 1 + step) % #list + 1]
end

local function ids(list: { Outfits.CatalogItem }): { string }
	local out = {}
	for _, item in list do
		table.insert(out, item.id)
	end
	return out
end

local function nameOf(list: { Outfits.CatalogItem }, id: string?): string
	local item = Outfits.find(list, id or "None")
	return if item then item.name else (id or "-")
end

local function colorName(value: Outfits.ColorRef?): string
	return if type(value) == "string" then value else "-"
end

local function onOff(value: any): string
	return if value then "On" else "Off"
end

local function wardrobeValues(outfit: Outfits.Outfit): { [string]: string }
	return {
		Skin = colorName(outfit.skin),
		Hair = nameOf(Outfits.HairStyles, outfit.hair.style),
		["Hair color"] = colorName(outfit.hair.color),
		Hat = nameOf(Outfits.Hats, if outfit.hat then outfit.hat.style else "None"),
		Top = nameOf(Outfits.Tops, outfit.top.style),
		["Top color"] = if outfit.top.style == "None" then "-" else colorName(outfit.top.color),
		Bottom = nameOf(Outfits.Bottoms, outfit.bottom.style),
		["Bottom color"] = colorName(outfit.bottom.color),
		Shoes = nameOf(Outfits.Shoes, outfit.shoes.style),
		["Shoe color"] = if outfit.shoes.style == "Bare" then "-" else colorName(outfit.shoes.color),
		Cape = onOff(outfit.cape),
		Goggles = onOff(outfit.goggles),
		["Life ring"] = onOff(outfit.lifeRing),
		Mask = onOff(outfit.mask),
	}
end

local function catalogPiece(list: { Outfits.CatalogItem }, id: string, color: Outfits.ColorRef?): Outfits.Piece
	local item = Outfits.find(list, id)
	return {
		style = id,
		color = (item and item.color) or color,
		accent = item and item.accent,
	}
end

local function randomFrom(list: { string }): string
	return list[random:NextInteger(1, #list)]
end

local function randomOutfit(): Outfits.Outfit
	local hat = randomFrom(ids(Outfits.Hats))
	local top = randomFrom(ids(Outfits.Tops))
	return {
		skin = randomFrom(Outfits.SkinTones),
		hair = { style = randomFrom(ids(Outfits.HairStyles)), color = randomFrom(Outfits.HairColors) },
		hat = if hat == "None" then nil else catalogPiece(Outfits.Hats, hat),
		top = { style = top, color = randomFrom(Outfits.ClothColors), accent = randomFrom(Outfits.ClothColors) },
		bottom = { style = randomFrom(ids(Outfits.Bottoms)), color = randomFrom(Outfits.ClothColors) },
		shoes = { style = randomFrom(ids(Outfits.Shoes)), color = randomFrom(Outfits.ClothColors) },
		cape = if random:NextNumber() < 0.25 then { style = "Cape", color = randomFrom(Outfits.ClothColors) } else nil,
		goggles = if random:NextNumber() < 0.25 then { style = "Goggles" } else nil,
		lifeRing = if random:NextNumber() < 0.2 then { style = "LifeRing" } else nil,
		mask = if random:NextNumber() < 0.15 then randomFrom(Outfits.ClothColors) else nil,
	}
end

local function changeOutfit(entry: Entry, field: string, step: number)
	local o = entry.outfit
	if field == "Random" then
		local fresh = randomOutfit()
		fresh.proportions = o.proportions
		fresh.emblem = o.emblem
		entry.outfit = fresh
	elseif field == "Reset" then
		entry.outfit = Outfits.copy(entry.original)
	elseif field == "Skin" then
		o.skin = cycle(Outfits.SkinTones, colorName(o.skin), step)
	elseif field == "Hair" then
		o.hair.style = cycle(ids(Outfits.HairStyles), o.hair.style, step)
	elseif field == "Hair color" then
		o.hair.color = cycle(Outfits.HairColors, colorName(o.hair.color), step)
	elseif field == "Hat" then
		local id = cycle(ids(Outfits.Hats), if o.hat then o.hat.style else "None", step)
		o.hat = if id == "None" then nil else catalogPiece(Outfits.Hats, id)
	elseif field == "Top" then
		o.top.style = cycle(ids(Outfits.Tops), o.top.style, step)
		o.top.color = o.top.color or "White"
	elseif field == "Top color" then
		o.top.color = cycle(Outfits.ClothColors, colorName(o.top.color), step)
	elseif field == "Bottom" then
		o.bottom.style = cycle(ids(Outfits.Bottoms), o.bottom.style, step)
	elseif field == "Bottom color" then
		o.bottom.color = cycle(Outfits.ClothColors, colorName(o.bottom.color), step)
	elseif field == "Shoes" then
		o.shoes.style = cycle(ids(Outfits.Shoes), o.shoes.style, step)
		o.shoes.color = o.shoes.color or "Red"
	elseif field == "Shoe color" then
		o.shoes.color = cycle(Outfits.ClothColors, colorName(o.shoes.color), step)
	elseif field == "Cape" then
		o.cape = if o.cape then nil else { style = "Cape", color = "Red", accent = "Sunny" }
	elseif field == "Goggles" then
		o.goggles = if o.goggles then nil else { style = "Goggles", color = "Glass", accent = "Aqua" }
	elseif field == "Life ring" then
		o.lifeRing = if o.lifeRing then nil else { style = "LifeRing", color = "Red", accent = "White" }
	elseif field == "Mask" then
		o.mask = if o.mask then nil else "Red"
	end
	spawnKid(entry)
	ui.setWardrobe(wardrobeValues(entry.outfit))
end

------------------------------------------------------------------------
-- Moves

local function doMove(move: string)
	local list = targets()
	if move == "Aim" then
		local anyIdle = false
		for _, entry in list do
			if entry.animator and entry.animator.State ~= "Aim" then
				anyIdle = true
			end
		end
		for _, entry in list do
			if entry.animator then
				entry.animator:Aim(anyIdle)
			end
		end
	elseif move == "Throw" then
		for _, entry in list do
			local animator = entry.animator
			if animator and animator:IsStanding() then
				if animator.State == "Aim" then
					animator:Fire()
				else
					animator:Aim(true)
					task.delay(0.4, function()
						animator:Fire()
					end)
				end
			end
		end
	elseif move == "Hit" then
		for _, entry in list do
			if entry.animator then
				entry.animator:Hit(1)
			end
		end
	elseif move == "Knock" then
		for i, entry in list do
			local animator = entry.animator
			if animator and animator:IsStanding() then
				task.delay((i - 1) * 0.15, function()
					animator:Hit(1)
					task.wait(0.12)
					local landX = Stage.DockLeft - 3 - random:NextNumber(0, 4)
					animator:Knock(animator:LaunchVelocity(landX, random:NextNumber(17, 22)))
				end)
			end
		end
	elseif move == "Win" then
		local anyIdle = false
		for _, entry in list do
			if entry.animator and entry.animator.State ~= "Win" then
				anyIdle = true
			end
		end
		for _, entry in list do
			if entry.animator then
				entry.animator:Win(anyIdle)
			end
		end
	elseif move == "Reset" then
		for _, entry in list do
			if entry.animator then
				entry.animator:Reset()
			end
		end
	end
end

------------------------------------------------------------------------
-- Camera

local function updateCamera()
	if closeUp and selected > 0 then
		local entry = entries[selected]
		local kid, animator = entry.kid, entry.animator
		if kid and animator then
			local position = if animator.State == "Gone" then entry.home else kid.Root.CFrame.Position
			local height = kid.Dims.height
			CameraRig.frame(Vector3.new(position.X, position.Y + height * 0.55, 0), height * 0.55, height * 0.68)
			return
		end
	end
	local left, right = Stage.DockLeft - 8, Stage.DockRight + 5
	CameraRig.frame(Vector3.new((left + right) / 2, Stage.DockY + 2.8, 0), (right - left) / 2, 6)
end

------------------------------------------------------------------------

function Showcase.start()
	stage = Stage.build()
	CameraRig.start()

	local lineup = {
		Characters.Extras[1],
		Characters.Extras[2],
		Characters.Heroes[2],
		Characters.Heroes[1],
		Characters.Extras[3],
		Characters.Extras[4],
		Characters.Extras[5],
	}
	local names = {}
	for i, character in lineup do
		local x = (i - (#lineup + 1) / 2) * SPACING
		local entry: Entry = {
			id = character.id,
			name = character.name,
			outfit = Outfits.copy(character.outfit),
			original = Outfits.copy(character.outfit),
			home = Vector3.new(x, Stage.DockY, 0),
			kid = nil,
			animator = nil,
			tag = nil,
		}
		table.insert(entries, entry)
		table.insert(names, character.name)
	end

	ui = ShowcaseUI.build(names, {
		select = function(index)
			selected = index
			ui.setSelected(index)
			ui.setWardrobe(if index > 0 then wardrobeValues(entries[index].outfit) else nil)
			for i, entry in entries do
				if entry.animator then
					entry.animator.Turntable = spinning and (index == 0 or i == index)
					if not entry.animator.Turntable then
						entry.animator.ExtraYaw = 0
					end
				end
			end
			refreshTags()
		end,
		face = function(expression)
			for _, entry in targets() do
				if entry.animator then
					entry.animator:ShowFace(expression)
				end
			end
		end,
		move = doMove,
		toggle = function(name, on)
			if name == "Close-up" then
				closeUp = on
				refreshTags()
			elseif name == "Spin" then
				spinning = on
				for i, entry in entries do
					if entry.animator then
						entry.animator.Turntable = on and (selected == 0 or i == selected)
						if not entry.animator.Turntable then
							entry.animator.ExtraYaw = 0
						end
					end
				end
			end
		end,
		wardrobe = function(field, step)
			if selected > 0 then
				changeOutfit(entries[selected], field, step)
			end
		end,
	})

	for _, entry in entries do
		spawnKid(entry)
	end
	updateCamera()
	RunService.Heartbeat:Connect(updateCamera)
end

return Showcase
