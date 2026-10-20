--!strict
-- On-screen controls for phones and tablets during a run: a thumbstick on the
-- left half of the screen to move and face, plus FIRE and SWAP (next weapon)
-- buttons. The lobby uses Roblox's normal touch controls instead.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Input = require(script.Parent.InputController)
local UI = require(script.Parent.UI)

local MobileControls = {}

local STICK_RADIUS = 60
local DEADZONE = 0.15

function MobileControls.start()
	local gui = UI.screen("MobileControls", 5)

	-- Thumbstick: appears where the thumb lands anywhere on the left half.
	local zone = Instance.new("Frame")
	zone.Name = "MoveZone"
	zone.BackgroundTransparency = 1
	zone.Size = UDim2.fromScale(0.5, 1)
	zone.Parent = gui

	local base = Instance.new("Frame")
	base.Name = "Stick"
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.Size = UDim2.fromOffset(STICK_RADIUS * 2, STICK_RADIUS * 2)
	base.BackgroundColor3 = UI.DARK
	base.BackgroundTransparency = 0.55
	UI.round(base, STICK_RADIUS)
	base.Parent = zone
	local restPosition = UDim2.new(0, 120, 1, -120)
	base.Position = restPosition

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.fromOffset(56, 56)
	knob.BackgroundColor3 = UI.WHITE
	knob.BackgroundTransparency = 0.2
	UI.round(knob, 28)
	knob.Parent = base

	local moveTouch: InputObject? = nil
	local startPos = Vector2.zero

	local function releaseStick()
		moveTouch = nil
		Input.setTouchMove(Vector3.zero)
		base.Position = restPosition
		knob.Position = UDim2.fromScale(0.5, 0.5)
	end

	zone.InputBegan:Connect(function(input: InputObject)
		if moveTouch or input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		moveTouch = input
		startPos = Vector2.new(input.Position.X, input.Position.Y)
		base.Position = UDim2.fromOffset(startPos.X - zone.AbsolutePosition.X, startPos.Y - zone.AbsolutePosition.Y)
	end)

	UserInputService.TouchMoved:Connect(function(input: InputObject)
		if input ~= moveTouch then
			return
		end
		local offset = Vector2.new(input.Position.X, input.Position.Y) - startPos
		if offset.Magnitude > STICK_RADIUS then
			offset = offset.Unit * STICK_RADIUS
		end
		knob.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
		if offset.Magnitude / STICK_RADIUS < DEADZONE then
			Input.setTouchMove(Vector3.zero)
		else
			-- Screen down is south (+Z) because the camera looks north.
			Input.setTouchMove(Vector3.new(offset.X, 0, offset.Y) / STICK_RADIUS)
		end
	end)

	-- FIRE: hold to keep shooting.
	local fireButton = UI.button(gui, "FIRE", 28)
	fireButton.AnchorPoint = Vector2.new(1, 1)
	fireButton.Position = UDim2.new(1, -36, 1, -36)
	fireButton.Size = UDim2.fromOffset(112, 112)
	fireButton.BackgroundColor3 = Color3.fromRGB(196, 58, 40)
	UI.round(fireButton, 56)

	local fireTouch: InputObject? = nil
	local function releaseFire()
		fireTouch = nil
		Input.setTouchFire(false)
	end
	fireButton.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			fireTouch = input
			Input.setTouchFire(true)
		end
	end)

	UserInputService.TouchEnded:Connect(function(input: InputObject)
		if input == moveTouch then
			releaseStick()
		elseif input == fireTouch then
			releaseFire()
		end
	end)

	-- SWAP: next owned weapon.
	local swapButton = UI.button(gui, "SWAP", 20)
	swapButton.AnchorPoint = Vector2.new(1, 1)
	swapButton.Position = UDim2.new(1, -164, 1, -36)
	swapButton.Size = UDim2.fromOffset(76, 76)
	UI.round(swapButton, 38)
	swapButton.Activated:Connect(function()
		Input.CycleWeapon:Fire(1)
	end)

	local function refresh()
		gui.Enabled = Input.scheme == "Touch" and Players.LocalPlayer:GetAttribute("InRun") == true
		if not gui.Enabled then
			releaseStick()
			releaseFire()
		end
	end
	Input.SchemeChanged:Connect(refresh)
	Players.LocalPlayer:GetAttributeChangedSignal("InRun"):Connect(refresh)
	refresh()
end

return MobileControls
