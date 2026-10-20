--!strict
-- Checks every shot a client asks for (owned weapon, fire rate, ammo) and
-- applies hitscan damage against the enemy table. Then tells all clients so
-- they can draw the tracer; the shooter already drew theirs instantly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hitscan = require(ReplicatedStorage.Shared.Hitscan)
local Net = require(ReplicatedStorage.Shared.Net)
local Arena = require(script.Parent.Arena)
local Enemies = require(script.Parent.Enemies)
local Loadout = require(script.Parent.Loadout)
local PauseService = require(script.Parent.PauseService)

local Fire = Net.event("Fire")
local ShotFired = Net.event("ShotFired")

local WeaponService = {}

-- Per player, per weapon: the earliest time the next shot is allowed.
local nextShotAt: { [Player]: { [string]: number } } = {}

local function circleOf(enemy: Enemies.Enemy): (number, number, number)
	return enemy.x, enemy.z, enemy.radius
end

local function onFire(player: Player, weaponId: unknown, dirX: unknown, dirZ: unknown)
	if typeof(weaponId) ~= "string" or typeof(dirX) ~= "number" or typeof(dirZ) ~= "number" then
		return
	end
	local weapon = Config.WEAPONS[weaponId]
	if not weapon or PauseService.isPaused() or not Loadout.owns(player, weaponId) then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end

	local length = math.sqrt(dirX * dirX + dirZ * dirZ)
	if length ~= length or length < 0.01 then
		return -- NaN or zero direction
	end
	local dx, dz = dirX / length, dirZ / length

	-- Fire rate check, with half an interval of slack for network jitter.
	local now = os.clock()
	local times = nextShotAt[player]
	if not times then
		times = {}
		nextShotAt[player] = times
	end
	local allowedAt = times[weaponId] or 0
	if now < allowedAt - weapon.fireInterval * 0.5 then
		return
	end
	times[weaponId] = math.max(allowedAt, now) + weapon.fireInterval

	if not Loadout.useAmmo(player, weaponId) then
		return
	end

	-- Cast from the player's center so enemies hugging the gun still get hit.
	local pos = root.Position
	local wallDist = Arena.grid():raycast(pos.X, pos.Z, dx, dz, weapon.range)
	local hits, travel = Hitscan.cast(pos.X, pos.Z, dx, dz, wallDist, Enemies.list(), circleOf, weapon.pierce)
	for _, enemy in hits do
		Enemies.damage(enemy, weapon.damage, player)
	end

	local y = pos.Y + Config.MUZZLE_HEIGHT
	local muzzle = Vector3.new(pos.X + dx * Config.MUZZLE_FORWARD, y, pos.Z + dz * Config.MUZZLE_FORWARD)
	local endpoints = {}
	if travel > Config.MUZZLE_FORWARD then
		table.insert(endpoints, Vector3.new(pos.X + dx * travel, y, pos.Z + dz * travel))
	end
	ShotFired:FireAllClients(player, weaponId, muzzle, endpoints)
end

function WeaponService.start()
	Fire.OnServerEvent:Connect(onFire)
	Players.PlayerRemoving:Connect(function(player)
		nextShotAt[player] = nil
	end)
end

return WeaponService
