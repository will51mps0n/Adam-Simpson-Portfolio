--!strict
-- Hair styles, built from parts. Each style starts with a "cap" (a bigger
-- copy of the head nudged up and back, see HeadShape.cap) and adds spikes,
-- curls or a ponytail on top. To add a style: write a builder below and list
-- it in Data/Outfits.luau.

local Shapes = require(script.Parent.Shapes)
local HeadShape = require(script.Parent.HeadShape)
local Types = require(script.Parent.Types)
local Palette = require(script.Parent.Parent.Data.Palette)
local Outfits = require(script.Parent.Parent.Data.Outfits)

type Context = Types.Context
type Builder = (ctx: Context, color: Color3, accent: Color3, underHat: boolean) -> ()

local Hair = {}

local function addCap(ctx: Context, color: Color3, front: number, back: number, puff: number): HeadShape.Cap
	local cap = HeadShape.cap(ctx.headRadii, front, back, puff)
	ctx.addToHead(Shapes.ellipsoid("HairCap", cap.size, color, ctx.model), CFrame.new(cap.center))
	ctx.cap = cap
	ctx.hairTop = cap.center.Y + cap.size.Y / 2
	ctx.hairPuff = puff
	return cap
end

-- A soft spike standing on the cap and leaning outward.
-- { elevation, azimuth, length, width, lean } with angles measured from the cap's center.
local function addSpike(ctx: Context, cap: HeadShape.Cap, color: Color3, spec: { number })
	local s = ctx.scale
	local direction = Shapes.direction(spec[1], spec[2])
	local length, width, lean = spec[3] * s, spec[4] * s, spec[5] or 0.35
	local base = HeadShape.onCap(cap, direction, 0.96)
	local out = (direction + Vector3.yAxis * lean).Unit
	local part = Shapes.ellipsoid("Spike", Vector3.new(width, length, width), color, ctx.model)
	ctx.addToHead(part, Shapes.alongY(base + out * length * 0.3, out))
end

-- Cheap repeatable "random" number between 0 and 1.
local function hash(i: number): number
	local x = math.sin(i * 12.9898) * 43758.5453
	return x - math.floor(x)
end

local builders: { [string]: Builder } = {}

builders.Spiky = function(ctx, color, _accent, underHat)
	local cap = addCap(ctx, color, 0.42, -0.42, 1.05)
	local spikes: { { number } } = if underHat
		then {
			{ 0, 75, 0.7, 0.42, 0.1 },
			{ 0, -75, 0.7, 0.42, 0.1 },
			{ 5, 125, 0.68, 0.42, 0.1 },
			{ 5, -125, 0.68, 0.42, 0.1 },
			{ 8, 180, 0.66, 0.42, 0.1 },
		}
		else {
			{ 86, 10, 0.95, 0.58 },
			{ 62, 35, 0.88, 0.56 },
			{ 64, -30, 0.88, 0.56 },
			{ 52, 90, 0.8, 0.54, 0.5 },
			{ 52, -90, 0.8, 0.54, 0.5 },
			{ 48, 145, 0.78, 0.54 },
			{ 48, -145, 0.78, 0.54 },
			{ 42, 180, 0.74, 0.54 },
			{ 18, 80, 0.62, 0.48, 0.45 },
			{ 18, -80, 0.62, 0.48, 0.45 },
		}
	for _, spec in spikes do
		addSpike(ctx, cap, color, spec)
	end
	if not underHat then
		ctx.hairTop += 0.62 * ctx.scale
	end
end

builders.BowlCut = function(ctx, color, _accent, underHat)
	local cap = addCap(ctx, color, 0.4, -0.5, 1.11)
	if underHat then
		return
	end
	-- A little sprout of hair sticking up on top.
	local s = ctx.scale
	local p0 = HeadShape.onCap(cap, Shapes.direction(80, 160), 0.97)
	local d1 = Vector3.new(0.2, 1, 0.3).Unit
	ctx.addToHead(Shapes.ellipsoid("Sprout", Vector3.new(0.2, 0.42, 0.2) * s, color, ctx.model), Shapes.alongY(p0 + d1 * 0.16 * s, d1))
	local p1 = p0 + d1 * 0.34 * s
	local d2 = Vector3.new(0.3, 0.2, -1).Unit
	ctx.addToHead(Shapes.ellipsoid("Sprout", Vector3.new(0.17, 0.34, 0.17) * s, color, ctx.model), Shapes.alongY(p1 + d2 * 0.12 * s, d2))
end

builders.Ponytail = function(ctx, color, accent, _underHat)
	local cap = addCap(ctx, color, 0.42, -0.35, 1.07)
	local s = ctx.scale
	-- A high ponytail: tied on top toward the back, it arcs up and out, then falls.
	local tie = HeadShape.onCap(cap, Shapes.direction(58, 150), 0.98)
	ctx.addToHead(Shapes.ellipsoid("HairTie", Vector3.new(0.5, 0.3, 0.5) * s, accent, ctx.model), Shapes.alongY(tie, Vector3.new(0.3, 1, 0.5)))
	local point = tie
	local pieces = {
		{ Vector3.new(0.35, 1, 0.55), Vector3.new(0.62, 0.7, 0.62) },
		{ Vector3.new(0.8, 0.1, 0.6), Vector3.new(0.6, 0.75, 0.6) },
		{ Vector3.new(0.6, -0.8, 0.4), Vector3.new(0.52, 0.8, 0.52) },
		{ Vector3.new(0.3, -1, 0.15), Vector3.new(0.38, 0.6, 0.38) },
	}
	for i, piece in pieces do
		local direction = piece[1].Unit
		local size = piece[2] * s
		local name = if i == #pieces then "TailTip" else "Tail"
		ctx.addToHead(Shapes.ellipsoid(name, size, color, ctx.model), Shapes.alongY(point + direction * size.Y * 0.4, direction))
		point += direction * size.Y * 0.62
	end
end

builders.Curly = function(ctx, color, _accent, underHat)
	local cap = addCap(ctx, color, 0.44, -0.45, 1.03)
	local s = ctx.scale
	-- Spread round puffs evenly over the covered part of the head.
	local count = 64
	local golden = math.pi * (3 - math.sqrt(5))
	local highest = 0
	for i = 0, count - 1 do
		local y = 1 - 2 * (i + 0.5) / count
		local r = math.sqrt(1 - y * y)
		local direction = Vector3.new(r * math.cos(i * golden), y, r * math.sin(i * golden))
		if HeadShape.underCap(cap, direction, 0.1) and not (underHat and y > 0.45) then
			local position = HeadShape.surface(ctx.headRadii, direction, 1.04)
			local size = (0.6 + 0.16 * hash(i)) * s
			ctx.addToHead(Shapes.ball("Curl", size, color, ctx.model), CFrame.new(position))
			highest = math.max(highest, position.Y + size / 2)
		end
	end
	ctx.hairTop = math.max(ctx.hairTop, highest)
	ctx.hairPuff = 1.22
end

builders.None = function(ctx)
	ctx.hairTop = ctx.headRadii.Y
	ctx.hairPuff = 1
end

function Hair.build(ctx: Context, piece: Outfits.Piece, underHat: boolean)
	local builder = builders[piece.style]
	if not builder then
		warn(`[Hair] Unknown hair style "{piece.style}"`)
		builder = builders.None
	end
	local color = Palette.resolve(piece.color, Palette.Hair.Chestnut)
	local accent = Palette.resolve(piece.accent, Palette.Cloth.Coral)
	builder(ctx, color, accent, underHat)
end

return Hair
