--!strict
-- Short visual effects. (More arrive with the polish milestone.)

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)

local Effects = {}

-- A flash of fire at (x, y) px that swells to `radius` px and fades out.
function Effects.explosion(parent: Instance, x: number, y: number, radius: number, z: number)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = Config.COLORS.EXPLOSION
	ball.Size = Vector3.one * Units.studs(radius * 0.6)
	ball.Position = Units.toWorld(x, y, z)
	ball.Parent = parent
	local tween = TweenService:Create(
		ball,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * Units.studs(radius * 2.2), Transparency = 1 }
	)
	tween.Completed:Once(function()
		ball:Destroy()
	end)
	tween:Play()
end

return Effects
