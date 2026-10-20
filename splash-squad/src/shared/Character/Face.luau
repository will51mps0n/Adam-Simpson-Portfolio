--!strict
-- Draws a kid's face with a SurfaceGui on the front of the head: eyes with
-- shine dots, eyebrows, blush and a mouth, all made of rounded Frames.
-- Every expression's pieces are built once and switched on and off, so
-- changing expression is instant.
--
-- Curved lines (smiles, closed eyes, dizzy spirals) are chains of short
-- rounded bars. Layout numbers live in Config.Face.

local Config = require(script.Parent.Parent.Config)
local Palette = require(script.Parent.Parent.Data.Palette)

export type Expression = {
	eyes: string,
	brows: string,
	mouth: string,
	blush: number, -- blush transparency (0 = strong, 1 = none)
}

local Face = {}
Face.__index = Face

Face.Expressions = {
	Idle = { eyes = "Open", brows = "Normal", mouth = "Smile", blush = 0.4 },
	Aiming = { eyes = "Smug", brows = "Smug", mouth = "Smirk", blush = 0.5 },
	Fire = { eyes = "Open", brows = "Determined", mouth = "Grin", blush = 0.4 },
	Hit = { eyes = "Squeezed", brows = "Worried", mouth = "O", blush = 0.25 },
	Flying = { eyes = "Spiral", brows = "Raised", mouth = "BigOpen", blush = 0.35 },
	Wet = { eyes = "Droopy", brows = "Worried", mouth = "Frown", blush = 0.55 },
	Win = { eyes = "Happy", brows = "Raised", mouth = "BigSmile", blush = 0.15 },
} :: { [string]: Expression }

Face.ExpressionOrder = { "Idle", "Aiming", "Fire", "Hit", "Flying", "Wet", "Win" }

type Spiral = { frame: Frame, direction: number }

type FaceData = {
	Gui: SurfaceGui,
	Groups: { [string]: { [string]: Frame } },
	Blush: { Frame },
	Spirals: { Spiral },
	Expression: string,
	EyesShown: string,
	BlinkToken: number,
}

export type Face = typeof(setmetatable({} :: FaceData, Face))

export type FaceOptions = {
	skin: Color3?, -- dark skin gets a soft light rim around the lines so they stay readable
	mask: Color3?, -- superhero eye mask
}

------------------------------------------------------------------------
-- Drawing helpers. All positions are in canvas pixels.

type FrameOptions = {
	transparency: number?,
	rounded: boolean?,
	rotation: number?,
	z: number?,
	name: string?,
	halo: boolean?, -- draw a light rim behind this shape (dark skin only)
}

-- Light rim color for the face being built (nil = no rims).
local halo: Color3? = nil
local HALO_WIDTH = 5

local function shape(parent: GuiObject, center: Vector2, size: Vector2, color: Color3, options: FrameOptions?): Frame
	local opts: FrameOptions = options or {}
	if opts.halo and halo then
		shape(parent, center, size + Vector2.new(HALO_WIDTH, HALO_WIDTH), halo, {
			rotation = opts.rotation,
			z = (opts.z or 1) - 1,
			name = "Rim",
		})
	end
	local frame = Instance.new("Frame")
	frame.Name = opts.name or "Shape"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset(center.X, center.Y)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = opts.transparency or 0
	frame.BorderSizePixel = 0
	frame.Rotation = opts.rotation or 0
	frame.ZIndex = opts.z or 1
	if opts.rounded ~= false then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
	end
	frame.Parent = parent
	return frame
end

local function layer(parent: Instance, name: string, z: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	frame.Parent = parent
	return frame
end

-- A rounded bar from a to b; overlapping bars make smooth curves.
local function bar(parent: GuiObject, a: Vector2, b: Vector2, thickness: number, color: Color3)
	local delta = b - a
	shape(parent, (a + b) / 2, Vector2.new(delta.Magnitude + thickness, thickness), color, {
		rotation = math.deg(math.atan2(delta.Y, delta.X)),
		name = "Line",
		z = 2,
		halo = true,
	})
end

local function polyline(parent: GuiObject, points: { Vector2 }, thickness: number, color: Color3)
	for i = 1, #points - 1 do
		bar(parent, points[i], points[i + 1], thickness, color)
	end
end

-- Points on an elliptical arc. Angles in degrees, 0 = right, 90 = up.
local function arc(center: Vector2, rx: number, ry: number, from: number, to: number, segments: number): { Vector2 }
	local points = {}
	for i = 0, segments do
		local a = math.rad(from + (to - from) * i / segments)
		table.insert(points, center + Vector2.new(rx * math.cos(a), -ry * math.sin(a)))
	end
	return points
end

-- Open mouth: the bottom half of a dark oval, with an optional tongue and teeth.
local function halfOval(parent: GuiObject, center: Vector2, width: number, depth: number, tongue: boolean, teeth: boolean)
	local clip = Instance.new("Frame")
	clip.Name = "Clip"
	clip.Position = UDim2.fromOffset(center.X - width / 2, center.Y - depth * 0.5)
	clip.Size = UDim2.fromOffset(width, depth)
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Parent = parent
	shape(clip, Vector2.new(width / 2, 0), Vector2.new(width, depth * 2), Palette.Face.MouthInside, {
		name = "Inside",
		z = 2,
		halo = true,
	})
	if tongue then
		shape(clip, Vector2.new(width / 2, depth * 0.7), Vector2.new(width * 0.5, depth * 0.44), Palette.Face.Tongue, {
			name = "Tongue",
			z = 3,
		})
	end
	if teeth then
		shape(clip, Vector2.new(width / 2, depth * 0.1), Vector2.new(width * 0.8, depth * 0.22), Palette.Face.Teeth, {
			name = "Teeth",
			z = 3,
		})
	end
end

------------------------------------------------------------------------

function Face.new(head: BasePart, options: FaceOptions?): Face
	local opts: FaceOptions = options or {}
	local F = Config.Face
	local cw = Config.Kid.HeadSize.X * F.PixelsPerStud
	local ch = Config.Kid.HeadSize.Y * F.PixelsPerStud

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(cw, ch)
	gui.LightInfluence = F.LightInfluence
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Adornee = head
	gui.Parent = head

	local self: Face = setmetatable({
		Gui = gui,
		Groups = { Eyes = {}, Brows = {}, Mouth = {} },
		Blush = {},
		Spirals = {},
		Expression = "Idle",
		EyesShown = "Open",
		BlinkToken = 0,
	} :: FaceData, Face)

	-- Dark skin: rim the lines in a lighter shade of the skin so they still read.
	halo = nil
	if opts.skin then
		local brightness = 0.299 * opts.skin.R + 0.587 * opts.skin.G + 0.114 * opts.skin.B
		local amount = math.clamp((0.55 - brightness) * 1.6, 0, 0.45)
		if amount > 0.02 then
			halo = opts.skin:Lerp(Color3.new(1, 1, 1), amount)
		end
	end

	local line = cw * F.LineThickness
	local ew, eh = cw * F.EyeWidth, ch * F.EyeHeight
	local ey = ch * F.EyeY
	local eyeColor = Palette.Face.Eye
	local shine = Palette.Face.Shine

	-- Blush
	local blushLayer = layer(gui, "Blush", 1)
	for side = -1, 1, 2 do
		local blush = shape(
			blushLayer,
			Vector2.new(cw * (0.5 + side * F.BlushSpacing / 2), ch * F.BlushY),
			Vector2.new(cw * F.BlushWidth, ch * F.BlushHeight),
			Palette.Face.Blush,
			{ transparency = 0.4, name = "Blush" }
		)
		table.insert(self.Blush, blush)
	end

	-- Superhero mask: a band behind the eyes with white eye holes.
	if opts.mask then
		local maskLayer = layer(gui, "Mask", 2)
		shape(
			maskLayer,
			Vector2.new(cw * 0.5, ey - eh * 0.02),
			Vector2.new(cw * (F.EyeSpacing + F.EyeWidth * 2.3), eh * 1.12),
			opts.mask,
			{ name = "Band" }
		)
		for side = -1, 1, 2 do
			shape(
				maskLayer,
				Vector2.new(cw * (0.5 + side * F.EyeSpacing / 2), ey),
				Vector2.new(ew * 1.6, eh * 1.18),
				shine,
				{ name = "Hole", z = 2 }
			)
		end
	end

	-- Eyes: one group per look. `side` is -1 for the eye on the viewer's left.
	local function eyeGroup(name: string, draw: (group: Frame, ex: number, side: number, inward: number) -> ())
		local group = layer(gui, "Eyes" .. name, 3)
		for side = -1, 1, 2 do
			draw(group, cw * (0.5 + side * F.EyeSpacing / 2), side, -side)
		end
		self.Groups.Eyes[name] = group
	end

	eyeGroup("Open", function(group, ex)
		shape(group, Vector2.new(ex, ey), Vector2.new(ew, eh), eyeColor, { name = "Eye", z = 2, halo = true })
		local d = ew * F.ShineSize
		shape(group, Vector2.new(ex - ew * 0.17, ey - eh * 0.2), Vector2.new(d, d), shine, { z = 3, name = "Shine" })
		shape(group, Vector2.new(ex + ew * 0.2, ey + eh * 0.22), Vector2.new(d * 0.42, d * 0.42), shine, {
			z = 3,
			name = "Shine",
		})
	end)

	eyeGroup("Closed", function(group, ex)
		polyline(group, arc(Vector2.new(ex, ey - eh * 0.05), ew * 0.6, eh * 0.18, 200, 340, 5), line, eyeColor)
	end)

	eyeGroup("Smug", function(group, ex, _side, inward)
		local cy = ey + eh * 0.18
		shape(group, Vector2.new(ex, cy), Vector2.new(ew, eh * 0.58), eyeColor, { name = "Eye", z = 2, halo = true })
		local lidY = cy - eh * 0.29 + 1
		bar(
			group,
			Vector2.new(ex - inward * ew * 0.66, lidY - 2),
			Vector2.new(ex + inward * ew * 0.62, lidY + 3),
			line * 1.1,
			eyeColor
		)
		local d = ew * 0.32
		shape(group, Vector2.new(ex - ew * 0.15, cy - eh * 0.04), Vector2.new(d, d), shine, { z = 3, name = "Shine" })
	end)

	eyeGroup("Squeezed", function(group, ex, _side, inward)
		polyline(group, {
			Vector2.new(ex - inward * ew * 0.55, ey - eh * 0.3),
			Vector2.new(ex + inward * ew * 0.5, ey + 1),
			Vector2.new(ex - inward * ew * 0.55, ey + eh * 0.3),
		}, line * 1.15, eyeColor)
	end)

	eyeGroup("Spiral", function(group, ex, side)
		local size = ew * 1.5
		local spin = Instance.new("Frame")
		spin.Name = "Spin"
		spin.AnchorPoint = Vector2.new(0.5, 0.5)
		spin.Position = UDim2.fromOffset(ex, ey)
		spin.Size = UDim2.fromOffset(size, size)
		spin.BackgroundTransparency = 1
		spin.Parent = group
		local points = {}
		local turns, maxR = 2.25, ew * 0.62
		local total = turns * 2 * math.pi
		local a = 0
		while a <= total do
			local r = 1 + (maxR - 1) * a / total
			table.insert(points, Vector2.new(size / 2 + r * math.cos(a * side), size / 2 - r * math.sin(a * side)))
			a += 0.42
		end
		polyline(spin, points, line * 0.9, eyeColor)
		table.insert(self.Spirals, { frame = spin, direction = side })
	end)

	eyeGroup("Droopy", function(group, ex, side, inward)
		local cy = ey + eh * 0.15
		shape(group, Vector2.new(ex, cy), Vector2.new(ew * 0.95, eh * 0.62), eyeColor, { name = "Eye", z = 2, halo = true })
		local lidY = cy - eh * 0.31
		bar(
			group,
			Vector2.new(ex - inward * ew * 0.66, lidY + 7),
			Vector2.new(ex + inward * ew * 0.6, lidY - 2),
			line * 1.1,
			eyeColor
		)
		local d = ew * 0.42
		shape(group, Vector2.new(ex - ew * 0.12, cy - eh * 0.02), Vector2.new(d, d), shine, { z = 3, name = "Shine" })
		shape(group, Vector2.new(ex + ew * 0.18, cy + eh * 0.14), Vector2.new(d * 0.45, d * 0.45), shine, {
			z = 3,
			name = "Shine",
		})
		if side == 1 then
			shape(group, Vector2.new(ex + ew * 0.55, ey + eh * 0.55), Vector2.new(ew * 0.3, ew * 0.48), Palette.Face.Tear, {
				name = "Tear",
			})
		end
	end)

	eyeGroup("Happy", function(group, ex)
		polyline(group, arc(Vector2.new(ex, ey + eh * 0.15), ew * 0.62, eh * 0.4, 15, 165, 6), line * 1.15, eyeColor)
	end)

	-- Eyebrows: { drop in pixels, tilt in degrees (clockwise), arch } for the left and right brow.
	local browSets: { [string]: { { number } } } = {
		Normal = { { 0, -7, 3 }, { 0, 7, 3 } },
		Smug = { { 6, 14, 1 }, { -7, 5, 5 } },
		Determined = { { 4, 18, 1 }, { 4, -18, 1 } },
		Worried = { { -4, -16, 2 }, { -4, 16, 2 } },
		Raised = { { -11, -8, 5 }, { -11, 8, 5 } },
	}
	local browLength = cw * F.BrowLength
	local browColor = Palette.Face.Brow
	for name, sides in browSets do
		local group = layer(gui, "Brows" .. name, 4)
		for i, side in { -1, 1 } do
			local spec = sides[i]
			local center = Vector2.new(cw * (0.5 + side * F.EyeSpacing / 2), ch * F.BrowY + spec[1])
			local tilt = math.rad(spec[2])
			local cos, sin = math.cos(tilt), math.sin(tilt)
			local points = {}
			for _, p in { Vector2.new(-browLength / 2, 0), Vector2.new(0, -spec[3]), Vector2.new(browLength / 2, 0) } do
				table.insert(points, center + Vector2.new(p.X * cos - p.Y * sin, p.X * sin + p.Y * cos))
			end
			polyline(group, points, line * 0.95, browColor)
		end
		self.Groups.Brows[name] = group
	end

	-- Mouths
	local mx, my = cw * 0.5, ch * F.MouthY
	local mw = cw * F.MouthWidth
	local mouthLine = Palette.Face.MouthLine
	local function mouthGroup(name: string, draw: (group: Frame) -> ())
		local group = layer(gui, "Mouth" .. name, 5)
		draw(group)
		self.Groups.Mouth[name] = group
	end

	mouthGroup("Smile", function(group)
		polyline(group, arc(Vector2.new(mx, my - mw * 0.3), mw * 0.5, mw * 0.42, 200, 340, 7), line, mouthLine)
	end)
	mouthGroup("Smirk", function(group)
		polyline(group, arc(Vector2.new(mx + mw * 0.1, my - mw * 0.28), mw * 0.46, mw * 0.36, 225, 378, 8), line, mouthLine)
	end)
	mouthGroup("Grin", function(group)
		halfOval(group, Vector2.new(mx, my), mw * 1.3, mw * 1.3 * 0.58, true, true)
	end)
	mouthGroup("O", function(group)
		shape(group, Vector2.new(mx, my + 2), Vector2.new(mw * 0.48, mw * 0.58), Palette.Face.MouthInside, {
			name = "O",
			z = 2,
			halo = true,
		})
	end)
	mouthGroup("BigOpen", function(group)
		shape(group, Vector2.new(mx, my + 5), Vector2.new(mw * 0.82, mw * 1.0), Palette.Face.MouthInside, {
			name = "Open",
			z = 2,
			halo = true,
		})
		shape(group, Vector2.new(mx, my + 5 + mw * 0.27), Vector2.new(mw * 0.48, mw * 0.3), Palette.Face.Tongue, {
			name = "Tongue",
			z = 3,
		})
	end)
	mouthGroup("Frown", function(group)
		polyline(group, arc(Vector2.new(mx, my + mw * 0.35), mw * 0.42, mw * 0.32, 25, 155, 6), line, mouthLine)
	end)
	mouthGroup("BigSmile", function(group)
		halfOval(group, Vector2.new(mx, my - 2), mw * 1.55, mw * 1.55 * 0.62, true, false)
	end)

	halo = nil
	self:SetExpression("Idle")
	return self
end

function Face._show(self: Face, category: string, name: string)
	for groupName, group in self.Groups[category] do
		group.Visible = groupName == name
	end
	if category == "Eyes" then
		self.EyesShown = name
	end
end

function Face.SetExpression(self: Face, name: string)
	local expression = Face.Expressions[name]
	if not expression then
		warn(`[Face] Unknown expression "{name}"`)
		return
	end
	self.Expression = name
	self.BlinkToken += 1 -- cancel any blink in progress
	self:_show("Eyes", expression.eyes)
	self:_show("Brows", expression.brows)
	self:_show("Mouth", expression.mouth)
	for _, blush in self.Blush do
		blush.BackgroundTransparency = expression.blush
	end
end

-- Close the eyes for a moment (only when they are open).
function Face.Blink(self: Face)
	local expression = Face.Expressions[self.Expression]
	if not expression or (expression.eyes ~= "Open" and expression.eyes ~= "Smug") then
		return
	end
	self.BlinkToken += 1
	local token = self.BlinkToken
	self:_show("Eyes", "Closed")
	task.delay(Config.Face.BlinkTime, function()
		if self.BlinkToken == token and self.Gui.Parent then
			self:_show("Eyes", expression.eyes)
		end
	end)
end

-- Spins the dizzy eyes; call every frame.
function Face.Update(self: Face, dt: number)
	if self.EyesShown ~= "Spiral" then
		return
	end
	for _, spiral in self.Spirals do
		spiral.frame.Rotation = (spiral.frame.Rotation + spiral.direction * Config.Face.SpiralSpeed * dt) % 360
	end
end

return Face
