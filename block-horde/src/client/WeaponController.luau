--!strict
-- The local player's weapons: picks the equipped weapon, fires while the fire
-- input is held (only in a run), draws hitscan tracers instantly using the
-- same pellet pattern the server will use, and asks the server to shoot.
-- Also draws other players' and turrets' shots when the server reports them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Hitscan = require(Shared:WaitForChild("Hitscan"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local WeaponStats = require(Shared:WaitForChild("WeaponStats"))
local CharacterController = require(script.Parent.CharacterController)
local ClientArena = require(script.Parent.ClientArena)
local Effects = require(script.Parent.Effects)
local EnemyRenderer = require(script.Parent.EnemyRenderer)
local Input = require(script.Parent.InputController)
local Sounds = require(script.Parent.Sounds)

local Fire = Net.event("Fire")
local ShotFired = Net.event("ShotFired")
local WeaponState = Net.event("WeaponState")

local player = Players.LocalPlayer

local WeaponController = {}

WeaponController.Changed = Signal.new() -- equipped weapon, owned list or ammo changed

local TURRET_TRACER = Color3.fromRGB(255, 200, 90)

local equipped = "pistol"
local owned: { [string]: boolean } = { pistol = true }
local upgrades: { [string]: { [string]: boolean } } = {}
local ammo: { [string]: number } = {}
local nextShotAt = 0

function WeaponController.getEquipped(): string
	return equipped
end

function WeaponController.owns(weaponId: string): boolean
	return owned[weaponId] == true
end

function WeaponController.stats(weaponId: string): WeaponStats.Stats
	return WeaponStats.get(weaponId, upgrades[weaponId])
end

-- Shots left, or nil for infinite.
function WeaponController.getAmmo(weaponId: string): number?
	if WeaponController.stats(weaponId).maxAmmo == nil then
		return nil
	end
	return ammo[weaponId] or 0
end

local function hasAmmo(weaponId: string): boolean
	local left = WeaponController.getAmmo(weaponId)
	return left == nil or left > 0
end

local function equip(weaponId: string)
	if owned[weaponId] and Config.WEAPONS[weaponId] and weaponId ~= equipped then
		equipped = weaponId
		nextShotAt = math.max(nextShotAt, os.clock() + 0.1)
		WeaponController.Changed:Fire()
	end
end

-- Owned weapons in number-key order.
local function ownedInOrder(): { string }
	local list = {}
	for _, id in Config.WEAPON_ORDER do
		if owned[id] then
			table.insert(list, id)
		end
	end
	return list
end

-- Out of ammo: drop to the best owned gun that still has some.
local function switchFromEmpty()
	local list = ownedInOrder()
	for i = #list, 1, -1 do
		local id = list[i]
		local kind = Config.WEAPONS[id].kind
		if id ~= equipped and hasAmmo(id) and kind ~= "place" then
			equip(id)
			return
		end
	end
	equip("pistol")
end

local function predictTravel(stats: WeaponStats.Stats, x: number, z: number, dx: number, dz: number): number
	local grid = ClientArena.grid()
	local wall = if grid then grid:raycast(x, z, dx, dz, stats.range) else stats.range
	local function circle(t: { x: number, z: number, radius: number }): (number, number, number)
		return t.x, t.z, t.radius
	end
	local _, enemyTravel = Hitscan.cast(x, z, dx, dz, wall, EnemyRenderer.targets(), circle, stats.pierce)
	local _, barrelTravel = Hitscan.cast(x, z, dx, dz, wall, ClientArena.barrels(), circle, stats.pierce)
	if stats.pierce > 1 then
		return wall
	end
	return math.min(enemyTravel, barrelTravel)
end

local function fire()
	local stats = WeaponController.stats(equipped)
	local root = CharacterController.getRoot()
	if not root then
		return
	end
	if not hasAmmo(equipped) then
		switchFromEmpty()
		return
	end
	if stats.maxAmmo ~= nil then
		ammo[equipped] = (ammo[equipped] or 0) - 1
		WeaponController.Changed:Fire()
	end

	local dir = CharacterController.getFacing()
	local pos = root.Position
	local y = pos.Y + Config.MUZZLE_HEIGHT
	local muzzle = Vector3.new(pos.X + dir.X * Config.MUZZLE_FORWARD, y, pos.Z + dir.Z * Config.MUZZLE_FORWARD)
	local seed = math.random(1, 1000000000)

	if stats.kind == "hitscan" then
		Effects.muzzleFlash(muzzle)
		for _, pellet in WeaponStats.pelletDirections(dir.X, dir.Z, stats, seed) do
			local dx, dz = pellet[1], pellet[2]
			local travel = predictTravel(stats, pos.X, pos.Z, dx, dz)
			if travel > Config.MUZZLE_FORWARD then
				local finish = Vector3.new(pos.X + dx * travel, y, pos.Z + dz * travel)
				if stats.beam then
					Effects.beam(muzzle, finish, stats.tracerColor)
				else
					Effects.tracer(muzzle, finish, stats.tracerColor)
				end
			end
		end
		Sounds.play(equipped)
	elseif stats.kind == "rocket" then
		Effects.muzzleFlash(muzzle)
	end
	Fire:FireServer(equipped, dir.X, dir.Z, seed)

	if not hasAmmo(equipped) then
		switchFromEmpty()
	end
end

local function update()
	if player:GetAttribute("InRun") ~= true or not Input.isFireHeld() then
		return
	end
	if workspace:GetAttribute("Paused") == true or not CharacterController.isAlive() then
		return
	end
	if ReplicatedStorage:GetAttribute("RunPhase") == "Over" then
		return
	end
	local now = os.clock()
	if now >= nextShotAt then
		nextShotAt = now + WeaponController.stats(equipped).fireInterval
		fire()
	end
end

local function onWeaponState(ownedList: { string }, ammoTable: { [string]: number }, upgradeLists: { [string]: { string } })
	owned = {}
	for _, id in ownedList do
		owned[id] = true
	end
	if next(owned) == nil then
		owned.pistol = true
	end
	ammo = ammoTable
	upgrades = {}
	for id, names in upgradeLists do
		local set = {}
		for _, name in names do
			set[name] = true
		end
		upgrades[id] = set
	end
	if not owned[equipped] then
		equipped = "pistol"
	end
	WeaponController.Changed:Fire()
end

local function onShotFired(shooter: Player?, weaponId: string, muzzle: Vector3, endpoints: { Vector3 }, _seed: number)
	if shooter == player then
		return -- already drawn when we fired
	end
	local color = TURRET_TRACER
	local beam = false
	if weaponId ~= "turret" then
		local stats = WeaponStats.get(weaponId, nil)
		color, beam = stats.tracerColor, stats.beam
	end
	Effects.muzzleFlash(muzzle)
	for _, point in endpoints do
		if beam then
			Effects.beam(muzzle, point, color)
		else
			Effects.tracer(muzzle, point, color)
		end
	end
	if shooter then
		Sounds.play(weaponId, 0.5)
	end
end

function WeaponController.start()
	Input.WeaponSlot:Connect(function(slot: number)
		for _, id in Config.WEAPON_ORDER do
			if Config.WEAPONS[id].slot == slot then
				equip(id)
				return
			end
		end
	end)
	Input.CycleWeapon:Connect(function(step: number)
		if not CharacterController.isAlive() then
			return -- Q/E switch who you spectate instead
		end
		local list = ownedInOrder()
		if #list == 0 then
			return
		end
		local index = table.find(list, equipped) or 1
		equip(list[(index - 1 + step) % #list + 1])
	end)
	WeaponState.OnClientEvent:Connect(onWeaponState)
	ShotFired.OnClientEvent:Connect(onShotFired)
	RunService.Heartbeat:Connect(update)
end

return WeaponController
