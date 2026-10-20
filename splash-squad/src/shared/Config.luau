--!strict
-- Every number you might want to tune lives here.
-- Sizes are in studs, angles in degrees, times in seconds.

local Config = {}

Config.GameName = "Splash Squad"

Config.World = {
	WaterY = 0, -- height of the water surface
	Gravity = 55, -- studs/s^2, used for shots and knockback flights
	PlaneZ = 0, -- the fight happens on this Z plane (2.5D)
}

-- Chibi body proportions, before each kid's own scale is applied.
-- The head is about as big as the rest of the body.
Config.Kid = {
	HeadSize = Vector3.new(2.5, 2.3, 2.3), -- width, height, depth (an egg-ish ball)
	HeadSink = 0.3, -- how far the head overlaps the top of the body
	BodySize = Vector3.new(1.6, 1.7, 1.36), -- a short bean
	LegSize = Vector3.new(0.56, 0.82, 0.56),
	LegSpread = 0.38, -- hip distance from the middle
	ArmSize = Vector3.new(0.46, 1.0, 0.46),
	ArmRestAngle = 16, -- arms hang slightly away from the body
	ShoulderDrop = 0.36, -- shoulders sit this far below the top of the body
	HandSize = Vector3.new(0.52, 0.54, 0.48), -- little mittens
	ShoeSize = Vector3.new(0.64, 0.38, 0.84),
	FeetSize = Vector3.new(0.5, 0.3, 0.66), -- bare feet are a bit smaller than shoes
	FacingAngle = 16, -- kids face the camera, turned this far toward their target
}

-- Where things go on the face, as fractions of the face (0..1 across, 0..1 down).
Config.Face = {
	PixelsPerStud = 100,
	LightInfluence = 0.55, -- 0 = face drawn at full brightness, 1 = shaded like the head
	EyeY = 0.56,
	EyeSpacing = 0.34, -- distance between the eye centers
	EyeWidth = 0.15,
	EyeHeight = 0.25,
	ShineSize = 0.45, -- shine dot size, as a fraction of the eye width
	BrowY = 0.355,
	BrowLength = 0.13,
	LineThickness = 0.024, -- brows, smiles, closed eyes
	BlushY = 0.7,
	BlushSpacing = 0.56,
	BlushWidth = 0.14,
	BlushHeight = 0.075,
	MouthY = 0.765,
	MouthWidth = 0.15,
	BlinkEvery = { 2.2, 5.0 }, -- random wait between blinks
	BlinkTime = 0.11,
	SpiralSpeed = 540, -- dizzy eyes spin speed (degrees per second)
}

Config.Outline = {
	Color = Color3.fromRGB(34, 22, 36),
	Transparency = 0,
	MaxHighlights = 30, -- Roblox draws at most 31 Highlights at once
}

Config.Anim = {
	IdleBobHeight = 0.1,
	IdleBobSpeed = 2.4, -- radians per second
	IdleSway = 2.5, -- degrees
	BreathSquash = 0.025,

	AimLean = 7,
	FireTime = 0.55,
	FireLean = 12,
	FireSquash = 0.16,
	FireFaceTime = 0.75,

	HitTime = 0.55,
	HitLean = 22,
	HitHop = 0.6,
	HitFaceTime = 0.8,

	SpinSpeed = 760, -- degrees per second while flying
	FlailSpeed = 22, -- radians per second for flailing arms and legs

	WaterFloatTime = 3.0, -- how long a kid bobs in the water before sinking
	WaterBob = 0.16,
	SinkTime = 1.3,

	WinHopHeight = 1.4,
	WinHopTime = 0.42,

	LandSquash = 0.22,
	DropInHeight = 9,
}

Config.Splash = {
	Droplets = 16,
	DropletSize = { 0.25, 0.55 },
	DropletSpeed = { 10, 22 },
	RingBlobs = 18,
	RingStartRadius = 0.6,
	RingEndRadius = 3.6,
	RingTime = 0.8,
	ColumnHeight = 3.4,
	ColumnTime = 0.55,
	WaterColor = Color3.fromRGB(150, 236, 246),
	FoamColor = Color3.fromRGB(250, 255, 255),
}

Config.Camera = {
	FieldOfView = 40,
	Pitch = 7, -- looking slightly down at the water
	Smoothness = 6, -- higher = snappier camera
}

Config.Lighting = {
	ClockTime = 14.2,
	GeographicLatitude = 23,
	Brightness = 2.6,
	Ambient = Color3.fromRGB(112, 112, 128),
	OutdoorAmbient = Color3.fromRGB(170, 172, 190),
	ShadowSoftness = 0.6,
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.15,
	ExposureCompensation = 0.12,
	ColorCorrection = {
		Saturation = 0.2,
		Contrast = 0.07,
		Brightness = 0.02,
		TintColor = Color3.fromRGB(255, 251, 244),
	},
	Bloom = {
		Intensity = 0.25,
		Size = 22,
		Threshold = 1.7,
	},
	Atmosphere = {
		Density = 0.24,
		Offset = 0.2,
		Color = Color3.fromRGB(205, 232, 255),
		Decay = Color3.fromRGB(140, 196, 240),
		Glare = 0.1,
		Haze = 0.6,
	},
}

return Config
