--!strict
-- Cartoon water effects, all made from parts: a big splash (a water column,
-- flying droplets, a ring of foam and a puff of spray), small ripples, and
-- "blub blub" bubbles when someone sinks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Shapes = require(ReplicatedStorage.Shared.Character.Shapes)

local Splash = {}

type Effect = (dt: number) -> boolean -- return false when finished

local effects: { Effect } = {}
local connection: RBXScriptConnection? = nil
local random = Random.new()

local function folder(): Instance
	local existing = workspace:FindFirstChild("Effects")
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Effects"
	created.Parent = workspace
	return created
end

local function run(effect: Effect)
	table.insert(effects, effect)
	if connection then
		return
	end
	connection = RunService.RenderStepped:Connect(function(dt)
		for i = #effects, 1, -1 do
			local ok, alive = pcall(effects[i], dt)
			if not ok or not alive then
				table.remove(effects, i)
			end
		end
	end)
end

local function blob(name: string, size: Vector3, color: Color3, transparency: number): Part
	local part = Shapes.ellipsoid(name, size, color, folder())
	part.Transparency = transparency
	part.CastShadow = false
	return part
end

-- Flying droplets that stretch along their path.
local function droplets(position: Vector3, scale: number)
	local S = Config.Splash
	local gravity = Config.World.Gravity
	for _ = 1, S.Droplets do
		local size = random:NextNumber(S.DropletSize[1], S.DropletSize[2]) * scale
		local angle = random:NextNumber(0, 2 * math.pi)
		local outward = random:NextNumber(2, 8) * scale
		local velocity = Vector3.new(
			math.cos(angle) * outward,
			random:NextNumber(S.DropletSpeed[1], S.DropletSpeed[2]) * math.sqrt(scale),
			math.sin(angle) * outward * 0.4
		)
		local pos = position + Vector3.new(math.cos(angle), 0.2, math.sin(angle) * 0.4) * 0.5 * scale
		local part = blob("Droplet", Vector3.new(size, size * 1.6, size), S.WaterColor, 0.05)
		local age = 0
		run(function(dt)
			age += dt
			velocity -= Vector3.new(0, gravity * dt, 0)
			pos += velocity * dt
			if pos.Y < Config.World.WaterY and velocity.Y < 0 then
				part:Destroy()
				return false
			end
			local stretch = 1 + math.min(velocity.Magnitude / 30, 0.8)
			part.Size = Vector3.new(size, size * stretch, size)
			part.CFrame = Shapes.alongY(pos, velocity)
			return true
		end)
	end
end

-- A ring of foam blobs spreading out on the water.
local function ring(position: Vector3, scale: number, blobs: number, fromRadius: number, toRadius: number, duration: number, blobSize: number)
	local parts = {}
	for i = 1, blobs do
		parts[i] = blob("Foam", Vector3.one, Config.Splash.FoamColor, 0)
	end
	local age = 0
	run(function(dt)
		age += dt
		local p = math.min(age / duration, 1)
		local eased = 1 - (1 - p) ^ 3
		local radius = (fromRadius + (toRadius - fromRadius) * eased) * scale
		local size = blobSize * scale * (1 - 0.6 * p)
		for i, part in parts do
			local a = (i / blobs) * 2 * math.pi
			part.Size = Vector3.new(size, size * 0.45, size)
			part.Transparency = p ^ 1.5
			part.CFrame = CFrame.new(position + Vector3.new(math.cos(a) * radius, 0.05, math.sin(a) * radius))
		end
		if p >= 1 then
			for _, part in parts do
				part:Destroy()
			end
			return false
		end
		return true
	end)
end

-- The tall cartoon column of water that shoots up and falls back.
local function column(position: Vector3, scale: number)
	local S = Config.Splash
	local part = blob("Column", Vector3.one, S.WaterColor, 0.1)
	local age = 0
	run(function(dt)
		age += dt
		local p = math.min(age / S.ColumnTime, 1)
		local height = math.max(S.ColumnHeight * scale * math.sin(math.pi * p), 0.05)
		local width = (0.9 + 0.9 * p) * scale
		part.Size = Vector3.new(width, height, width * 0.8)
		part.CFrame = CFrame.new(position + Vector3.new(0, height / 2 - 0.2, 0))
		part.Transparency = 0.1 + 0.5 * p
		if p >= 1 then
			part:Destroy()
			return false
		end
		return true
	end)
end

-- A puff of spray using Roblox particles.
local function spray(position: Vector3, scale: number)
	local holder = Shapes.carrier("Spray", Vector3.one, folder())
	holder.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(6 * scale, 13 * scale)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5 * scale),
		NumberSequenceKeypoint.new(1, 1.3 * scale),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Config.Splash.FoamColor, Config.Splash.WaterColor)
	emitter.LightEmission = 0.2
	emitter.Parent = holder
	emitter:Emit(24)
	task.delay(1.5, function()
		holder:Destroy()
	end)
end

-- The big splash when a kid hits the water.
function Splash.play(position: Vector3, scale: number?)
	local s = scale or 1
	local S = Config.Splash
	local surface = Vector3.new(position.X, Config.World.WaterY, position.Z)
	column(surface, s)
	droplets(surface, s)
	ring(surface, s, S.RingBlobs, S.RingStartRadius, S.RingEndRadius, S.RingTime, 0.75)
	ring(surface, s * 0.6, math.floor(S.RingBlobs * 0.7), S.RingStartRadius, S.RingEndRadius, S.RingTime * 1.3, 0.6)
	spray(surface, s)
end

-- A small ring on the water, for kids bobbing about.
function Splash.ripple(position: Vector3, scale: number?)
	local surface = Vector3.new(position.X, Config.World.WaterY, position.Z)
	ring(surface, scale or 1, 14, 0.8, 2.4, 0.9, 0.32)
end

-- Bubbles popping on the surface while a kid sinks.
function Splash.bubbles(position: Vector3, count: number, scale: number?)
	local s = scale or 1
	for _ = 1, count do
		local offset = Vector3.new(random:NextNumber(-0.8, 0.8), 0, random:NextNumber(-0.5, 0.5)) * s
		local pos = Vector3.new(position.X, Config.World.WaterY, position.Z) + offset
		local maxSize = random:NextNumber(0.25, 0.5) * s
		local part = blob("Bubble", Vector3.one * 0.05, Config.Splash.FoamColor, 0.25)
		local age, life = 0, random:NextNumber(0.25, 0.45)
		run(function(dt)
			age += dt
			local p = math.min(age / life, 1)
			local size = math.max(maxSize * math.sin(p * math.pi * 0.5), 0.05)
			part.Size = Vector3.new(size, size * 0.8, size)
			part.CFrame = CFrame.new(pos + Vector3.new(0, size * 0.2, 0))
			if p >= 1 then
				part:Destroy()
				return false
			end
			return true
		end)
	end
end

return Splash
