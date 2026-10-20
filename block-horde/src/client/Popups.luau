--!strict
-- Big center text: "WAVE 5", "NEW WEAPON: SHOTGUN  [3]", "UZI + RAPID FIRE",
-- "YOU DIED", "AMMO" and lobby notices. Each style has its own spot on screen;
-- text pops in, holds, then fades. Unlocks queue so none get skipped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Sounds = require(script.Parent.Sounds)
local UI = require(script.Parent.UI)

type Style = { y: number, size: number, color: Color3, hold: number }

local Popups = {}

local STYLES: { [string]: Style } = {
	wave = { y = 0.3, size = 72, color = Color3.fromRGB(255, 214, 60), hold = 1.6 },
	unlock = { y = 0.42, size = 44, color = Color3.new(1, 1, 1), hold = 2 },
	big = { y = 0.38, size = 80, color = Color3.fromRGB(230, 50, 40), hold = 2.5 },
	info = { y = 0.22, size = 26, color = Color3.new(1, 1, 1), hold = 2.4 },
	pickup = { y = 0.62, size = 30, color = Color3.fromRGB(120, 230, 110), hold = 0.8 },
}

local labels: { [string]: TextLabel } = {}
local tokens: { [string]: number } = {}
local unlockQueue: { string } = {}
local unlockBusy = false

local function show(style: string, text: string)
	local spec = STYLES[style] or STYLES.info
	local label = labels[style]
	if not label then
		return
	end
	tokens[style] = (tokens[style] or 0) + 1
	local token = tokens[style]
	label.Text = text
	label.TextColor3 = spec.color
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0
	label.Visible = true
	local scale = label:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.4
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(spec.hold, function()
		if tokens[style] ~= token then
			return
		end
		local fade = TweenInfo.new(0.4)
		TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local function pumpUnlocks()
	if unlockBusy then
		return
	end
	local text = table.remove(unlockQueue, 1)
	if not text then
		return
	end
	unlockBusy = true
	show("unlock", text)
	Sounds.play("unlock")
	task.delay(1.2, function()
		unlockBusy = false
		pumpUnlocks()
	end)
end

function Popups.show(text: string, style: string)
	if style == "unlock" then
		table.insert(unlockQueue, text)
		pumpUnlocks()
	else
		show(style, text)
	end
end

function Popups.start()
	local gui = UI.screen("Popups", 15)
	for name, spec in STYLES do
		local label = UI.text(gui, "", spec.size)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, spec.y)
		label.Size = UDim2.new(0.9, 0, 0, spec.size + 10)
		label.TextWrapped = true
		label.Visible = false
		local scale = Instance.new("UIScale")
		scale.Parent = label
		labels[name] = label
	end
	Net.event("Announce").OnClientEvent:Connect(function(text: string, style: string)
		Popups.show(text, style)
	end)
end

return Popups
