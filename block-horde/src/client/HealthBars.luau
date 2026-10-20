--!strict
-- Keeps the health bar over every player's head up to date. Your own name is
-- hidden (you know who you are) but your bar stays.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HealthBars = {}

local GOOD = Color3.fromRGB(80, 220, 90)
local LOW = Color3.fromRGB(230, 50, 40)

local timer = 0

local function update(dt: number)
	timer -= dt
	if timer > 0 then
		return
	end
	timer = 0.1
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local hero = character and character:FindFirstChild("Hero")
		local head = hero and hero:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("NameTag")
		if not humanoid or not tag then
			continue
		end
		local name = tag:FindFirstChild("PlayerName")
		if name and name:IsA("TextLabel") then
			name.Visible = other ~= Players.LocalPlayer
		end
		local bar = tag:FindFirstChild("Bar")
		local fill = bar and bar:FindFirstChild("Fill")
		if fill and fill:IsA("Frame") then
			local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			fill.Size = UDim2.fromScale(fraction, 1)
			fill.BackgroundColor3 = LOW:Lerp(GOOD, fraction)
		end
	end
end

function HealthBars.start()
	RunService.Heartbeat:Connect(update)
end

return HealthBars
