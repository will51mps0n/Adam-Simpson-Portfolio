--!strict
-- Draws grenades (arc through the air, then blink until they go off),
-- rockets (with a smoke trail) and devil fireballs from the server's
-- spawn messages. The server decides where they hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)

type Flying = {
	kind: string,
	parts: { Part },
	born: number,
	x: number,
	z: number,
	dx: number,
	dz: number,
	speed: number,
	toX: number,
	toZ: number,
	flight: number,
	smokeTimer: number,
}

local ProjectileRenderer = {}

local HEIGHT = 3.5
local MAX_AGE = 12

local folder: Folder
local flying: { [number]: Flying } = {}

local function part(size: Vector3, color: Color3, neon: boolean, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Parent = folder
	return p
end

local function onMessage(action: string, id: number, kind: string?, ...: any)
	if action == "end" then
		local entry = flying[id]
		if entry then
			flying[id] = nil
			for _, p in entry.parts do
				p:Destroy()
			end
		end
		return
	end
	if action ~= "spawn" or typeof(kind) ~= "string" then
		return
	end
	local args = { ... }
	local entry: Flying = {
		kind = kind,
		parts = {},
		born = os.clock(),
		x = args[1],
		z = args[2],
		dx = 0,
		dz = 0,
		speed = 0,
		toX = 0,
		toZ = 0,
		flight = 0,
		smokeTimer = 0,
	}
	if kind == "grenade" then
		entry.toX, entry.toZ, entry.flight = args[3], args[4], args[5]
		entry.parts = {
			part(Vector3.new(0.8, 0.8, 0.8), Color3.fromRGB(60, 80, 50), false),
			part(Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(255, 40, 40), true),
		}
	elseif kind == "rocket" then
		entry.dx, entry.dz, entry.speed = args[3], args[4], args[5]
		entry.parts = {
			part(Vector3.new(0.5, 0.5, 1.8), Color3.fromRGB(96, 104, 70), false),
			part(Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(255, 150, 40), true),
		}
		Sounds.play("rocket")
	elseif kind == "fireball" then
		entry.dx, entry.dz, entry.speed = args[3], args[4], args[5]
		entry.parts = {
			part(Vector3.one * 1.6, Color3.fromRGB(255, 110, 20), true, Enum.PartType.Ball),
			part(Vector3.one * 0.9, Color3.fromRGB(255, 230, 120), true, Enum.PartType.Ball),
		}
		entry.parts[1].Transparency = 0.25
	else
		return
	end
	flying[id] = entry
end

local function update(dt: number)
	local now = os.clock()
	local paused = workspace:GetAttribute("Paused") == true
	for id, entry in flying do
		if paused then
			entry.born += dt -- freeze in place while the game is paused
		end
		local age = now - entry.born
		if age > MAX_AGE then
			flying[id] = nil
			for _, p in entry.parts do
				p:Destroy()
			end
			continue
		end
		if entry.kind == "grenade" then
			local t = math.clamp(age / math.max(entry.flight, 1e-3), 0, 1)
			local x = entry.x + (entry.toX - entry.x) * t
			local z = entry.z + (entry.toZ - entry.z) * t
			local y = 0.4 + HEIGHT * 1.4 * math.sin(math.pi * t) + (1 - t) * 3
			local spin = CFrame.Angles(age * 9, age * 5, 0)
			entry.parts[1].CFrame = CFrame.new(x, y, z) * spin
			entry.parts[2].CFrame = CFrame.new(x, y + 0.5, z)
			-- Blink faster as the fuse runs down.
			entry.parts[2].Transparency = if math.floor(age * (4 + age * 6)) % 2 == 0 then 0 else 1
		else
			local x = entry.x + entry.dx * entry.speed * age
			local z = entry.z + entry.dz * entry.speed * age
			local at = CFrame.lookAt(Vector3.new(x, HEIGHT, z), Vector3.new(x + entry.dx, HEIGHT, z + entry.dz))
			entry.parts[1].CFrame = at
			if entry.kind == "rocket" then
				entry.parts[2].CFrame = at * CFrame.new(0, 0, 1.05)
				entry.smokeTimer -= dt
				if entry.smokeTimer <= 0 then
					entry.smokeTimer = 0.03
					Effects.smoke((at * CFrame.new(0, 0, 1.4)).Position)
				end
			else
				local pulse = 1 + math.sin(age * 30) * 0.12
				entry.parts[1].Size = Vector3.one * 1.6 * pulse
				entry.parts[2].CFrame = at
			end
		end
	end
end

function ProjectileRenderer.start()
	folder = Instance.new("Folder")
	folder.Name = "Projectiles"
	folder.Parent = workspace
	Net.event("Projectile").OnClientEvent:Connect(onMessage)
	RunService.RenderStepped:Connect(update)
end

return ProjectileRenderer
