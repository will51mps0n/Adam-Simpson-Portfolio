--!strict
-- Extras a kid can wear: a towel cape, swim goggles, a life ring and a chest emblem.
-- (The superhero eye mask is drawn on the face, see Face.luau.)

local Shapes = require(script.Parent.Shapes)
local HeadShape = require(script.Parent.HeadShape)
local Types = require(script.Parent.Types)
local Palette = require(script.Parent.Parent.Data.Palette)
local Outfits = require(script.Parent.Parent.Data.Outfits)

type Context = Types.Context

local Accessories = {}

-- Width of the body (a bean shape) at a height, as half-widths in X and Z.
-- `fraction` is 0 at the bottom of the body and 1 at the top.
function Accessories.bodyHalfWidths(dims: Types.Dims, fraction: number): (number, number)
	local t = (fraction - 0.5) / 0.5
	local k = math.sqrt(math.max(0, 1 - t * t))
	return dims.body.X / 2 * k, dims.body.Z / 2 * k
end

-- A thin ring hugging the body at a height (belts, stripes, waistbands).
function Accessories.band(ctx: Context, name: string, fraction: number, thickness: number, color: Color3)
	local d = ctx.dims
	local hx, hz = Accessories.bodyHalfWidths(d, fraction)
	local part = Shapes.ellipsoid(name, Vector3.new(hx * 2.07, thickness, hz * 2.07), color, ctx.model)
	ctx.addToBone(part, "Body", CFrame.new(0, d.body.Y * fraction, 0))
end

function Accessories.cape(ctx: Context, piece: Outfits.Piece)
	local d, s = ctx.dims, ctx.scale
	local color = Palette.resolve(piece.color, Palette.Cloth.Red)
	local knot = Palette.resolve(piece.accent, Palette.Cloth.Sunny)
	local length = d.shoulderY + 0.12 * s - d.leg.Y * 0.45
	local cape = Shapes.ellipsoid("Cape", Vector3.new(d.body.X * 1.5, length, 0.2 * s), color, ctx.model)
	cape.CastShadow = false
	-- The Cape bone sits behind the shoulders; tilt the cape so it flares out at the bottom.
	ctx.addToBone(cape, "Cape", CFrame.Angles(math.rad(-8), 0, 0) * CFrame.new(0, -length / 2 + 0.12 * s, 0.08 * s))
	-- Straps over the shoulders and a knot at the neck.
	for side = -1, 1, 2 do
		local strap = Shapes.ellipsoid("CapeStrap", Vector3.new(0.26 * s, 0.2 * s, d.body.Z * 0.9), color, ctx.model)
		ctx.addInRootSpace(strap, "Body", CFrame.new(side * d.body.X * 0.27, d.bodyTopY - 0.24 * s, 0))
		local tie = Shapes.ball("CapeKnot", 0.28 * s, knot, ctx.model)
		ctx.addInRootSpace(tie, "Body", CFrame.new(side * d.body.X * 0.12, d.bodyTopY - 0.24 * s, -d.body.Z * 0.4))
	end
end

function Accessories.goggles(ctx: Context, piece: Outfits.Piece)
	local s, r = ctx.scale, ctx.headRadii
	local lens = Palette.resolve(piece.color, Palette.Cloth.Glass)
	local strap = Palette.resolve(piece.accent, Palette.Cloth.Aqua)
	local lift = math.max(ctx.hairPuff, 1) + 0.04
	-- Pushed up on the forehead, just above the eyebrows.
	local centers = {}
	for side = -1, 1, 2 do
		local direction = Shapes.direction(36, side * 23)
		local point = HeadShape.surface(r, direction, lift)
		local normal = (HeadShape.normal(r, point) + Vector3.new(0, -0.15, -0.35)).Unit
		local frame = Shapes.facing(point, normal)
		ctx.addToHead(Shapes.ellipsoid("GoggleRim", Vector3.new(0.72, 0.66, 0.14) * s, strap, ctx.model), frame)
		local glass = Shapes.ellipsoid("GoggleLens", Vector3.new(0.56, 0.5, 0.14) * s, lens, ctx.model)
		glass.Reflectance = 0.15
		ctx.addToHead(glass, frame * CFrame.new(0, 0, -0.04 * s))
		ctx.addToHead(Shapes.ball("GoggleShine", 0.13 * s, Palette.Cloth.White, ctx.model), frame * CFrame.new(-0.12 * s, 0.1 * s, -0.09 * s))
		table.insert(centers, point)
	end
	ctx.addToHead(
		Shapes.ellipsoid("GoggleBridge", Vector3.new((centers[2] - centers[1]).Magnitude * 0.5, 0.1 * s, 0.1 * s), strap, ctx.model),
		CFrame.new((centers[1] + centers[2]) / 2)
	)
	-- The strap goes around the head (over the hair) at the same height.
	local y = centers[1].Y
	local cap = ctx.cap
	local rx, rz, cz
	if cap then
		local capRadii = cap.size / 2
		local t = math.clamp((y - cap.center.Y) / capRadii.Y, -0.95, 0.95)
		local k = math.sqrt(1 - t * t) * 1.02
		rx, rz, cz = capRadii.X * k, capRadii.Z * k, cap.center.Z
	else
		local t = math.clamp(y / r.Y, -0.95, 0.95)
		local k = math.sqrt(1 - t * t) * 1.03
		rx, rz, cz = r.X * k, r.Z * k, 0
	end
	ctx.addToHead(Shapes.ellipsoid("GoggleStrap", Vector3.new(rx * 2, 0.16 * s, rz * 2), strap, ctx.model), CFrame.new(0, y, cz))
end

function Accessories.lifeRing(ctx: Context, piece: Outfits.Piece)
	local d, s = ctx.dims, ctx.scale
	local color = Palette.resolve(piece.color, Palette.Cloth.Red)
	local stripe = Palette.resolve(piece.accent, Palette.Cloth.White)
	local fraction = 0.34
	local hx, hz = Accessories.bodyHalfWidths(d, fraction)
	local tube = 0.46 * s
	local rx, rz = hx + tube * 0.3, hz + tube * 0.3
	local count = 16
	for i = 0, count - 1 do
		local a = i / count * 2 * math.pi
		local position = Vector3.new(rx * math.cos(a), d.body.Y * fraction, rz * math.sin(a))
		local tangent = Vector3.new(-rx * math.sin(a), 0, rz * math.cos(a))
		local part = Shapes.ellipsoid("LifeRing", Vector3.new(tube, tube, tube * 1.3), if (i // 2) % 2 == 0 then color else stripe, ctx.model)
		ctx.addToBone(part, "Body", Shapes.facing(position, tangent))
	end
end

-- A felt badge on the chest with a letter on it.
function Accessories.emblem(ctx: Context, emblem: { letter: string, color: Outfits.ColorRef?, ink: Outfits.ColorRef? })
	local d, s = ctx.dims, ctx.scale
	local fraction = 0.6
	local _, hz = Accessories.bodyHalfWidths(d, fraction)
	local badge = Shapes.carrier("Emblem", Vector3.new(0.72, 0.72, 0.05) * s, ctx.model)
	ctx.addToBone(badge, "Body", CFrame.new(0, d.body.Y * fraction, -hz - 0.03 * s), true)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "EmblemGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(100, 100)
	gui.LightInfluence = 0.6
	gui.Adornee = badge
	gui.Parent = badge

	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = Palette.resolve(emblem.color, Palette.Cloth.Sunny)
	disc.BorderSizePixel = 0
	disc.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = disc

	local label = Instance.new("TextLabel")
	label.Name = "Letter"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = emblem.letter
	label.TextScaled = true
	label.TextColor3 = Palette.resolve(emblem.ink, Palette.Cloth.Red)
	label.Parent = disc
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.14, 0)
	padding.PaddingBottom = UDim.new(0.14, 0)
	padding.Parent = label
end

return Accessories
