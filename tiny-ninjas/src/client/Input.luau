--!strict
-- The player's controls:
--   keyboard  A / D or Left / Right to run; Space, W, Up or Z to jump; K or R to restart
--   gamepad   left stick or d-pad to run, A to jump, Y to restart
--   touch     big left / right buttons bottom-left, jump bottom-right, restart above it
-- A jump press is remembered until the simulation reads it, so even a tap shorter than
-- one physics frame still jumps.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

export type Sample = {
	left: boolean,
	right: boolean,
	jump: boolean,
	restart: boolean,
}

local Input = {}

local LEFT_KEYS = { Enum.KeyCode.A, Enum.KeyCode.Left }
local RIGHT_KEYS = { Enum.KeyCode.D, Enum.KeyCode.Right }
local JUMP_KEYS = { Enum.KeyCode.Space, Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.Z }
local RESTART_KEYS = { Enum.KeyCode.K, Enum.KeyCode.R }
local STICK_DEAD_ZONE = 0.4

local jumpLatched = false
local restartLatched = false
local stickX = 0
local touchHeld = { left = false, right = false, jump = false }

local function anyKeyDown(keys: { Enum.KeyCode }): boolean
	for _, key in keys do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function padDown(button: Enum.KeyCode): boolean
	return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, button)
end

-- Roblox's own movement controls would fight ours (and show a thumbstick on phones).
local function disableDefaultControls()
	local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
	local module = playerScripts:WaitForChild("PlayerModule", 10)
	if module and module:IsA("ModuleScript") then
		local ok, playerModule = pcall((require :: any), module)
		if ok and playerModule then
			pcall(function()
				playerModule:GetControls():Disable()
			end)
		end
	end
end

local function makeTouchButton(parent: Instance, text: string, position: UDim2, size: number): TextButton
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = position
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = Color3.new(0, 0, 0)
	button.BackgroundTransparency = 0.55
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextTransparency = 0.1
	button.Font = Enum.Font.GothamBold
	button.TextSize = math.floor(size * 0.42)
	button.Text = text
	button.AutoButtonColor = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	button.Parent = parent
	return button
end

-- Held while any finger that started on the button is still down, wherever it moves.
local function bindHold(button: TextButton, onChange: (boolean) -> ())
	local touches: { [InputObject]: boolean } = {}
	local function count(): number
		local n = 0
		for _ in touches do
			n += 1
		end
		return n
	end
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touches[input] = true
			button.BackgroundTransparency = 0.35
			onChange(true)
		end
	end)
	UserInputService.TouchEnded:Connect(function(input)
		if touches[input] then
			touches[input] = nil
			if count() == 0 then
				button.BackgroundTransparency = 0.55
				onChange(false)
			end
		end
	end)
end

local function makeTouchControls()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchControls"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	local left = makeTouchButton(gui, "◀", UDim2.new(0, 80, 1, -80), 110)
	local right = makeTouchButton(gui, "▶", UDim2.new(0, 205, 1, -80), 110)
	local jump = makeTouchButton(gui, "▲", UDim2.new(1, -90, 1, -85), 130)
	local restart = makeTouchButton(gui, "↻", UDim2.new(1, -70, 1, -205), 64)
	bindHold(left, function(down)
		touchHeld.left = down
	end)
	bindHold(right, function(down)
		touchHeld.right = down
	end)
	bindHold(jump, function(down)
		touchHeld.jump = down
		if down then
			jumpLatched = true
		end
	end)
	restart.Activated:Connect(function()
		restartLatched = true
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function Input.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local key = input.KeyCode
		if table.find(JUMP_KEYS, key) or key == Enum.KeyCode.ButtonA then
			jumpLatched = true
		elseif table.find(RESTART_KEYS, key) or key == Enum.KeyCode.ButtonY then
			restartLatched = true
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			stickX = input.Position.X
		end
	end)
	task.spawn(disableDefaultControls)
	if UserInputService.TouchEnabled then
		makeTouchControls()
	end
end

-- The controls right now. Call once per simulation frame.
function Input.sample(): Sample
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	local left = not typing
		and (anyKeyDown(LEFT_KEYS) or padDown(Enum.KeyCode.DPadLeft) or stickX < -STICK_DEAD_ZONE or touchHeld.left)
	local right = not typing
		and (anyKeyDown(RIGHT_KEYS) or padDown(Enum.KeyCode.DPadRight) or stickX > STICK_DEAD_ZONE or touchHeld.right)
	local jump = jumpLatched
		or (not typing and (anyKeyDown(JUMP_KEYS) or padDown(Enum.KeyCode.ButtonA) or touchHeld.jump))
	local restart = restartLatched
	jumpLatched = false
	restartLatched = false
	return { left = left, right = right, jump = jump, restart = restart }
end

-- True if the player is pressing anything (the time bar waits for the first press).
function Input.any(sample: Sample): boolean
	return sample.left or sample.right or sample.jump
end

return Input
