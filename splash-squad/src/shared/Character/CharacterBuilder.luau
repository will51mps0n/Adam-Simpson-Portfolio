--!strict
-- Builds a chibi cartoon kid from parts: a big round head with a drawn face,
-- a bean body, stubby arms and legs, mitten hands and round shoes, then
-- dresses them from an outfit (see Data/Outfits.luau).
--
-- Usage:
--   local kid = CharacterBuilder.build(outfit, CFrame.new(0, 1, 0), { name = "Pip" })
--   kid.Face:SetExpression("Win")

local Config = require(script.Parent.Parent.Config)
local Palette = require(script.Parent.Parent.Data.Palette)
local Outfits = require(script.Parent.Parent.Data.Outfits)
local Shapes = require(script.Parent.Shapes)
local KidRig = require(script.Parent.KidRig)
local Face = require(script.Parent.Face)
local Hair = require(script.Parent.Hair)
local Hats = require(script.Parent.Hats)
local Accessories = require(script.Parent.Accessories)
local Outline = require(script.Parent.Outline)
local Types = require(script.Parent.Types)

export type Dims = Types.Dims

export type Kid = {
	Model: Model,
	Root: BasePart,
	Head: BasePart,
	Rig: KidRig.Rig,
	Face: Face.Face,
	Dims: Dims,
	Outfit: Outfits.Outfit,
	Highlight: Highlight?,
}

export type BuildOptions = {
	name: string?,
	parent: Instance?, -- default: Workspace
	outline: boolean?, -- default: true
}

local CharacterBuilder = {}

function CharacterBuilder.measure(outfit: Outfits.Outfit): Dims
	local K = Config.Kid
	local proportions: { scale: number?, bodyStretch: number?, headScale: number? } = outfit.proportions or {}
	local s = proportions.scale or 1
	local stretch = proportions.bodyStretch or 1
	local headScale = proportions.headScale or 1
	local tall = Vector3.new(1, stretch, 1)

	local head = K.HeadSize * s * headScale
	local body = K.BodySize * s * tall
	local leg = K.LegSize * s * tall
	local arm = K.ArmSize * s * Vector3.new(1, stretch ^ 0.6, 1)
	local shoe = K.ShoeSize * s

	local legTopY = shoe.Y * 0.55 + leg.Y
	local bodyBottomY = legTopY - leg.Y * 0.3
	local bodyTopY = bodyBottomY + body.Y
	local neckY = bodyTopY - K.HeadSink * s * headScale
	local headCenterY = neckY + head.Y / 2
	local shoulderY = bodyTopY - K.ShoulderDrop * s * math.sqrt(stretch)
	local fromCenter = (shoulderY - (bodyBottomY + body.Y / 2)) / (body.Y / 2)
	local shoulderX = body.X / 2 * math.sqrt(math.max(0, 1 - fromCenter * fromCenter)) * 0.9

	return {
		scale = s,
		head = head,
		body = body,
		leg = leg,
		arm = arm,
		hand = K.HandSize * s,
		shoe = shoe,
		feet = K.FeetSize * s,
		legSpread = K.LegSpread * s,
		legTopY = legTopY,
		bodyBottomY = bodyBottomY,
		bodyTopY = bodyTopY,
		neckY = neckY,
		headCenterY = headCenterY,
		height = headCenterY + head.Y / 2,
		shoulderY = shoulderY,
		shoulderX = shoulderX,
	}
end

function CharacterBuilder.build(outfit: Outfits.Outfit, cframe: CFrame, options: BuildOptions?): Kid
	local opts: BuildOptions = options or {}
	local d = CharacterBuilder.measure(outfit)
	local s = d.scale

	local model = Instance.new("Model")
	model.Name = opts.name or "Kid"
	local root = Shapes.carrier("Root", Vector3.new(0.4, 0.4, 0.4) * s, model)
	model.PrimaryPart = root

	-- Skeleton. The root sits on the ground between the feet; the kid faces -Z.
	local rig = KidRig.new(root)
	local restAngle = math.rad(Config.Kid.ArmRestAngle)
	KidRig.addBone(rig, "Body", "Root", CFrame.new(0, d.bodyBottomY, 0))
	KidRig.addBone(rig, "Head", "Body", CFrame.new(0, d.neckY - d.bodyBottomY, 0))
	KidRig.addBone(rig, "ArmR", "Body", CFrame.new(d.shoulderX, d.shoulderY - d.bodyBottomY, 0) * CFrame.Angles(0, 0, restAngle))
	KidRig.addBone(rig, "ArmL", "Body", CFrame.new(-d.shoulderX, d.shoulderY - d.bodyBottomY, 0) * CFrame.Angles(0, 0, -restAngle))
	KidRig.addBone(rig, "LegR", "Root", CFrame.new(d.legSpread, d.legTopY, 0))
	KidRig.addBone(rig, "LegL", "Root", CFrame.new(-d.legSpread, d.legTopY, 0))
	KidRig.addBone(rig, "Cape", "Body", CFrame.new(0, d.shoulderY - d.bodyBottomY + 0.12 * s, d.body.Z * 0.32))

	local headCenter = CFrame.new(0, d.head.Y / 2, 0) -- head center in Head-bone space
	local ctx: Types.Context = {
		model = model,
		dims = d,
		scale = s,
		skin = Palette.resolve(outfit.skin, Palette.Skin.Peach),
		headRadii = d.head / 2,
		cap = nil,
		hairTop = d.head.Y / 2,
		hairPuff = 1,
		addToHead = function(part, headSpace)
			KidRig.attach(rig, part, "Head", headCenter * headSpace)
		end,
		addToBone = function(part, bone, boneSpace, squashBySize)
			KidRig.attach(rig, part, bone, boneSpace, squashBySize)
		end,
		addInRootSpace = function(part, bone, rootSpace)
			KidRig.attachInRootSpace(rig, part, bone, rootSpace)
		end,
	}

	-- Colors
	local skin = ctx.skin
	local topStyle = outfit.top.style
	local topColor = if topStyle == "None" then skin else Palette.resolve(outfit.top.color, Palette.Cloth.White)
	local topAccent = Palette.resolve(
		outfit.top.accent or (Outfits.find(Outfits.Tops, topStyle) or {} :: any).accent,
		Palette.Cloth.Red
	)
	local bottomStyle = outfit.bottom.style
	local bottomColor = Palette.resolve(outfit.bottom.color, Palette.Cloth.Navy)
	local armColor = if topStyle == "Suit" then topColor else skin
	local legColor = if bottomStyle == "Pants"
		then bottomColor
		elseif topStyle == "Suit" then topColor
		else skin

	-- Body and head
	local body = Shapes.ellipsoid("Body", d.body, topColor, model)
	ctx.addToBone(body, "Body", CFrame.new(0, d.body.Y / 2, 0))

	local head = Shapes.ellipsoid("Head", d.head, skin, model)
	ctx.addToBone(head, "Head", headCenter, true)
	local face = Face.new(head, {
		skin = skin,
		mask = if outfit.mask then Palette.resolve(outfit.mask) else nil,
	})

	-- Arms with mitten hands (and sleeves for t-shirts).
	for _, bone in { "ArmR", "ArmL" } do
		local inset = d.arm.X * 0.3
		local arm = Shapes.ellipsoid(bone, d.arm, armColor, model)
		ctx.addToBone(arm, bone, CFrame.new(0, -(d.arm.Y / 2 - inset), 0))
		local hand = Shapes.ellipsoid("Hand", d.hand, skin, model)
		ctx.addToBone(hand, bone, CFrame.new(0, -(d.arm.Y - inset) + d.hand.Y * 0.18, 0))
		if topStyle == "Tee" or topStyle == "Stripes" then
			local sleeve = Shapes.ellipsoid("Sleeve", d.arm * Vector3.new(1.32, 0.52, 1.32), topColor, model)
			ctx.addToBone(sleeve, bone, CFrame.new(0, -d.arm.Y * 0.16, 0))
		end
	end

	-- Legs and shoes
	local shoes = outfit.shoes
	local shoeColor = Palette.resolve(shoes.color, Palette.Cloth.Red)
	local shoeAccent = Palette.resolve(shoes.accent, Palette.Cloth.White)
	for _, bone in { "LegR", "LegL" } do
		local leg = Shapes.ellipsoid(bone, d.leg, legColor, model)
		ctx.addToBone(leg, bone, CFrame.new(0, -d.leg.Y / 2, 0))
		if bottomStyle == "Shorts" then
			local cuff = Shapes.ellipsoid("ShortsLeg", d.leg * Vector3.new(1.3, 0.55, 1.3), bottomColor, model)
			ctx.addToBone(cuff, bone, CFrame.new(0, -d.leg.Y * 0.22, 0))
		end

		if shoes.style == "Bare" then
			local foot = Shapes.ellipsoid("Foot", d.feet, skin, model)
			ctx.addToBone(foot, bone, CFrame.new(0, d.feet.Y / 2 - d.legTopY, -d.feet.Z * 0.14))
		else
			local shoe = Shapes.ellipsoid("Shoe", d.shoe, shoeColor, model)
			ctx.addToBone(shoe, bone, CFrame.new(0, d.shoe.Y / 2 - d.legTopY, -d.shoe.Z * 0.14))
			if shoes.style == "Sneakers" then
				local sole = Shapes.ellipsoid("Sole", d.shoe * Vector3.new(1.06, 0.42, 1.04), shoeAccent, model)
				ctx.addToBone(sole, bone, CFrame.new(0, d.shoe.Y * 0.2 - d.legTopY, -d.shoe.Z * 0.14))
			elseif shoes.style == "Boots" then
				local shaft = Shapes.ellipsoid("BootShaft", d.leg * Vector3.new(1.32, 0.72, 1.32), shoeColor, model)
				ctx.addToBone(shaft, bone, CFrame.new(0, -d.leg.Y * 0.68, 0))
				local cuff = Shapes.ellipsoid("BootCuff", d.leg * Vector3.new(1.34, 0.16, 1.34), shoeColor:Lerp(Palette.Cloth.White, 0.3), model)
				ctx.addToBone(cuff, bone, CFrame.new(0, -d.leg.Y * 0.36, 0))
			end
		end
	end

	-- Bottoms: a rounded overlay on the lower part of the bean.
	local trunks = Shapes.ellipsoid("Bottoms", d.body * Vector3.new(1.07, 0.56, 1.07), bottomColor, model)
	ctx.addToBone(trunks, "Body", CFrame.new(0, d.body.Y * 0.24, 0))
	local bottomAccent = outfit.bottom.accent or (Outfits.find(Outfits.Bottoms, bottomStyle) or {} :: any).accent
	if bottomAccent then
		Accessories.band(ctx, "Waistband", 0.37, d.body.Y * 0.07, Palette.resolve(bottomAccent))
	end

	-- Tops
	if topStyle == "Stripes" then
		Accessories.band(ctx, "Stripe", 0.52, d.body.Y * 0.085, topAccent)
		Accessories.band(ctx, "Stripe", 0.7, d.body.Y * 0.085, topAccent)
	elseif topStyle == "Suit" then
		Accessories.band(ctx, "Belt", 0.43, d.body.Y * 0.1, topAccent)
	end

	-- Hair, hat and extras
	Hair.build(ctx, outfit.hair, Hats.coversTop(outfit.hat))
	Hats.build(ctx, outfit.hat)
	if outfit.cape then
		Accessories.cape(ctx, outfit.cape)
	end
	if outfit.goggles then
		Accessories.goggles(ctx, outfit.goggles)
	end
	if outfit.lifeRing then
		Accessories.lifeRing(ctx, outfit.lifeRing)
	end
	if outfit.emblem then
		Accessories.emblem(ctx, outfit.emblem)
	end

	local kid: Kid = {
		Model = model,
		Root = root,
		Head = head,
		Rig = rig,
		Face = face,
		Dims = d,
		Outfit = outfit,
		Highlight = nil,
	}

	KidRig.apply(rig, { root = cframe })
	model.Parent = opts.parent or workspace
	if opts.outline ~= false then
		kid.Highlight = Outline.add(model)
	end
	return kid
end

function CharacterBuilder.destroy(kid: Kid)
	kid.Model:Destroy()
end

return CharacterBuilder
