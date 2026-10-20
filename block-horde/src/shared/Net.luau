--!strict
-- Every RemoteEvent the game uses. The server creates them all at startup,
-- so clients can always find them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RELIABLE: { string } = {
	-- client -> server
	"Fire", -- weaponId, dirX, dirZ, seed
	"PauseRequest",
	"PartyAction", -- action, value
	-- server -> client
	"ShotFired", -- shooter (or nil for turrets), weaponId, muzzle, endpoints, beam
	"WeaponState", -- owned weapon ids, ammo, upgrades
	"EnemyDied", -- flat list: id, kind, x, z, ...
	"EnemyEvent", -- kind ("teleport"), id, data
	"Projectile", -- "spawn"/"end", id, data
	"Explosion", -- x, z, radius, cause
	"Announce", -- text, style
	"RunResults", -- results table
	"PartyState", -- party table or nil
	"PlayerHurt", -- amount
}

local UNRELIABLE: { string } = {
	"EnemySnapshot", -- buffer (see Snapshot)
}

local folder: Instance
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in RELIABLE do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in UNRELIABLE do
		local remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Net = {}

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	return folder:WaitForChild(name) :: UnreliableRemoteEvent
end

return Net
