--!strict
-- Short-lived visual effects drawn only on this client: tracers, railgun
-- beams, muzzle flashes, cartoon explosions with block debris, death bursts,
-- blood splats that stay on the floor (oldest fade past SPLAT_MAX) and puffs.
-- Parts are pooled and reused instead of created per effect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CameraController = require(script.Parent.CameraController)
local Sounds = require(script.Parent.Sounds)

local Effects = {}

type Fading = {
	part: Part,
	born: number,
	life: number,
	startTransparency: number,
	fromSize: Vector3?,
	toSize: Vector3?,
	center: CFrame?,
}

type Chunk = {
	part: Part,
	velocity: Vector3,
	spin: Vector3,
	born: number,
	life: number,
}

local HIDDEN = CFrame.new(0, -10000, 0)
local GRAVITY = 80
local ORANGE = Color3.fromRGB(255, 140, 30)
local YELLOW_WHITE = Color3.fromRGB(255, 244, 190)
local BLOOD = Color3.fromRGB(150, 16, 16)

local folder: Folder
local pool: { Part } = {}
local fading: { Fading } = {}
local chunks: { Chunk } = {}
local splats: { Part } = {}
local rng = Random.new()

local function newPart(): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

local function take(shape: Enum.PartType, material: Enum.Material, color: Color3): Part
	local part = table.remove(pool) or newPart()
	part.Shape = shape
	part.Material = material
	part.Color = color
	part.Transparency = 0
	return part
end

local function release(part: Part)
	part.Transparency = 1
	part.CFrame = HIDDEN
	table.insert(pool, part)
end

-- Fades a part out over `life` seconds, optionally growing it.
local function fade(part: Part, life: number, fromSize: Vector3?, toSize: Vector3?)
	local center = if fromSize then part.CFrame else nil
	table.insert(fading, {
		part = part,
		born = os.clock(),
		life = life,
		startTransparency = part.Transparency,
		fromSize = fromSize,
		toSize = toSize,
		center = center,
	})
end

local function debris(at: Vector3, colors: { Color3 }, count: number, speed: number, size: number)
	for _ = 1, count do
		local part = take(Enum.PartType.Block, Enum.Material.SmoothPlastic, colors[rng:NextInteger(1, #colors)])
		local s = size * rng:NextNumber(0.6, 1.3)
		part.Size = Vector3.new(s, s, s)
		part.CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 1.5), rng:NextNumber(-0.6, 0.6)))
		local angle = rng:NextNumber(0, math.pi * 2)
		local outward = rng:NextNumber(0.4, 1) * speed
		table.insert(chunks, {
			part = part,
			velocity = Vector3.new(math.cos(angle) * outward, rng:NextNumber(0.8, 1.6) * speed, math.sin(angle) * outward),
			spin = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)),
			born = os.clock(),
			life = rng:NextNumber(0.7, 1.1),
		})
	end
end

-- A flat mark on the floor that stays until SPLAT_MAX newer ones push it out.
function Effects.splat(x: number, z: number, size: number, color: Color3)
	local part = take(Enum.PartType.Block, Enum.Material.SmoothPlastic, color)
	part.Size = Vector3.new(size, 0.05, size * rng:NextNumber(0.7, 1.1))
	part.CFrame = CFrame.new(x, 0.07 + #splats % 7 * 0.004, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	table.insert(splats, part)
	while #splats > Config.SPLAT_MAX do
		local oldest = table.remove(splats, 1) :: Part
		fade(oldest, 1.5, nil, nil)
	end
end

function Effects.tracer(from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	local part = take(Enum.PartType.Block, Enum.Material.Neon, color)
	part.Size = Vector3.new(Config.TRACER_WIDTH, Config.TRACER_WIDTH, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	fade(part, Config.TRACER_LIFETIME, nil, nil)
end

-- Railgun: a thick glowing line that lingers a moment.
function Effects.beam(from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	local mid = (from + to) / 2
	local core = take(Enum.PartType.Block, Enum.Material.Neon, Color3.new(1, 1, 1))
	core.Size = Vector3.new(0.3, 0.3, length)
	core.CFrame = CFrame.lookAt(mid, to)
	fade(core, Config.BEAM_LIFETIME * 0.6, nil, nil)
	local glow = take(Enum.PartType.Block, Enum.Material.Neon, color)
	glow.Transparency = 0.35
	glow.Size = Vector3.new(0.9, 0.9, length)
	glow.CFrame = CFrame.lookAt(mid, to)
	fade(glow, Config.BEAM_LIFETIME, glow.Size, Vector3.new(0.1, 0.1, length))
end

function Effects.muzzleFlash(at: Vector3)
	local part = take(Enum.PartType.Block, Enum.Material.Neon, YELLOW_WHITE)
	part.Size = Vector3.new(0.7, 0.7, 0.7)
	part.CFrame = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0)
	fade(part, Config.MUZZLE_FLASH_TIME, nil, nil)
end

local function shakeFrom(x: number, z: number, strength: number)
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local listener = if root and root:IsA("BasePart") then root.Position else workspace.CurrentCamera.Focus.Position
	local dist = (Vector3.new(x, 0, z) - Vector3.new(listener.X, 0, listener.Z)).Magnitude
	local closeness = math.clamp(1 - dist / Config.CAMERA_SHAKE_RANGE, 0, 1)
	CameraController.shake(closeness * strength)
end

-- Round orange-and-white cartoon blast with flying blocks and a scorch mark.
function Effects.explosion(x: number, z: number, radius: number)
	local at = CFrame.new(x, 2, z)
	local outer = take(Enum.PartType.Ball, Enum.Material.Neon, ORANGE)
	outer.Transparency = 0.1
	outer.Size = Vector3.one * 2
	outer.CFrame = at
	fade(outer, 0.4, outer.Size, Vector3.one * radius * 2)
	local core = take(Enum.PartType.Ball, Enum.Material.Neon, YELLOW_WHITE)
	core.Size = Vector3.one
	core.CFrame = at
	fade(core, 0.22, core.Size, Vector3.one * radius * 1.1)
	debris(Vector3.new(x, 1, z), { ORANGE, Color3.fromRGB(60, 56, 52), YELLOW_WHITE }, 10, 26, 0.7)
	Effects.splat(x, z, radius * 0.7, Color3.fromRGB(34, 30, 28))
	shakeFrom(x, z, math.clamp(radius / 12, 0.3, 1))
	Sounds.play("explosion")
end

function Effects.enemyDeath(x: number, z: number, colors: { Color3 })
	debris(Vector3.new(x, 2, z), colors, Config.DEBRIS_PER_DEATH, 18, 0.55)
	Effects.splat(x, z, rng:NextNumber(2.4, 3.6), BLOOD:Lerp(Color3.fromRGB(110, 8, 8), rng:NextNumber(0, 1)))
	Sounds.play("enemyDeath", 0.7)
end

function Effects.playerDeath(x: number, z: number)
	debris(Vector3.new(x, 2.5, z), { Config.SKIN_COLOR, Config.HAIR_COLOR, BLOOD, Config.HEADBAND_COLOR }, 12, 20, 0.6)
	Effects.splat(x, z, 4.5, BLOOD)
	Sounds.play("playerDeath")
end

-- Something placeable breaking.
function Effects.breakPuff(x: number, z: number)
	debris(Vector3.new(x, 1.5, z), { Color3.fromRGB(150, 146, 140), Color3.fromRGB(90, 90, 96) }, 8, 16, 0.6)
end

function Effects.teleportPuff(x: number, z: number)
	for _ = 1, 5 do
		local part = take(Enum.PartType.Block, Enum.Material.SmoothPlastic, Color3.fromRGB(90, 40, 120))
		part.Transparency = 0.3
		part.Size = Vector3.one * 1.2
		part.CFrame = CFrame.new(x + rng:NextNumber(-1.2, 1.2), rng:NextNumber(1, 4), z + rng:NextNumber(-1.2, 1.2))
		fade(part, 0.5, part.Size, Vector3.one * 2.4)
	end
end

function Effects.smoke(at: Vector3)
	local part = take(Enum.PartType.Block, Enum.Material.SmoothPlastic, Color3.fromRGB(170, 170, 170))
	part.Transparency = 0.35
	part.Size = Vector3.one * 0.5
	part.CFrame = CFrame.new(at) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 1), 0)
	fade(part, 0.6, part.Size, Vector3.one * 1.6)
end

-- Server explosion messages: a blast, or radius 0 for a death or a break.
function Effects.fromServer(x: number, z: number, radius: number, cause: string)
	if cause == "death" then
		Effects.playerDeath(x, z)
	elseif cause == "break" then
		Effects.breakPuff(x, z)
	else
		Effects.explosion(x, z, radius)
	end
end

local function update(dt: number)
	local now = os.clock()
	for i = #fading, 1, -1 do
		local entry = fading[i]
		local t = (now - entry.born) / entry.life
		if t >= 1 then
			release(entry.part)
			fading[i] = fading[#fading]
			fading[#fading] = nil
		else
			entry.part.Transparency = entry.startTransparency + (1 - entry.startTransparency) * t
			local fromSize, toSize, center = entry.fromSize, entry.toSize, entry.center
			if fromSize and toSize and center then
				entry.part.Size = fromSize:Lerp(toSize, math.sqrt(t))
				entry.part.CFrame = center
			end
		end
	end
	for i = #chunks, 1, -1 do
		local chunk = chunks[i]
		local age = now - chunk.born
		if age >= chunk.life then
			release(chunk.part)
			chunks[i] = chunks[#chunks]
			chunks[#chunks] = nil
			continue
		end
		local velocity = chunk.velocity - Vector3.new(0, GRAVITY * dt, 0)
		local cframe = chunk.part.CFrame + velocity * dt
		local floor = chunk.part.Size.Y / 2
		if cframe.Position.Y < floor then
			cframe = CFrame.new(cframe.Position.X, floor, cframe.Position.Z) * cframe.Rotation
			velocity = Vector3.new(velocity.X * 0.6, math.abs(velocity.Y) * 0.3, velocity.Z * 0.6)
			chunk.spin *= 0.5
		end
		chunk.velocity = velocity
		chunk.part.CFrame = cframe * CFrame.Angles(chunk.spin.X * dt, chunk.spin.Y * dt, chunk.spin.Z * dt)
		if age > chunk.life - 0.3 then
			chunk.part.Transparency = (age - (chunk.life - 0.3)) / 0.3
		end
	end
end

-- Removes every splat (e.g. when a new run starts).
function Effects.clearSplats()
	for _, part in splats do
		release(part)
	end
	table.clear(splats)
end

function Effects.start()
	folder = Instance.new("Folder")
	folder.Name = "ClientEffects"
	folder.Parent = workspace
	RunService.Heartbeat:Connect(update)
end

return Effects
