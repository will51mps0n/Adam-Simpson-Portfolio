--!strict
-- A side-on camera (like the 2D original) that glides to whatever we ask it to frame.
--   CameraRig.start()
--   CameraRig.frame(Vector3.new(0, 3, 0), 20, 6)  -- center, half width, half height (studs)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local CameraRig = {}

local target = {
	center = Vector3.new(0, 3, 0),
	halfWidth = 20,
	halfHeight = 6,
}
local current: CFrame? = nil
local started = false

local function desired(camera: Camera): CFrame
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
	local tanHalf = math.tan(math.rad(Config.Camera.FieldOfView / 2))
	local distance = math.max(target.halfHeight / tanHalf, target.halfWidth / (tanHalf * aspect))
	local pitch = math.rad(Config.Camera.Pitch)
	local eye = target.center + Vector3.new(0, math.sin(pitch), math.cos(pitch)) * distance
	return CFrame.lookAt(eye, target.center)
end

function CameraRig.start()
	if started then
		return
	end
	started = true
	RunService:BindToRenderStep("SplashCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		camera.FieldOfView = Config.Camera.FieldOfView
		local goal = desired(camera)
		local alpha = 1 - math.exp(-Config.Camera.Smoothness * dt)
		current = if current then current:Lerp(goal, alpha) else goal
		camera.CFrame = current :: CFrame
	end)
end

-- Frame a region: everything within halfWidth/halfHeight of center stays on screen.
function CameraRig.frame(center: Vector3, halfWidth: number, halfHeight: number, instant: boolean?)
	target.center = center
	target.halfWidth = halfWidth
	target.halfHeight = halfHeight
	if instant then
		current = nil
	end
end

return CameraRig
