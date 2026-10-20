--!strict
-- Sunny beach lighting: warm sun, soft shadows, a little extra color.
-- All values come from Config.Lighting.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local LightingSetup = {}

local function effect<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing :: any
	end
	local created = Instance.new(className :: any)
	created.Name = name
	created.Parent = Lighting
	return created :: any
end

function LightingSetup.apply()
	local L = Config.Lighting
	Lighting.ClockTime = L.ClockTime
	Lighting.GeographicLatitude = L.GeographicLatitude
	Lighting.Brightness = L.Brightness
	Lighting.Ambient = L.Ambient
	Lighting.OutdoorAmbient = L.OutdoorAmbient
	Lighting.ShadowSoftness = L.ShadowSoftness
	Lighting.EnvironmentDiffuseScale = L.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = L.EnvironmentSpecularScale
	Lighting.ExposureCompensation = L.ExposureCompensation
	Lighting.GlobalShadows = true

	local colorCorrection = effect("ColorCorrectionEffect", "SunnyColor") :: ColorCorrectionEffect
	colorCorrection.Saturation = L.ColorCorrection.Saturation
	colorCorrection.Contrast = L.ColorCorrection.Contrast
	colorCorrection.Brightness = L.ColorCorrection.Brightness
	colorCorrection.TintColor = L.ColorCorrection.TintColor

	local bloom = effect("BloomEffect", "SoftBloom") :: BloomEffect
	bloom.Intensity = L.Bloom.Intensity
	bloom.Size = L.Bloom.Size
	bloom.Threshold = L.Bloom.Threshold

	local atmosphere = effect("Atmosphere", "BeachAir") :: Atmosphere
	atmosphere.Density = L.Atmosphere.Density
	atmosphere.Offset = L.Atmosphere.Offset
	atmosphere.Color = L.Atmosphere.Color
	atmosphere.Decay = L.Atmosphere.Decay
	atmosphere.Glare = L.Atmosphere.Glare
	atmosphere.Haze = L.Atmosphere.Haze
end

return LightingSetup
