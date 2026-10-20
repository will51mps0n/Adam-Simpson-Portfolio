--!strict
-- How the server and clients talk.
--
-- Remotes (all in ReplicatedStorage.Remotes):
--   SessionEvent   server -> client  reliable: level loads, resets, object changes, enemy shots
--   PlayerAction   client -> server  reliable: ready, gold taken, switch pressed, died, restart...
--   NinjaState     client -> server  unreliable, 20 per second: where my ninja is
--   EnemySnapshot  server -> client  unreliable, 30 per second: where the moving enemies are
--
-- Ninja states and enemy snapshots are packed into buffers to keep them small.

local Protocol = {}

Protocol.REMOTES = {
	SessionEvent = "RemoteEvent",
	PlayerAction = "RemoteEvent",
	NinjaState = "UnreliableRemoteEvent",
	EnemySnapshot = "UnreliableRemoteEvent",
} :: { [string]: string }

export type Remotes = {
	SessionEvent: RemoteEvent,
	PlayerAction: RemoteEvent,
	NinjaState: UnreliableRemoteEvent,
	EnemySnapshot: UnreliableRemoteEvent,
}

-- Server: creates the remotes. Client: waits for them.
function Protocol.remotes(): Remotes
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local folder: Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			existing:Destroy()
		end
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for name, className in Protocol.REMOTES do
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
	return {
		SessionEvent = folder:WaitForChild("SessionEvent") :: RemoteEvent,
		PlayerAction = folder:WaitForChild("PlayerAction") :: RemoteEvent,
		NinjaState = folder:WaitForChild("NinjaState") :: UnreliableRemoteEvent,
		EnemySnapshot = folder:WaitForChild("EnemySnapshot") :: UnreliableRemoteEvent,
	}
end

--------------------------------------------------------------------------------
-- Ninja state: session u16, x y vx vy f32, flags u8 = 19 bytes
--------------------------------------------------------------------------------

Protocol.FLAG_ALIVE = 1
Protocol.FLAG_GROUNDED = 2
Protocol.FLAG_DONE = 4
Protocol.FLAG_WALL = 8

function Protocol.encodeNinja(session: number, x: number, y: number, vx: number, vy: number, flags: number): buffer
	local b = buffer.create(19)
	buffer.writeu16(b, 0, session)
	buffer.writef32(b, 2, x)
	buffer.writef32(b, 6, y)
	buffer.writef32(b, 10, vx)
	buffer.writef32(b, 14, vy)
	buffer.writeu8(b, 18, flags)
	return b
end

export type NinjaState = { session: number, x: number, y: number, vx: number, vy: number, flags: number }

function Protocol.decodeNinja(b: buffer): NinjaState?
	if buffer.len(b) ~= 19 then
		return nil
	end
	return {
		session = buffer.readu16(b, 0),
		x = buffer.readf32(b, 2),
		y = buffer.readf32(b, 6),
		vx = buffer.readf32(b, 10),
		vy = buffer.readf32(b, 14),
		flags = buffer.readu8(b, 18),
	}
end

--------------------------------------------------------------------------------
-- Enemy snapshot: epoch u16, time f64, count u8, then per entry
-- id u16, x f32, y f32, a f32 (angle or extra), s u8 (state) = 15 bytes
--------------------------------------------------------------------------------

export type Entry = { id: number, x: number, y: number, a: number, s: number }

local HEADER = 11
local ENTRY = 15
Protocol.MAX_ENTRIES = 40 -- per packet, keeping each well under the unreliable size limit

-- Packs entries[from..to] into one packet.
function Protocol.encodeSnapshot(epoch: number, time: number, entries: { Entry }, from: number, to: number): buffer
	local count = to - from + 1
	local b = buffer.create(HEADER + count * ENTRY)
	buffer.writeu16(b, 0, epoch % 65536)
	buffer.writef64(b, 2, time)
	buffer.writeu8(b, 10, count)
	local o = HEADER
	for i = from, to do
		local e = entries[i]
		buffer.writeu16(b, o, e.id)
		buffer.writef32(b, o + 2, e.x)
		buffer.writef32(b, o + 6, e.y)
		buffer.writef32(b, o + 10, e.a)
		buffer.writeu8(b, o + 14, e.s)
		o += ENTRY
	end
	return b
end

export type Snapshot = { epoch: number, time: number, entries: { Entry } }

function Protocol.decodeSnapshot(b: buffer): Snapshot?
	local len = buffer.len(b)
	if len < HEADER then
		return nil
	end
	local count = buffer.readu8(b, 10)
	if len ~= HEADER + count * ENTRY then
		return nil
	end
	local entries = table.create(count)
	local o = HEADER
	for i = 1, count do
		entries[i] = {
			id = buffer.readu16(b, o),
			x = buffer.readf32(b, o + 2),
			y = buffer.readf32(b, o + 6),
			a = buffer.readf32(b, o + 10),
			s = buffer.readu8(b, o + 14),
		}
		o += ENTRY
	end
	return { epoch = buffer.readu16(b, 0), time = buffer.readf64(b, 2), entries = entries }
end

return Protocol
