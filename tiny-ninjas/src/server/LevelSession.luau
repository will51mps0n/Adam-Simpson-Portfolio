--!strict
-- One play-through of one level by a group of players (for now each player gets their
-- own). The server owns everything that must be the same for everyone in it: which gold
-- is taken, which switches are pressed, and every moving enemy. Each player's ninja is
-- simulated on their own client; clients report where it is, and enemies hunt those
-- reported positions.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Levels = require(Shared.Levels)
local LevelGrid = require(Shared.LevelGrid)
local LevelObjects = require(Shared.Sim.LevelObjects)
local Protocol = require(Shared.Net.Protocol)
local Enemies = require(script.Parent.Enemies)
local Types = require(script.Parent.Enemies.Types)

local REACH_SLACK = 72 -- px: how far a reported ninja may be from something it says it touched
local MAX_SPEED_PER_FRAME = 16 -- px: faster reported movement than this is ignored...
local MAX_REJECTED = 10 -- ...unless it's reported this many times in a row (half a second)

type PlayerInfo = {
	ninja: Types.NinjaInfo,
	alive: boolean,
	done: boolean,
	reported: boolean,
	reportTime: number,
	rejected: number, -- reports ignored in a row
}

export type Session = {
	id: number,
	def: Levels.LevelDef,
	grid: LevelGrid.Grid,
	remotes: Protocol.Remotes,
	players: { [Player]: PlayerInfo },
	epoch: number,
	goldTaken: { [number]: boolean },
	pressed: { [number]: boolean },
	enemies: Enemies.State,
}

local LevelSession = {}

local nextId = 0

local function newInfo(): PlayerInfo
	return {
		ninja = { x = 0, y = 0, vx = 0, vy = 0, grounded = false },
		alive = true,
		done = false,
		reported = false,
		reportTime = 0,
		rejected = 0,
	}
end

local function keys(set: { [number]: boolean }): { number }
	local list = {}
	for id in set do
		table.insert(list, id)
	end
	return list
end

function LevelSession.new(levelId: string, remotes: Protocol.Remotes): Session
	local def = Levels.get(levelId)
	nextId = nextId % 65535 + 1
	local grid = LevelGrid.parse(def.grid, def.id)
	return {
		id = nextId,
		def = def,
		grid = grid,
		remotes = remotes,
		players = {},
		epoch = 0,
		goldTaken = {},
		pressed = {},
		enemies = Enemies.create(def, grid),
	}
end

function LevelSession.broadcast(s: Session, kind: string, ...: any)
	for player in s.players do
		s.remotes.SessionEvent:FireClient(player, kind, s.id, ...)
	end
end

function LevelSession.sendLoad(s: Session, player: Player)
	s.remotes.SessionEvent:FireClient(player, "load", s.id, s.def.id, s.epoch, keys(s.goldTaken), keys(s.pressed))
end

function LevelSession.addPlayer(s: Session, player: Player)
	s.players[player] = newInfo()
	LevelSession.sendLoad(s, player)
end

function LevelSession.removePlayer(s: Session, player: Player)
	s.players[player] = nil
end

-- Back to the start: gold, switches and enemies as the level begins.
function LevelSession.reset(s: Session)
	s.epoch = (s.epoch + 1) % 65536
	s.goldTaken = {}
	s.pressed = {}
	s.enemies = Enemies.create(s.def, s.grid)
	for player in s.players do
		s.players[player] = newInfo()
	end
	LevelSession.broadcast(s, "reset", s.epoch)
end

local function near(info: PlayerInfo, x: number, y: number): boolean
	if not info.reported then
		return true
	end
	local n = info.ninja
	return (n.x - x) ^ 2 + (n.y - y) ^ 2 < REACH_SLACK ^ 2
end

local function makeCtx(s: Session, dt: number, ninjas: { Types.NinjaInfo }): Types.Ctx
	return {
		grid = s.grid,
		frames = dt * 60,
		dt = dt,
		now = Workspace:GetServerTimeNow(),
		ninjas = ninjas,
		emit = function(kind: string, ...: any)
			LevelSession.broadcast(s, "enemy", kind, ...)
		end,
		blocked = s.enemies.blocked,
		spawnRocket = function() end,
	}
end

-- A request from one of this session's players. Everything here comes from a client, so
-- every argument is checked before it's trusted.
function LevelSession.onAction(s: Session, player: Player, kind: string, a: any, b: any, c: any)
	local info = s.players[player]
	if not info then
		return
	end
	if kind == "gold" then
		local obj = if type(a) == "number" then s.def.objects[a] else nil
		if obj and obj.type == "gold" and not s.goldTaken[a] and info.alive then
			local x, y = LevelObjects.center(obj)
			if near(info, x, y) then
				s.goldTaken[a] = true
				LevelSession.broadcast(s, "gold", a, player.UserId)
			end
		end
	elseif kind == "switch" then
		local obj = if type(a) == "number" then s.def.objects[a] else nil
		if obj and not s.pressed[a] and info.alive then
			local x: number?, y: number? = nil, nil
			if obj.type == "exitSwitch" then
				x, y = LevelObjects.center(obj)
			elseif obj.type == "lockedDoor" or obj.type == "trapDoor" then
				x, y = LevelObjects.doorSwitchCenter(obj)
			end
			if x and y and near(info, x, y) then
				s.pressed[a] = true
				LevelSession.broadcast(s, "switch", a)
			end
		end
	elseif kind == "died" then
		if info.alive then
			info.alive = false
			local cause = if type(a) == "string" then string.sub(a, 1, 24) else "unknown"
			LevelSession.broadcast(s, "died", player.UserId, cause)
		end
	elseif kind == "finished" then
		if info.alive and not info.done then
			info.done = true
			LevelSession.broadcast(s, "finished", player.UserId)
		end
	elseif kind == "restart" then
		LevelSession.reset(s)
	elseif kind == "rocketHit" then
		if type(a) == "number" and type(b) == "number" and type(c) == "number" and near(info, b, c) then
			Enemies.explodeRocket(s.enemies, makeCtx(s, 0, {}), a, b, c)
		end
	end
end

function LevelSession.onNinjaState(s: Session, player: Player, data: buffer)
	local info = s.players[player]
	if not info then
		return
	end
	local state = Protocol.decodeNinja(data)
	if not state or state.session ~= s.id then
		return
	end
	local x, y, vx, vy = state.x, state.y, state.vx, state.vy
	if x ~= x or y ~= y or math.abs(x) > 1e6 or math.abs(y) > 1e6 then
		return -- NaN or nonsense
	end
	local now = Workspace:GetServerTimeNow()
	local n = info.ninja
	if info.reported and info.rejected < MAX_REJECTED then
		local elapsed = now - info.reportTime
		local allowed = 48 + elapsed * 60 * MAX_SPEED_PER_FRAME
		if (x - n.x) ^ 2 + (y - n.y) ^ 2 > allowed * allowed then
			-- An impossible jump: keep the last believable position. If the client keeps
			-- insisting (say a respawn report overtook an older one), believe it after a bit.
			info.rejected += 1
			return
		end
	end
	info.rejected = 0
	n.x, n.y, n.vx, n.vy = x, y, vx, vy
	n.grounded = bit32.band(state.flags, Protocol.FLAG_GROUNDED) ~= 0
	info.reported = true
	info.reportTime = now
end

-- One server tick: move enemies, then send everyone a snapshot.
function LevelSession.tick(s: Session, dt: number)
	local living = {}
	for _, info in s.players do
		if info.alive and not info.done and info.reported then
			table.insert(living, info.ninja)
		end
	end
	local ctx = makeCtx(s, dt, living)
	Enemies.step(s.enemies, ctx)

	local entries = Enemies.snapshot(s.enemies)
	if #entries == 0 then
		return
	end
	local packets = {}
	for from = 1, #entries, Protocol.MAX_ENTRIES do
		local to = math.min(from + Protocol.MAX_ENTRIES - 1, #entries)
		table.insert(packets, Protocol.encodeSnapshot(s.epoch, ctx.now, entries, from, to))
	end
	for player in s.players do
		for _, packet in packets do
			s.remotes.EnemySnapshot:FireClient(player, packet)
		end
	end
end

return LevelSession
