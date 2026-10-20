--!strict
-- Packs enemy positions into small binary buffers for the 15-per-second
-- position updates. Unreliable remote messages must stay under 900 bytes, so
-- big hordes are split across several packets.
--
-- Layout: f64 server time, then per enemy 9 bytes:
--   u16 id, u8 kind, i16 x*10, i16 z*10, u8 facing, u8 health (0-255)

local Snapshot = {}

Snapshot.HEADER = 8
Snapshot.ENTRY = 9
Snapshot.MAX_PER_PACKET = 80 -- 8 + 80 * 9 = 728 bytes, safely under the limit

local TAU = math.pi * 2

function Snapshot.create(count: number, time: number): buffer
	local buf = buffer.create(Snapshot.HEADER + count * Snapshot.ENTRY)
	buffer.writef64(buf, 0, time)
	return buf
end

local function fixed(value: number): number
	return math.clamp(math.round(value * 10), -32768, 32767)
end

-- slot is 0-based. facing is an angle in radians; health is 0-1.
function Snapshot.write(buf: buffer, slot: number, id: number, kind: number, x: number, z: number, facing: number, health: number)
	local at = Snapshot.HEADER + slot * Snapshot.ENTRY
	buffer.writeu16(buf, at, id)
	buffer.writeu8(buf, at + 2, kind)
	buffer.writei16(buf, at + 3, fixed(x))
	buffer.writei16(buf, at + 5, fixed(z))
	buffer.writeu8(buf, at + 7, math.floor((facing % TAU) / TAU * 256) % 256)
	buffer.writeu8(buf, at + 8, if health > 0 then math.clamp(math.ceil(health * 255), 1, 255) else 0)
end

function Snapshot.time(buf: buffer): number
	return buffer.readf64(buf, 0)
end

-- Calls visit for every enemy in the packet and returns the packet's server time.
function Snapshot.read(buf: buffer, visit: (id: number, kind: number, x: number, z: number, facing: number, health: number) -> ()): number
	local count = (buffer.len(buf) - Snapshot.HEADER) // Snapshot.ENTRY
	for slot = 0, count - 1 do
		local at = Snapshot.HEADER + slot * Snapshot.ENTRY
		visit(
			buffer.readu16(buf, at),
			buffer.readu8(buf, at + 2),
			buffer.readi16(buf, at + 3) / 10,
			buffer.readi16(buf, at + 5) / 10,
			buffer.readu8(buf, at + 7) / 256 * TAU,
			buffer.readu8(buf, at + 8) / 255
		)
	end
	return buffer.readf64(buf, 0)
end

return Snapshot
