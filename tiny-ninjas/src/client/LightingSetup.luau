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

	-- Studio templates add haze and glow effects that would tint the flat grey look.
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") then
			child.Enabled = false
		elseif child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
end

return LightingSetup
