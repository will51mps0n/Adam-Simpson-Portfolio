--!strict
-- Short-lived visual effects drawn only on this client: bullet tracers and
-- muzzle flashes. Parts are pooled and reused instead of created per shot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Effects = {}

type Active = { part: Part, expiresAt: number, life: number }

local HIDDEN = CFrame.new(0, -10000, 0)
local FLASH_COLOR = Color3.fromRGB(255, 244, 180)

local folder: Folder
local pool: { Part } = {}
local active: { Active } = {}

local function takePart(): Part
	local pooled = table.remove(pool)
	if pooled then
		return pooled
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Parent = folder
	return part
end

local function show(part: Part, life: number)
	part.Transparency = 0
	table.insert(active, { part = part, expiresAt = os.clock() + life, life = life })
end

function Effects.tracer(from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	local part = takePart()
	part.Size = Vector3.new(Config.TRACER_WIDTH, Config.TRACER_WIDTH, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Color = color
	show(part, Config.TRACER_LIFETIME)
end

function Effects.muzzleFlash(at: Vector3)
	local part = takePart()
	part.Size = Vector3.new(0.7, 0.7, 0.7)
	part.CFrame = CFrame.new(at)
	part.Color = FLASH_COLOR
	show(part, Config.MUZZLE_FLASH_TIME)
end

local function update()
	local now = os.clock()
	for i = #active, 1, -1 do
		local entry = active[i]
		local left = entry.expiresAt - now
		if left <= 0 then
			entry.part.Transparency = 1
			entry.part.CFrame = HIDDEN
			table.insert(pool, entry.part)
			active[i] = active[#active]
			active[#active] = nil
		else
			entry.part.Transparency = 1 - left / entry.life
		end
	end
end

function Effects.start()
	folder = Instance.new("Folder")
	folder.Name = "ClientEffects"
	folder.Parent = workspace
	RunService.Heartbeat:Connect(update)
end

return Effects
