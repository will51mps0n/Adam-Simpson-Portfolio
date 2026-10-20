--!strict
-- Side-on camera, far away with a narrow field of view so the level looks flat.
--  * "fixed": frames the whole one-screen level, like the original game.
--  * "follow": for big arenas; keeps every target (player) in view, zooming out as
--    they spread apart and never showing past the level's outer wall.
-- The level is always centered in the screen area below the Roblox top bar and the
-- time bar, with a little padding around it.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local LevelBuilder = require(Shared.LevelBuilder)

type Region = { center: Vector2, size: Vector2 }

local CameraController = {}

local level: LevelBuilder.BuiltLevel? = nil
local targetSource: (() -> { Vector3 })? = nil
local smoothed: Region? = nil -- follow mode's current view, eased toward the goal each frame

local function wholeLevel(lvl: LevelBuilder.BuiltLevel): Region
	return { center = (lvl.boundsMin + lvl.boundsMax) / 2, size = lvl.boundsMax - lvl.boundsMin }
end

-- The smallest region that holds every target with some margin around it.
local function followGoal(lvl: LevelBuilder.BuiltLevel, targets: { Vector3 }): Region
	if #targets == 0 then
		return wholeLevel(lvl)
	end
	local lo = Vector2.new(math.huge, math.huge)
	local hi = -lo
	for _, p in targets do
		local flat = Vector2.new(p.X, p.Y)
		lo = lo:Min(flat)
		hi = hi:Max(flat)
	end
	local levelSize = lvl.boundsMax - lvl.boundsMin
	local margin = Units.studs(Config.FOLLOW_MARGIN_TILES * Config.TILE_PX)
	local minTall = math.min(Units.studs(Config.FOLLOW_MIN_VIEW_TILES * Config.TILE_PX), levelSize.Y)
	local size = hi - lo + Vector2.new(margin, margin) * 2
	size = Vector2.new(math.min(size.X, levelSize.X), math.clamp(size.Y, minTall, levelSize.Y))
	return { center = (lo + hi) / 2, size = size }
end

-- Keeps the view inside the level's outer wall along each axis where the level is
-- bigger than the view; centers the level along an axis where it is smaller.
local function clampAxis(center: number, half: number, lo: number, hi: number): number
	if hi - lo <= half * 2 then
		return (lo + hi) / 2
	end
	return math.clamp(center, lo + half, hi - half)
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	local lvl = level
	if not camera or not lvl then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local viewport = camera.ViewportSize
	local top = GuiService:GetGuiInset().Y + Config.CAMERA_HUD_TOP_PX
	if viewport.X < 2 or viewport.Y <= top then
		return
	end

	local region: Region
	if lvl.cameraMode == "follow" then
		local goal = followGoal(lvl, if targetSource then targetSource() else {})
		local current = smoothed
		if current then
			local alpha = 1 - math.exp(-Config.FOLLOW_SMOOTHING * dt)
			current.center = current.center:Lerp(goal.center, alpha)
			current.size = current.size:Lerp(goal.size, alpha)
			region = current
		else
			smoothed = goal
			region = goal
		end
	else
		region = wholeLevel(lvl)
	end

	-- Scale so the region fits the usable screen area (below the top bar, inside the padding).
	local pad = Config.CAMERA_PADDING_PX
	local usableW = math.max(viewport.X - 2 * pad, 1)
	local usableH = math.max(viewport.Y - top - 2 * pad, 1)
	local pxPerStud = math.min(usableW / region.size.X, usableH / region.size.Y)

	local center = Vector2.new(
		clampAxis(region.center.X, viewport.X / 2 / pxPerStud, lvl.boundsMin.X, lvl.boundsMax.X),
		clampAxis(region.center.Y, (viewport.Y - top) / 2 / pxPerStud, lvl.boundsMin.Y, lvl.boundsMax.Y)
	)

	-- Distance that makes the whole screen height span viewport.Y / pxPerStud studs.
	local visibleHeight = viewport.Y / pxPerStud
	local distance = (visibleHeight / 2) / math.tan(math.rad(Config.CAMERA_FOV) / 2)
	-- The usable area's middle is top / 2 pixels below the screen's middle, so aim that much higher.
	local focus = Vector3.new(center.X, center.Y + (top / 2) / pxPerStud, lvl.frontZ)

	camera.FieldOfView = Config.CAMERA_FOV
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, distance), focus)
	camera.Focus = CFrame.new(focus)
end

function CameraController.start()
	RunService:BindToRenderStep("TinyNinjasCamera", Enum.RenderPriority.Camera.Value + 1, update)
end

function CameraController.setLevel(lvl: LevelBuilder.BuiltLevel)
	level = lvl
	smoothed = nil -- jump straight to the new level instead of gliding
end

-- `source` returns the world positions the follow camera should keep in view
-- (living players). Pass nil to show the whole level.
function CameraController.setTargets(source: (() -> { Vector3 })?)
	targetSource = source
end

return CameraController
