--!strict
-- The on-screen display, kept almost empty like the original game: one row at the top
-- with the level name on the left, a long time bar in the middle (it shrinks, and flashes
-- red under 10 seconds) and the gold counter on the right. Plus a message in the middle
-- of the screen for "level complete" and similar, and a line of help at the bottom.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Hud = {}

local LOW_TIME = 10
local TEXT = Color3.fromRGB(242, 242, 242)
local BAR_BACK = Color3.fromRGB(58, 58, 58)
local BAR_FILL = Color3.fromRGB(236, 236, 236)
local BAR_LOW = Color3.fromRGB(226, 72, 72)

local levelLabel: TextLabel
local barFill: Frame
local timeLabel: TextLabel
local goldLabel: TextLabel
local messageTitle: TextLabel
local messageText: TextLabel
local helpLabel: TextLabel

local function label(parent: Instance, size: number, bold: boolean): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = TEXT
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	l.TextSize = size
	l.Text = ""
	l.Parent = parent
	return l
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false -- starts just below Roblox's top bar
	gui.DisplayOrder = 5

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(12, 6)
	row.Size = UDim2.new(1, -24, 0, 18)
	row.Parent = gui

	levelLabel = label(row, 14, true)
	levelLabel.Size = UDim2.new(0, 170, 1, 0)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = BAR_BACK
	bar.BorderSizePixel = 0
	bar.Position = UDim2.new(0, 180, 0, 3)
	bar.Size = UDim2.new(1, -180 - 150, 0, 12)
	bar.Parent = row
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = bar

	barFill = Instance.new("Frame")
	barFill.BackgroundColor3 = BAR_FILL
	barFill.BorderSizePixel = 0
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.Parent = bar
	corner:Clone().Parent = barFill

	timeLabel = label(row, 14, true)
	timeLabel.AnchorPoint = Vector2.new(1, 0)
	timeLabel.Position = UDim2.new(1, -86, 0, 0)
	timeLabel.Size = UDim2.new(0, 56, 1, 0)
	timeLabel.TextXAlignment = Enum.TextXAlignment.Right

	local goldIcon = Instance.new("Frame")
	goldIcon.AnchorPoint = Vector2.new(1, 0.5)
	goldIcon.Position = UDim2.new(1, -62, 0.5, 0)
	goldIcon.Size = UDim2.fromOffset(10, 10)
	goldIcon.BackgroundColor3 = Config.COLORS.GOLD
	goldIcon.BorderSizePixel = 0
	goldIcon.Parent = row

	goldLabel = label(row, 14, true)
	goldLabel.AnchorPoint = Vector2.new(1, 0)
	goldLabel.Position = UDim2.new(1, 0, 0, 0)
	goldLabel.Size = UDim2.new(0, 56, 1, 0)
	goldLabel.TextXAlignment = Enum.TextXAlignment.Left

	local message = Instance.new("Frame")
	message.AnchorPoint = Vector2.new(0.5, 0.5)
	message.Position = UDim2.fromScale(0.5, 0.45)
	message.Size = UDim2.fromOffset(460, 84)
	message.BackgroundColor3 = Color3.new(0, 0, 0)
	message.BackgroundTransparency = 0.35
	message.Visible = false
	message.Name = "Message"
	message.Parent = gui
	local messageCorner = Instance.new("UICorner")
	messageCorner.CornerRadius = UDim.new(0, 10)
	messageCorner.Parent = message
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 84)
	limit.Parent = message

	messageTitle = label(message, 26, true)
	messageTitle.Position = UDim2.fromOffset(0, 10)
	messageTitle.Size = UDim2.new(1, 0, 0, 34)
	messageText = label(message, 15, false)
	messageText.Position = UDim2.fromOffset(0, 48)
	messageText.Size = UDim2.new(1, 0, 0, 22)

	helpLabel = label(gui, 13, false)
	helpLabel.AnchorPoint = Vector2.new(0.5, 1)
	helpLabel.Position = UDim2.new(0.5, 0, 1, -6)
	helpLabel.Size = UDim2.new(1, -24, 0, 18)
	helpLabel.TextColor3 = TEXT
	helpLabel.TextTransparency = 0.25
	helpLabel.TextTruncate = Enum.TextTruncate.AtEnd

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function Hud.setLevel(text: string)
	levelLabel.Text = text
end

-- Seconds left. The bar is full at TIME_START (or more).
function Hud.setTime(seconds: number)
	local t = math.max(seconds, 0)
	barFill.Size = UDim2.fromScale(math.clamp(t / Config.TIME_START, 0, 1), 1)
	local low = t < LOW_TIME and t > 0
	local flashOn = low and (os.clock() * 4) % 2 < 1
	barFill.BackgroundColor3 = if flashOn then BAR_LOW elseif low then BAR_FILL:Lerp(BAR_LOW, 0.5) else BAR_FILL
	timeLabel.Text = string.format("%.1f", t)
end

function Hud.setGold(count: number)
	goldLabel.Text = "× " .. tostring(count)
end

-- Shows a message in the middle of the screen, or hides it with nil.
function Hud.message(title: string?, text: string?)
	local frame = messageTitle.Parent :: Frame
	frame.Visible = title ~= nil
	messageTitle.Text = title or ""
	messageText.Text = text or ""
end

function Hud.setHelp(text: string)
	helpLabel.Text = text
end

return Hud
