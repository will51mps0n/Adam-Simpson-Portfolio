--!strict
-- Applies the flat, shadowless lighting from Config.LIGHTING on this client.

local Lighting = game:GetService("Lighting")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)

local LightingSetup = {}

function LightingSetup.apply()
	local settings = Config.LIGHTING
	Lighting.Ambient = settings.Ambient
	Lighting.OutdoorAmbient = settings.OutdoorAmbient
	Lighting.Brightness = settings.Brightness
	Lighting.EnvironmentDiffuseScale = settings.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = settings.EnvironmentSpecularScale
	Lighting.ExposureCompensation = settings.ExposureCompensation
	Lighting.GlobalShadows = settings.GlobalShadows
end

return LightingSetup
