--!strict
-- Turns keyboard, mouse and touch input into game intents: a move vector,
-- whether fire is held, weapon picks and pause.
--
-- Schemes:
--   Classic (default): WASD/arrows move in 8 directions and set facing, Space fires.
--   Mouse: WASD/arrows move, the mouse aims, click (or Space) fires.
--   Touch: on-screen thumbstick and buttons (see MobileControls).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

export type Scheme = "Classic" | "Mouse" | "Touch"

local Input = {}

Input.scheme = "Classic" :: Scheme
Input.SchemeChanged = Signal.new() -- (scheme: Scheme)
Input.WeaponSlot = Signal.new() -- (slot: number), 10 is the 0 key
Input.CycleWeapon = Signal.new() -- (step: number), -1 or 1
Input.PausePressed = Signal.new()

local NORTH = Vector3.new(0, 0, -1)
local SOUTH = Vector3.new(0, 0, 1)
local WEST = Vector3.new(-1, 0, 0)
local EAST = Vector3.new(1, 0, 0)

local MOVE_KEYS: { [Enum.KeyCode]: Vector3 } = {
	[Enum.KeyCode.W] = NORTH,
	[Enum.KeyCode.Up] = NORTH,
	[Enum.KeyCode.S] = SOUTH,
	[Enum.KeyCode.Down] = SOUTH,
	[Enum.KeyCode.A] = WEST,
	[Enum.KeyCode.Left] = WEST,
	[Enum.KeyCode.D] = EAST,
	[Enum.KeyCode.Right] = EAST,
}

local SLOT_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}

local touchMove = Vector3.zero
local touchFire = false
local mouseFire = false
-- Keys pressed while the game had input focus (not typed into chat or a text box).
local held: { [Enum.KeyCode]: boolean } = {}

local function releaseAll()
	table.clear(held)
	mouseFire = false
end

-- World-space move direction on the floor plane, length 0 to 1.
function Input.getMoveVector(): Vector3
	if Input.scheme == "Touch" then
		return touchMove
	end
	local sum = Vector3.zero
	for key, dir in MOVE_KEYS do
		if held[key] then
			sum += dir
		end
	end
	-- W and Up together still count once.
	local move = Vector3.new(math.clamp(sum.X, -1, 1), 0, math.clamp(sum.Z, -1, 1))
	if move.Magnitude > 0 then
		return move.Unit
	end
	return move
end

function Input.isFireHeld(): boolean
	if Input.scheme == "Touch" then
		return touchFire
	end
	if held[Enum.KeyCode.Space] then
		return true
	end
	return Input.scheme == "Mouse" and mouseFire
end

-- The point under the mouse cursor on the horizontal plane at `height`.
function Input.getMouseGroundPoint(height: number): Vector3?
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (height - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

function Input.setTouchMove(move: Vector3)
	touchMove = move
end

function Input.setTouchFire(held: boolean)
	touchFire = held
end

function Input.setScheme(scheme: Scheme)
	if scheme ~= Input.scheme then
		Input.scheme = scheme
		mouseFire = false
		Input.SchemeChanged:Fire(scheme)
	end
end

function Input.start()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		Input.scheme = "Touch"
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseFire = true
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local key = input.KeyCode
		held[key] = true
		local slot = SLOT_KEYS[key]
		if slot then
			Input.WeaponSlot:Fire(slot)
		elseif key == Enum.KeyCode.Q then
			Input.CycleWeapon:Fire(-1)
		elseif key == Enum.KeyCode.E then
			Input.CycleWeapon:Fire(1)
		elseif key == Enum.KeyCode.P then
			Input.PausePressed:Fire()
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseFire = false
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			held[input.KeyCode] = nil
		end
	end)

	-- Never leave a key stuck down when focus moves to chat or another window.
	UserInputService.TextBoxFocused:Connect(releaseAll)
	UserInputService.WindowFocusReleased:Connect(releaseAll)
end

return Input
