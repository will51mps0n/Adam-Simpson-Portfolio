--!strict
-- The local player's weapons: picks the equipped weapon, fires while the fire
-- input is held, draws the tracer instantly, and asks the server to shoot.
-- Also draws other players' shots when the server reports them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Hitscan = require(Shared:WaitForChild("Hitscan"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local CharacterController = require(script.Parent.CharacterController)
local ClientArena = require(script.Parent.ClientArena)
local Effects = require(script.Parent.Effects)
local EnemyView = require(script.Parent.EnemyView)
local Input = require(script.Parent.InputController)

local Fire = Net.event("Fire")
local ShotFired = Net.event("ShotFired")
local WeaponState = Net.event("WeaponState")

local WeaponController = {}

WeaponController.Changed = Signal.new() -- fires when the equipped weapon, owned list or ammo changes

local equipped = "pistol"
local owned: { [string]: boolean } = { pistol = true }
local ammo: { [string]: number } = {}
local nextShotAt = 0

function WeaponController.getEquipped(): string
	return equipped
end

function WeaponController.getAmmo(weaponId: string): number?
	local weapon = Config.WEAPONS[weaponId]
	if not weapon or weapon.maxAmmo == nil then
		return nil -- infinite
	end
	return ammo[weaponId] or 0
end

local function ownedInSlotOrder(): { string }
	local list = {}
	for id in owned do
		if Config.WEAPONS[id] then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		return Config.WEAPONS[a].slot < Config.WEAPONS[b].slot
	end)
	return list
end

local function equip(weaponId: string)
	if owned[weaponId] and Config.WEAPONS[weaponId] and weaponId ~= equipped then
		equipped = weaponId
		WeaponController.Changed:Fire()
	end
end

local function fire()
	local weapon = Config.WEAPONS[equipped]
	local root = CharacterController.getRoot()
	if not weapon or not root then
		return
	end
	if weapon.maxAmmo ~= nil then
		local left = ammo[equipped] or 0
		if left <= 0 then
			return
		end
		ammo[equipped] = left - 1
		WeaponController.Changed:Fire()
	end

	local dir = CharacterController.getFacing()
	local pos = root.Position
	local y = pos.Y + Config.MUZZLE_HEIGHT
	local muzzle = Vector3.new(pos.X + dir.X * Config.MUZZLE_FORWARD, y, pos.Z + dir.Z * Config.MUZZLE_FORWARD)

	-- Predict where the bullet stops, the same way the server will.
	local grid = ClientArena.grid()
	local maxDist = if grid then grid:raycast(pos.X, pos.Z, dir.X, dir.Z, weapon.range) else weapon.range
	local _, travel = Hitscan.cast(pos.X, pos.Z, dir.X, dir.Z, maxDist, EnemyView.getTargets(), EnemyView.circleOf, weapon.pierce)

	Effects.muzzleFlash(muzzle)
	if travel > Config.MUZZLE_FORWARD then
		Effects.tracer(muzzle, Vector3.new(pos.X + dir.X * travel, y, pos.Z + dir.Z * travel), weapon.tracerColor)
	end
	Fire:FireServer(equipped, dir.X, dir.Z)
end

local function update()
	if not Input.isFireHeld() or workspace:GetAttribute("Paused") == true or not CharacterController.isAlive() then
		return
	end
	local weapon = Config.WEAPONS[equipped]
	local now = os.clock()
	if weapon and now >= nextShotAt then
		nextShotAt = now + weapon.fireInterval
		fire()
	end
end

local function onWeaponState(ownedList: { string }, ammoTable: { [string]: number })
	owned = {}
	for _, id in ownedList do
		owned[id] = true
	end
	ammo = ammoTable
	if not owned[equipped] then
		equipped = "pistol"
	end
	WeaponController.Changed:Fire()
end

local function onShotFired(shooter: Player, weaponId: string, muzzle: Vector3, endpoints: { Vector3 })
	if shooter == Players.LocalPlayer then
		return -- already drawn when we fired
	end
	local weapon = Config.WEAPONS[weaponId]
	if not weapon then
		return
	end
	Effects.muzzleFlash(muzzle)
	for _, point in endpoints do
		Effects.tracer(muzzle, point, weapon.tracerColor)
	end
end

function WeaponController.start()
	Input.WeaponSlot:Connect(function(slot: number)
		for id in owned do
			local weapon = Config.WEAPONS[id]
			if weapon and weapon.slot == slot then
				equip(id)
				return
			end
		end
	end)
	Input.CycleWeapon:Connect(function(step: number)
		local list = ownedInSlotOrder()
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
