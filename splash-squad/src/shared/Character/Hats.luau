--!strict
-- Hats, built from parts and sized to sit on top of whatever hair the kid has.
-- To add a hat: write a builder below and list it in Data/Outfits.luau.

local Shapes = require(script.Parent.Shapes)
local HeadShape = require(script.Parent.HeadShape)
local Types = require(script.Parent.Types)
local Palette = require(script.Parent.Parent.Data.Palette)
local Outfits = require(script.Parent.Parent.Data.Outfits)

type Context = Types.Context
type Builder = (ctx: Context, color: Color3, accent: Color3) -> ()

local Hats = {}

local function add(ctx: Context, name: string, size: Vector3, color: Color3, cf: CFrame)
	ctx.addToHead(Shapes.ellipsoid(name, size, color, ctx.model), cf)
end

-- How big a hat's dome must be to cover the hair.
local function domePuff(ctx: Context, extra: number): number
	return math.max(ctx.hairPuff, 1.05) + extra
end

local builders: { [string]: Builder } = {}

builders.Tricorn = function(ctx, color, accent)
	local s, r = ctx.scale, ctx.headRadii
	local puff = domePuff(ctx, 0.05)
	local dome = HeadShape.cap(r, 0.66, 0.35, puff)
	add(ctx, "Crown", dome.size, color, CFrame.new(dome.center))

	-- Three turned-up brim flaps with gold trim. The front one carries a skull badge.
	local brimY = r.Y * 0.74
	local brimRadius = r.X * puff * 0.78
	local flapWidth, flapDepth = r.X * 1.75, r.X * 0.62
	for i, azimuth in { 0, 120, 240 } do
		local flap = CFrame.Angles(0, -math.rad(azimuth), 0)
			* CFrame.new(0, brimY, -brimRadius)
			* CFrame.Angles(math.rad(62), 0, 0)
		add(ctx, "Brim", Vector3.new(flapWidth, 0.22 * s, flapDepth), color, flap)
		add(ctx, "Trim", Vector3.new(flapWidth * 0.95, 0.26 * s, 0.16 * s), accent, flap * CFrame.new(0, 0, -flapDepth * 0.46))
		if i == 1 then
			-- The flap's outer face points along its -Y axis.
			local skull = Shapes.facing((flap * CFrame.new(0, -0.1 * s, 0.02 * s)).Position, -flap.UpVector)
			add(ctx, "Skull", Vector3.new(0.42, 0.38, 0.16) * s, Palette.Cloth.White, skull)
			for side = -1, 1, 2 do
				add(ctx, "SkullEye", Vector3.new(0.1, 0.11, 0.05) * s, Palette.Cloth.Charcoal, skull * CFrame.new(side * 0.08 * s, 0.03 * s, -0.08 * s))
			end
		end
	end
end

builders.VikingHorns = function(ctx, color, accent)
	local s, r = ctx.scale, ctx.headRadii
	local puff = domePuff(ctx, 0.07)
	local helmet = HeadShape.cap(r, 0.5, -0.05, puff)
	add(ctx, "Helmet", helmet.size, color, CFrame.new(helmet.center))
	-- A gold ridge over the top, front to back.
	add(ctx, "Ridge", Vector3.new(0.32 * s, helmet.size.Y * 1.03, helmet.size.Z * 1.03), accent, CFrame.new(helmet.center))

	-- Horns that curve up, made of four shrinking pieces each.
	local hornColor = Palette.Cloth.Horn
	for side = -1, 1, 2 do
		local point = Vector3.new(side * r.X * puff * 0.88, r.Y * 0.4, 0.05 * s)
		local pieces = {
			{ Vector3.new(side * 1, 0.25, 0), Vector3.new(0.54, 0.6, 0.54) },
			{ Vector3.new(side * 0.75, 0.7, 0), Vector3.new(0.44, 0.55, 0.44) },
			{ Vector3.new(side * 0.3, 1, 0), Vector3.new(0.33, 0.5, 0.33) },
			{ Vector3.new(0, 1, 0), Vector3.new(0.21, 0.4, 0.21) },
		}
		for _, piece in pieces do
			local direction = piece[1].Unit
			local size = piece[2] * s
			add(ctx, "Horn", size, hornColor, Shapes.alongY(point + direction * size.Y * 0.4, direction))
			point += direction * size.Y * 0.62
		end
	end
end

builders.Cap = function(ctx, color, accent)
	local s, r = ctx.scale, ctx.headRadii
	local puff = domePuff(ctx, 0.04)
	local dome = HeadShape.cap(r, 0.58, 0.05, puff)
	add(ctx, "Dome", dome.size, color, CFrame.new(dome.center))
	-- The visor is worn cocked to one side so it shows from the front.
	local visor = CFrame.Angles(0, -math.rad(40), 0)
		* CFrame.new(0, r.Y * 0.56, -r.Z * puff * 0.92)
		* CFrame.Angles(math.rad(-14), 0, 0)
	add(ctx, "Visor", Vector3.new(r.X * 1.25, 0.16 * s, r.Z * 1.3), color, visor)
	add(ctx, "Button", Vector3.new(0.26, 0.16, 0.26) * s, accent, CFrame.new(dome.center + Vector3.new(0, dome.size.Y / 2 - 0.02 * s, 0)))
end

builders.Crown = function(ctx, color, accent)
	local s = ctx.scale
	local base = CFrame.new(0, ctx.hairTop - 0.14 * s, 0) * CFrame.Angles(0, 0, math.rad(-10))
	add(ctx, "Band", Vector3.new(1.2, 0.42, 1.2) * s, color, base)
	for i = 0, 4 do
		local angle = math.rad(i * 72)
		local out = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local direction = (Vector3.yAxis + out * 0.3).Unit
		local foot = Vector3.new(out.X * 0.48 * s, 0.12 * s, out.Z * 0.48 * s)
		local tip = foot + direction * 0.44 * s
		add(ctx, "Point", Vector3.new(0.2, 0.46, 0.2) * s, color, base * Shapes.alongY(foot + direction * 0.2 * s, direction))
		add(ctx, "Tip", Vector3.new(0.17, 0.17, 0.17) * s, color, base * CFrame.new(tip))
	end
	add(ctx, "Gem", Vector3.new(0.24, 0.24, 0.16) * s, accent, base * CFrame.new(0, 0, -0.6 * s))
end

builders.Flower = function(ctx, color, accent)
	local s = ctx.scale
	local direction = Shapes.direction(38, 62)
	local base = if ctx.cap
		then HeadShape.onCap(ctx.cap, direction, 1.0)
		else HeadShape.surface(ctx.headRadii, direction, 1.0)
	local facing = (base.Unit + Vector3.new(0, 0, -0.5)).Unit
	local flower = Shapes.facing(base + facing * 0.05 * s, facing)
	for i = 0, 4 do
		local angle = math.rad(i * 72 + 90)
		add(ctx, "Petal", Vector3.new(0.4, 0.4, 0.2) * s, color, flower * CFrame.new(math.cos(angle) * 0.3 * s, math.sin(angle) * 0.3 * s, 0))
	end
	add(ctx, "Middle", Vector3.new(0.3, 0.3, 0.22) * s, accent, flower * CFrame.new(0, 0, -0.07 * s))
end

function Hats.build(ctx: Context, piece: Outfits.Piece?)
	if not piece or piece.style == "None" then
		return
	end
	local builder = builders[piece.style]
	if not builder then
		warn(`[Hats] Unknown hat "{piece.style}"`)
		return
	end
	local defaults = Outfits.find(Outfits.Hats, piece.style)
	local color = Palette.resolve(piece.color or (defaults and defaults.color), Palette.Cloth.Charcoal)
	local accent = Palette.resolve(piece.accent or (defaults and defaults.accent), Palette.Cloth.Gold)
	builder(ctx, color, accent)
end

-- Hats that cover the top of the head (spiky hair hides its top spikes under these).
function Hats.coversTop(piece: Outfits.Piece?): boolean
	return piece ~= nil and piece.style ~= "None" and piece.style ~= "Flower"
end

return Hats
