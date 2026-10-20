--!strict
-- Runs this player's game. Loads the level the server picks, steps our ninja 60 times a
-- second, turns what it touches into requests to the server, handles deaths (ragdolls),
-- restarts and finishing, and keeps the time bar, HUD and camera up to date.
--
-- Our client is in charge of our own ninja: it decides our movement and when we die,
-- using the enemies exactly as they're drawn on our screen.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local Levels = require(Shared.Levels)
local LevelBuilder = require(Shared.LevelBuilder)
local LevelObjects = require(Shared.Sim.LevelObjects)
local Collision = require(Shared.Sim.Collision)
local NinjaSim = require(Shared.Sim.NinjaSim)
local Animator = require(Shared.Sim.Animator)
local Ragdoll = require(Shared.Sim.Ragdoll)
local Rig = require(Shared.Sim.Rig)
local Protocol = require(Shared.Net.Protocol)

local CameraController = require(script.Parent.CameraController)
local LevelController = require(script.Parent.LevelController)
local Input = require(script.Parent.Input)
local Hud = require(script.Parent.Hud)
local Effects = require(script.Parent.Effects)
local NinjaRig = require(script.Parent.Ninja.NinjaRig)
local ObjectsView = require(script.Parent.World.ObjectsView)
local EnemyView = require(script.Parent.World.EnemyView)

local STEP = 1 / Config.PHYSICS_HZ
local SEND_INTERVAL = 1 / 20
local NINJA_Z = 0.3 -- ninjas are drawn in front of objects and enemies
local RAGDOLL_Z = 0.28

local DEATH_TITLES: { [string]: string } = {
	impact = "Splat!",
	crushed = "Squashed!",
	time = "Out of time!",
	mine = "Boom!",
	rocket = "Boom!",
	explosion = "Boom!",
	zapDrone = "Zapped!",
	laserDrone = "Zapped!",
	chaingunDrone = "Zapped!",
	laser = "Lasered!",
	bullet = "Shot!",
	gauss = "Shot!",
	floorGuard = "Caught!",
	thwump = "Thwumped!",
	gaussTurret = "Zapped!",
	rocketTurret = "Zapped!",
}

type RagdollEntry = { sim: Ragdoll.Ragdoll, rig: NinjaRig.NinjaRig, bones: { { number } }, drawnAsleep: boolean }

type Play = {
	sessionId: number,
	built: LevelBuilder.BuiltLevel,
	world: Collision.World,
	objects: ObjectsView.ObjectsView,
	enemies: EnemyView.EnemyView,
	spawnX: number,
	spawnY: number,
	ninja: NinjaSim.Ninja,
	prevX: number,
	prevY: number,
	animator: Animator.Animator,
	rig: NinjaRig.NinjaRig,
	ragdolls: { RagdollEntry },
	timeLeft: number,
	timeAtStart: number,
	timerRunning: boolean,
	gold: number,
	deadFor: number,
	sendTimer: number,
	focus: Vector3, -- where the camera should look
}

local ClientSession = {}

local remotes: Protocol.Remotes
local play: Play? = nil
local accumulator = 0
local animView: Animator.View = {
	x = 0,
	y = 0,
	vx = 0,
	vy = 0,
	state = "air",
	facing = 1,
	h = 0,
	onFloor = false,
	wallNormal = 1,
	landFrames = 0,
	landSpeed = 0,
	spinFrames = 0,
	spinDir = 1,
} -- reused: the ninja as the animator should see it this frame

-- The ninja `n` as the animator should see it, drawn at (x, y).
local function viewOf(n: NinjaSim.Ninja, x: number, y: number): Animator.View
	local v = animView
	v.x, v.y, v.vx, v.vy = x, y, n.vx, n.vy
	v.state, v.facing, v.h, v.onFloor = n.state, n.facing, n.h, n.onFloor
	v.wallNormal, v.landFrames, v.landSpeed = n.wallNormal, n.landFrames, n.landSpeed
	v.spinFrames, v.spinDir = n.spinFrames, n.spinDir
	return v
end

local function fire(kind: string, ...: any)
	remotes.PlayerAction:FireServer(kind, ...)
end

local function clearRagdolls(p: Play)
	for _, entry in p.ragdolls do
		NinjaRig.destroy(entry.rig)
	end
	table.clear(p.ragdolls)
end

-- Starts the level over (locally right away; the server resets its side too).
local function restart(p: Play)
	clearRagdolls(p)
	ObjectsView.reset(p.objects)
	EnemyView.expectReset(p.enemies)
	fire("restart")
	p.ninja = NinjaSim.new(p.spawnX, p.spawnY)
	p.prevX, p.prevY = p.spawnX, p.spawnY
	Animator.snap(p.animator)
	NinjaRig.setVisible(p.rig, true)
	p.timeLeft = p.timeAtStart
	p.timerRunning = false
	p.gold = 0
	p.deadFor = 0
	Hud.message(nil)
end

local function addRagdoll(p: Play, pose: Rig.Pose, vx: number, vy: number, explosion: { x: number, y: number }?)
	local rig = NinjaRig.new(p.built.model, Config.COLORS.NINJA, Config.COLORS.HEADBAND, p.built.frontZ + RAGDOLL_Z)
	table.insert(p.ragdolls, { sim = Ragdoll.new(pose, vx, vy, explosion), rig = rig, bones = {}, drawnAsleep = false })
	while #p.ragdolls > Config.RAGDOLL_LIMIT do
		local oldest = table.remove(p.ragdolls, 1)
		if oldest then
			NinjaRig.destroy(oldest.rig)
		end
	end
end

-- Our ninja just died (NinjaSim already knows). Swap it for a ragdoll and tell the server.
local function onDeath(p: Play, cause: string, enemyId: number?, ex: number?, ey: number?)
	local n = p.ninja
	if not p.animator.tailsReady then
		Animator.update(p.animator, viewOf(n, n.x, n.y), 0) -- died before the first frame was drawn
	end
	local explosion: { x: number, y: number }? = nil
	if cause == "mine" or cause == "rocket" or cause == "explosion" then
		local bx, by = ex or n.x, ey or n.y
		explosion = { x = bx, y = by }
		if cause ~= "explosion" then
			-- (Rocket blasts that hit a wall come with their own explosion from the server.)
			Effects.explosion(p.built.model, bx, by, Config.EXPLOSION_RADIUS_PX, p.built.frontZ + 0.25)
		end
		if cause == "rocket" and enemyId then
			EnemyView.markExploded(p.enemies, enemyId)
			fire("rocketHit", enemyId, bx, by)
		end
	end
	addRagdoll(p, p.animator.pose, n.deathVx, n.deathVy, explosion)
	NinjaRig.setVisible(p.rig, false)
	fire("died", cause)
	p.deadFor = 0
	Hud.message(DEATH_TITLES[cause] or "Ouch!", "Press R to restart")
end

local function kill(p: Play, cause: string, enemyId: number?, ex: number?, ey: number?)
	if NinjaSim.kill(p.ninja, cause) then
		onDeath(p, cause, enemyId, ex, ey)
	end
end

local function finish(p: Play)
	local n = p.ninja
	n.state = "done"
	NinjaRig.setVisible(p.rig, false)
	fire("finished")
	Hud.message("Level complete!", string.format("%.1f seconds left. Press R to play again", p.timeLeft))
end

-- One 60 Hz frame of our ninja and everything it touches.
local function simStep(p: Play)
	local input = Input.sample()
	if input.restart then
		restart(p)
		return
	end
	local n = p.ninja
	local solids = p.world.solids
	table.clear(solids)
	ObjectsView.solids(p.objects, solids)
	EnemyView.solids(p.enemies, solids)

	if NinjaSim.isAlive(n) then
		if not p.timerRunning and Input.any(input) then
			p.timerRunning = true -- the clock starts with your first move
		end
		p.prevX, p.prevY = n.x, n.y
		for _, event in NinjaSim.step(n, input, p.world) do
			if event.kind == "death" then
				onDeath(p, event.cause or "impact")
			end
		end
		ObjectsView.step(p.objects, { n })
		if NinjaSim.isAlive(n) then
			for _, touch in ObjectsView.touch(p.objects, n.x, n.y) do
				if touch.kind == "gold" then
					p.gold += 1
					p.timeLeft += Config.GOLD_TIME
					fire("gold", touch.id)
				elseif touch.kind == "switch" then
					fire("switch", touch.id)
				elseif touch.kind == "launch" then
					NinjaSim.launch(n, touch.dx or 0, touch.dy or -1, Config.LAUNCH_PAD_SPEED)
				elseif touch.kind == "exit" and NinjaSim.isAlive(n) then
					finish(p)
				end
			end
		end
		if NinjaSim.isAlive(n) then
			local cause, id, ex, ey = EnemyView.hazard(p.enemies, n.x, n.y)
			if cause then
				kill(p, cause, id, ex, ey)
			end
		end
		if p.timerRunning and NinjaSim.isAlive(n) then
			p.timeLeft -= STEP
			if p.timeLeft <= 0 then
				p.timeLeft = 0
				kill(p, "time")
			end
		end
	else
		ObjectsView.step(p.objects, {})
		EnemyView.ignorePastShots(p.enemies)
		if n.state == "dead" then
			p.deadFor += STEP
			if p.deadFor >= Config.RESPAWN_DELAY then
				restart(p)
			end
		end
	end

	for _, entry in p.ragdolls do
		Ragdoll.step(entry.sim, p.world)
	end
end

local function render(p: Play, alpha: number, dt: number)
	local n = p.ninja
	if NinjaSim.isAlive(n) then
		local x = p.prevX + (n.x - p.prevX) * alpha
		local y = p.prevY + (n.y - p.prevY) * alpha
		NinjaRig.drawPose(p.rig, Animator.update(p.animator, viewOf(n, x, y), dt))
		p.focus = Units.toWorld(x, y)
	elseif #p.ragdolls > 0 then
		local last = p.ragdolls[#p.ragdolls].sim
		p.focus = Units.toWorld(last.x[3], last.y[3])
	end
	for _, entry in p.ragdolls do
		if not (entry.sim.asleep and entry.drawnAsleep) then
			NinjaRig.drawBones(entry.rig, Ragdoll.bones(entry.sim, entry.bones))
			entry.drawnAsleep = entry.sim.asleep
		end
	end
	ObjectsView.render(p.objects)
	Hud.setTime(p.timeLeft)
	Hud.setGold(p.gold)
end

local function sendState(p: Play, dt: number)
	p.sendTimer -= dt
	if p.sendTimer > 0 then
		return
	end
	p.sendTimer = SEND_INTERVAL
	local n = p.ninja
	local flags = 0
	if NinjaSim.isAlive(n) then
		flags += Protocol.FLAG_ALIVE
	end
	if n.onFloor then
		flags += Protocol.FLAG_GROUNDED
	end
	if n.state == "done" then
		flags += Protocol.FLAG_DONE
	end
	if n.state == "wall" then
		flags += Protocol.FLAG_WALL
	end
	remotes.NinjaState:FireServer(Protocol.encodeNinja(p.sessionId, n.x, n.y, n.vx, n.vy, flags))
end

local function frame(dt: number)
	local p = play
	if not p then
		return
	end
	EnemyView.update(p.enemies, Workspace:GetServerTimeNow() - Config.INTERP_DELAY, dt)
	accumulator = math.min(accumulator + dt, 0.25)
	while accumulator >= STEP do
		accumulator -= STEP
		simStep(p)
	end
	render(p, accumulator / STEP, dt)
	sendState(p, dt)
end

local function load(sessionId: number, levelId: string, epoch: number, goldTaken: { number }, pressed: { number })
	local built = LevelController.load(levelId)
	local objects = ObjectsView.new(built)
	ObjectsView.reset(objects, goldTaken, pressed)
	local enemies = EnemyView.new(built)
	EnemyView.reset(enemies, epoch)
	local spawn = LevelObjects.spawns(built.def)[1]
	local p: Play = {
		sessionId = sessionId,
		built = built,
		world = { grid = built.grid, solids = {} },
		objects = objects,
		enemies = enemies,
		spawnX = spawn.x,
		spawnY = spawn.y,
		ninja = NinjaSim.new(spawn.x, spawn.y),
		prevX = spawn.x,
		prevY = spawn.y,
		animator = Animator.new(),
		rig = NinjaRig.new(built.model, Config.COLORS.NINJA, Config.COLORS.HEADBAND, built.frontZ + NINJA_Z),
		ragdolls = {},
		timeLeft = Config.TIME_START,
		timeAtStart = Config.TIME_START,
		timerRunning = false,
		gold = 0,
		deadFor = 0,
		sendTimer = 0,
		focus = Units.toWorld(spawn.x, spawn.y),
	}
	play = p
	accumulator = 0
	CameraController.setTargets(function()
		return { p.focus }
	end)
	Hud.setLevel(built.def.name)
	Hud.message(nil)
end

local function onSessionEvent(kind: any, sessionId: any, ...: any)
	if kind == "load" then
		local levelId, epoch, goldTaken, pressed = ...
		if type(sessionId) == "number" and type(levelId) == "string" and type(epoch) == "number" then
			load(sessionId, levelId, epoch, if type(goldTaken) == "table" then goldTaken else {}, if type(pressed) == "table" then pressed else {})
		end
		return
	end
	local p = play
	if not p or sessionId ~= p.sessionId then
		return -- about a level we've left
	end
	local a = ...
	if kind == "reset" then
		if type(a) == "number" then
			EnemyView.reset(p.enemies, a)
		end
	elseif kind == "gold" then
		if type(a) == "number" then
			p.objects.goldTaken[a] = true
		end
	elseif kind == "switch" then
		if type(a) == "number" then
			p.objects.pressed[a] = true
		end
	elseif kind == "enemy" then
		if type(a) == "string" then
			EnemyView.onEvent(p.enemies, a, select(2, ...))
		end
	end
end

-- Test levels on the number keys, until the menus arrive in milestone 4.
local function bindDevKeys()
	local tests = Levels.list("test")
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local index = table.find(keys, input.KeyCode)
		if index and tests[index] then
			fire("loadLevel", tests[index].id)
		end
	end)
	local names = {}
	for i, def in tests do
		if i <= #keys then
			table.insert(names, `{i} {def.name}`)
		end
	end
	Hud.setHelp("Test levels: " .. table.concat(names, " · ") .. "   |   R restart")
end

-- The level being played right now (for debugging).
function ClientSession.current(): Play?
	return play
end

function ClientSession.start()
	remotes = Protocol.remotes()
	remotes.SessionEvent.OnClientEvent:Connect(onSessionEvent)
	remotes.EnemySnapshot.OnClientEvent:Connect(function(data: any)
		local p = play
		if p and typeof(data) == "buffer" then
			local snap = Protocol.decodeSnapshot(data)
			if snap then
				EnemyView.onSnapshot(p.enemies, snap)
			end
		end
	end)
	-- Before the camera, so it frames where the ninja is this frame.
	RunService:BindToRenderStep("TinyNinjasGame", Enum.RenderPriority.Input.Value + 1, frame)
	if Config.DEV_LEVEL_KEYS then
		bindDevKeys()
	end
	fire("ready")
end

return ClientSession
