--!strict
-- Every RemoteEvent the game uses. The server creates them all at startup,
-- so clients can always find them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RELIABLE: { string } = {
	"Fire", -- client -> server: weaponId, dirX, dirZ
	"ShotFired", -- server -> clients: shooter, weaponId, muzzle, endpoints
	"WeaponState", -- server -> client: owned weapon ids, ammo
	"PauseRequest", -- client -> server
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
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Net = {}

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
