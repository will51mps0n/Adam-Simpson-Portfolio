--!strict
-- The screen shown while a party teleports into its game: set as the
-- teleport loading screen before leaving, and kept up on arrival until the
-- run has started.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local LoadingScreen = {}

local function build(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "BlockHordeLoading"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	shade.Parent = gui
	local function line(text: string, size: number, y: number, color: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, y)
		label.Size = UDim2.new(0.9, 0, 0, size + 10)
		label.Font = Enum.Font.FredokaOne
		label.Text = text
		label.TextSize = size
		label.TextColor3 = color
		label.TextStrokeTransparency = 0
		label.Parent = shade
	end
	local name = ReplicatedStorage:GetAttribute("GameName")
	line(string.upper(if typeof(name) == "string" then name else "BLOCK HORDE"), 72, 0.42, Color3.fromRGB(240, 196, 60))
	line("Loading your game...", 28, 0.55, Color3.new(1, 1, 1))
	return gui
end

local function fadeOut(gui: ScreenGui)
	local shade = gui:FindFirstChild("Shade")
	if shade and shade:IsA("Frame") then
		TweenService:Create(shade, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		for _, label in shade:GetChildren() do
			if label:IsA("TextLabel") then
				TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end
	end
	task.delay(0.7, function()
		gui:Destroy()
	end)
end

function LoadingScreen.start()
	local player = Players.LocalPlayer
	pcall(function()
		TeleportService:SetTeleportGui(build() :: any)
	end)

	-- Arriving from a teleport: keep the screen up until the run has started.
	local ok, arriving = pcall(function()
		return TeleportService:GetArrivingTeleportGui()
	end)
	if ok and arriving then
		arriving.Parent = player:WaitForChild("PlayerGui")
		task.spawn(function()
			local waited = 0
			while waited < 30 and not (player:GetAttribute("InRun") == true and player.Character) do
				waited += task.wait(0.25)
			end
			fadeOut(arriving)
		end)
	end
end

return LoadingScreen
