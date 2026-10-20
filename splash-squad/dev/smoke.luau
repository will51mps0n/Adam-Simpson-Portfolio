-- Smoke test: runs the server lighting setup and the whole milestone 1 test
-- stage (dock, kids, buttons) inside Lune, presses every button, and plays a
-- few seconds of animation. Lune checks every property name and type, so
-- typos and wrong values fail here instead of in Studio.
--
-- usage: lune run dev/smoke.luau SplashSquad.rbxlx

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local task = require("@lune/task")
local process = require("@lune/process")

local place = roblox.deserializePlace(fs.readFile(process.args[1]))
local Workspace = place:GetService("Workspace")
Workspace.CurrentCamera.ViewportSize = roblox.Vector2.new(1280, 720) -- normally set by the engine
local problems = {}

-- Fake engine pieces Lune doesn't have -----------------------------------
local frameCallbacks = {}
local function signal(list)
	return {
		Connect = function(_, fn)
			table.insert(list, fn)
			return { Disconnect = function() end }
		end,
	}
end
local RunService = {
	RenderStepped = signal(frameCallbacks),
	Heartbeat = signal(frameCallbacks),
	BindToRenderStep = function(_, _name, _priority, fn)
		table.insert(frameCallbacks, fn)
	end,
}
local buttonHandlers = {}
roblox.implementProperty("TextButton", "Activated", function(button)
	local key = button:GetFullName()
	buttonHandlers[key] = buttonHandlers[key] or {}
	return signal(buttonHandlers[key])
end)
roblox.implementMethod("Camera", "GetPropertyChangedSignal", function()
	return signal({})
end)
roblox.implementMethod("ParticleEmitter", "Emit", function() end)
roblox.implementMethod("Workspace", "BulkMoveTo", function(_, parts, cframes)
	for i, part in parts do
		part.CFrame = cframes[i]
	end
end)

local playerGui = roblox.Instance.new("Folder")
playerGui.Name = "PlayerGui"
local Players = { LocalPlayer = {
	WaitForChild = function()
		return playerGui
	end,
} }
local TweenService = { Create = function()
	return { Play = function() end }
end }

local game = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_, name)
				if name == "RunService" then
					return RunService
				elseif name == "Players" then
					return Players
				elseif name == "TweenService" then
					return TweenService
				end
				return place:GetService(name)
			end
		end
		return place[key]
	end,
})

local RandomStub = { new = function()
	local state = 99
	local function nextValue()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return {
		NextNumber = function(_, a, b)
			a, b = a or 0, b or 1
			return a + (b - a) * nextValue()
		end,
		NextInteger = function(_, a, b)
			return a + math.floor(nextValue() * (b - a + 1))
		end,
	}
end }

local cache = {}
local function requireModule(module)
	local key = module:GetFullName()
	if cache[key] == nil then
		local env = {
			script = module,
			require = requireModule,
			game = game,
			workspace = Workspace,
			Instance = roblox.Instance,
			Vector3 = roblox.Vector3,
			Vector2 = roblox.Vector2,
			CFrame = roblox.CFrame,
			Color3 = roblox.Color3,
			UDim = roblox.UDim,
			UDim2 = roblox.UDim2,
			Enum = roblox.Enum,
			NumberRange = roblox.NumberRange,
			NumberSequence = roblox.NumberSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			ColorSequence = roblox.ColorSequence,
			TweenInfo = { new = function() return {} end },
			Random = RandomStub,
			task = task,
			warn = function(...)
				table.insert(problems, "warn: " .. table.concat({ ... }, " "))
			end,
		}
		cache[key] = luau.load(module.Source, { debugName = key, environment = env })()
	end
	return cache[key]
end

local function step(seconds)
	for _ = 1, math.floor(seconds * 60) do
		for _, fn in frameCallbacks do
			local ok, err = pcall(fn, 1 / 60)
			if not ok then
				table.insert(problems, "frame: " .. tostring(err))
			end
		end
	end
end

local function press(path)
	local handlers = buttonHandlers[path]
	if not handlers or #handlers == 0 then
		table.insert(problems, "no button: " .. path)
		return
	end
	for _, fn in handlers do
		local ok, err = pcall(fn)
		if not ok then
			table.insert(problems, "button " .. path .. ": " .. tostring(err))
		end
	end
	step(0.3)
end

-- Server: lighting --------------------------------------------------------
local server = place:GetService("ServerScriptService"):FindFirstChild("Server")
requireModule(server:FindFirstChild("LightingSetup")).apply()
print("lighting effects:", #place:GetService("Lighting"):GetChildren())

-- Client: the test stage ------------------------------------------------
local client = place:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("Client")
requireModule(client:FindFirstChild("Showcase")).start()
step(1)

local ui = "ShowcaseUI.Root." -- buttons are wired before the GUI is parented to PlayerGui
local faces = { "Idle", "Aiming", "Fire", "Hit", "Flying", "Wet", "Win" }
local moves = { "Aim", "Throw!", "Get hit", "Win dance", "Reset", "Splash!" }
for _, face in faces do
	press(ui .. "Faces." .. face)
end
for _, move in moves do
	press(ui .. "Moves." .. move)
end
step(8) -- everyone splashes in, sinks and drops back

-- Pick Pip, look closely, spin, and go through the whole wardrobe.
press(ui .. "Tabs.Pip")
press(ui .. "Toggles.Close-up")
press(ui .. "Toggles.Spin")
press(ui .. "Toggles.Wardrobe")
local fields = { "Skin", "Hair", "Hair color", "Hat", "Top", "Top color", "Bottom", "Bottom color", "Shoes", "Shoe color", "Cape", "Goggles", "Life ring", "Mask" }
for _, field in fields do
	for _ = 1, 6 do
		press(ui .. "Wardrobe." .. field .. ".>")
	end
	press(ui .. "Wardrobe." .. field .. ".<")
end
for _ = 1, 5 do
	press(ui .. "Wardrobe.Extras.Random")
end
press(ui .. "Wardrobe.Extras.Undo all")
press(ui .. "Moves.Splash!")
step(8)
press(ui .. "Tabs.Everyone")

local kids = 0
for _, child in Workspace:FindFirstChild("TestStage"):GetChildren() do
	if child:IsA("Model") then
		kids += 1
	end
end
print("kids on stage:", kids)
print("buttons wired:", (function()
	local n = 0
	for _ in buttonHandlers do
		n += 1
	end
	return n
end)())

if #problems > 0 then
	for _, problem in problems do
		print("PROBLEM", problem)
	end
	process.exit(1)
end
print("smoke test passed")
