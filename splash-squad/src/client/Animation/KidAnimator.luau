--!strict
-- Brings a kid to life: bobbing on the waves, blinking, aiming, throwing
-- with squash and stretch, flinching when hit, flailing through the air,
-- splashing into the water, bobbing there sadly and sinking out of view.
--
-- Everything is computed each frame from simple curves and handed to the
-- kid's rig (Shared/Character/KidRig.luau). One loop drives all kids.
--
--   local animator = KidAnimator.new(kid, { home = Vector3.new(0, 1, 0), facing = 1 })
--   animator:Aim(true)    animator:Fire()    animator:Hit(1)
--   animator:Knock(Vector3.new(-20, 18, 0))  animator:Win(true)  animator:DropIn()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local KidRig = require(ReplicatedStorage.Shared.Character.KidRig)
local CharacterBuilder = require(ReplicatedStorage.Shared.Character.CharacterBuilder)
local Curve = require(script.Parent.Curve)
local Splash = require(script.Parent.Parent.Effects.Splash)

type Kid = CharacterBuilder.Kid

type Overlay = {
	kind: string,
	t: number,
	duration: number,
	direction: number,
}

type Limb = { out: number, forward: number }

type AnimatorData = {
	Kid: Kid,
	Home: Vector3, -- point between the feet when standing
	Facing: number, -- 1 = target is to the right (+X), -1 = to the left
	ExtraYaw: number, -- degrees (used to spin the kid around for a look)
	Turntable: boolean,
	State: string, -- Idle, Aim, Win, Fly, Water, Sink, Gone, Drop
	StateTime: number,
	Clock: number,
	Phase: number,
	Overlays: { Overlay },
	Position: Vector3,
	Velocity: Vector3,
	Spin: number,
	FaceOverride: string?,
	FaceOverrideUntil: number,
	NextBlink: number,
	NextRipple: number,
	NextBubble: number,
	OnGone: (() -> ())?,
	Destroyed: boolean,
}

local KidAnimator = {}
KidAnimator.__index = KidAnimator

export type Animator = typeof(setmetatable({} :: AnimatorData, KidAnimator))

export type Options = {
	home: Vector3,
	facing: number?,
}

local active: { [Animator]: boolean } = {}
local loop: RBXScriptConnection? = nil
local random = Random.new()

local STATE_FACES = {
	Idle = "Idle",
	Aim = "Aiming",
	Win = "Win",
	Fly = "Flying",
	Water = "Wet",
	Sink = "Wet",
	Gone = "Wet",
	Drop = "Fire",
}

local function ensureLoop()
	if loop then
		return
	end
	loop = RunService.RenderStepped:Connect(function(dt)
		for animator in active do
			local ok, err = pcall(animator.Update, animator, dt)
			if not ok then
				warn("[KidAnimator] " .. tostring(err))
			end
		end
	end)
end

function KidAnimator.new(kid: Kid, options: Options): Animator
	local self = setmetatable({
		Kid = kid,
		Home = options.home,
		Facing = options.facing or 1,
		ExtraYaw = 0,
		Turntable = false,
		State = "Idle",
		StateTime = 0,
		Clock = 0,
		Phase = random:NextNumber(0, 10),
		Overlays = {},
		Position = options.home,
		Velocity = Vector3.zero,
		Spin = 0,
		FaceOverride = nil,
		FaceOverrideUntil = 0,
		NextBlink = random:NextNumber(Config.Face.BlinkEvery[1], Config.Face.BlinkEvery[2]),
		NextRipple = 0,
		NextBubble = 0,
		OnGone = nil,
		Destroyed = false,
	} :: AnimatorData, KidAnimator)
	active[self] = true
	ensureLoop()
	self:Update(0)
	return self
end

function KidAnimator.Destroy(self: Animator)
	self.Destroyed = true
	active[self] = nil
end

------------------------------------------------------------------------
-- Commands

function KidAnimator._setState(self: Animator, state: string)
	self.State = state
	self.StateTime = 0
	self.FaceOverride = nil
end

function KidAnimator._overlay(self: Animator, kind: string, duration: number, direction: number?)
	for i = #self.Overlays, 1, -1 do
		if self.Overlays[i].kind == kind then
			table.remove(self.Overlays, i)
		end
	end
	table.insert(self.Overlays, { kind = kind, t = 0, duration = duration, direction = direction or 1 })
end

-- Is the kid standing on their spot (not flying or swimming)?
function KidAnimator.IsStanding(self: Animator): boolean
	return self.State == "Idle" or self.State == "Aim" or self.State == "Win"
end

-- Show an expression for a while (or until the next action if no duration).
function KidAnimator.ShowFace(self: Animator, expression: string, duration: number?)
	self.FaceOverride = expression
	self.FaceOverrideUntil = if duration then self.Clock + duration else math.huge
end

function KidAnimator.SetHome(self: Animator, home: Vector3, facing: number?)
	self.Home = home
	if facing then
		self.Facing = facing
	end
end

function KidAnimator.Aim(self: Animator, on: boolean)
	if on and self:IsStanding() then
		self:_setState("Aim")
	elseif not on and self.State == "Aim" then
		self:_setState("Idle")
	end
end

function KidAnimator.Fire(self: Animator)
	if not self:IsStanding() then
		return
	end
	self:_setState("Idle")
	self:_overlay("Fire", Config.Anim.FireTime)
	self:ShowFace("Fire", Config.Anim.FireFaceTime)
end

-- fromSide: 1 if the hit came from the right, -1 from the left.
function KidAnimator.Hit(self: Animator, fromSide: number)
	if not self:IsStanding() then
		return
	end
	if self.State == "Aim" then
		self:_setState("Idle")
	end
	self:_overlay("Hit", Config.Anim.HitTime, fromSide)
	self:ShowFace("Hit", Config.Anim.HitFaceTime)
end

-- Send the kid flying with a velocity (studs per second). They splash into the water.
function KidAnimator.Knock(self: Animator, velocity: Vector3)
	if self.State == "Fly" or self.State == "Water" or self.State == "Sink" or self.State == "Gone" then
		return
	end
	self.Position = self.Home
	self.Velocity = velocity
	self.Spin = 0
	table.clear(self.Overlays)
	self:_setState("Fly")
end

function KidAnimator.Win(self: Animator, on: boolean)
	if on and self:IsStanding() then
		self:_setState("Win")
	elseif not on and self.State == "Win" then
		self:_setState("Idle")
	end
end

-- Drop back onto the home spot from above.
function KidAnimator.DropIn(self: Animator)
	self.Position = self.Home + Vector3.new(0, Config.Anim.DropInHeight, 0)
	self.Velocity = Vector3.zero
	self.Spin = 0
	table.clear(self.Overlays)
	self:_setState("Drop")
end

-- Snap back to standing on the home spot.
function KidAnimator.Reset(self: Animator)
	table.clear(self.Overlays)
	self.Position = self.Home
	self:_setState("Idle")
end

-- Launch speed that makes a kid standing at `from` land in the water at `targetX`.
function KidAnimator.LaunchVelocity(self: Animator, targetX: number, upSpeed: number): Vector3
	local g = Config.World.Gravity
	local pivot = self.Kid.Dims.height * 0.5
	local drop = self.Home.Y - (Config.World.WaterY - pivot)
	local t = (upSpeed + math.sqrt(upSpeed * upSpeed + 2 * g * drop)) / g
	return Vector3.new((targetX - self.Home.X) / t, upSpeed, 0)
end

------------------------------------------------------------------------
-- Per-frame update

function KidAnimator.Update(self: Animator, dt: number)
	if self.Destroyed or not self.Kid.Model.Parent then
		return
	end
	local A = Config.Anim
	local d = self.Kid.Dims
	local s = d.scale
	local facing = self.Facing
	self.Clock += dt
	self.StateTime += dt

	-- Pose pieces we build up this frame.
	local base = self.Home
	local offset = Vector3.zero
	local roll = 0 -- radians, in the screen plane; positive tips the kid's head to the left
	local pivot = 0 -- height of the point we roll around (0 = feet)
	local sx, sy = 1, 1
	local arms: { [string]: Limb } = { R = { out = 0, forward = 0 }, L = { out = 0, forward = 0 } }
	local legs: { [string]: Limb } = { R = { out = 0, forward = 0 }, L = { out = 0, forward = 0 } }
	local headRoll, headNod = 0, 0
	local cape = math.rad(4)

	-- The arm on the target's side throws.
	local front = if facing > 0 then "L" else "R"
	local back = if facing > 0 then "R" else "L"

	local state = self.State
	local t = self.Clock + self.Phase
	local standing = state == "Idle" or state == "Aim" or state == "Win"

	if standing then
		local w = A.IdleBobSpeed
		offset += Vector3.new(0, (1 - math.cos(t * w)) * 0.5 * A.IdleBobHeight * s, 0)
		roll += math.rad(A.IdleSway) * math.sin(t * w * 0.5)
		local breath = math.sin(t * w) * A.BreathSquash
		sy *= 1 + breath
		sx *= 1 - breath * 0.5
		arms.R.out += math.rad(4) * math.sin(t * 1.7)
		arms.L.out += math.rad(4) * math.sin(t * 1.7 + 1.3)
		headRoll += math.rad(3) * math.sin(t * 1.1 + 1)
		cape += math.rad(6) * math.sin(t * 3.1)
	end

	if state == "Aim" then
		local k = math.min(self.StateTime / 0.25, 1)
		roll += facing * math.rad(A.AimLean) * k
		arms[front].out = math.rad(118) * k
		arms[back].out = math.rad(40) * k
		headRoll -= facing * math.rad(6) * k
	elseif state == "Win" then
		local air, ground = A.WinHopTime, 0.22
		local u = self.StateTime % (air + ground)
		if u < air then
			local q = u / air
			offset += Vector3.new(0, 4 * A.WinHopHeight * s * q * (1 - q), 0)
			local stretch = 0.12 * math.abs(1 - 2 * q)
			sy *= 1 + stretch
			sx *= 1 - stretch * 0.6
			legs.R.out, legs.L.out = math.rad(14), math.rad(14)
		else
			local k = math.sin((u - air) / ground * math.pi)
			sy *= 1 - 0.18 * k
			sx *= 1 + 0.12 * k
		end
		arms.R.out = math.rad(122) + math.rad(18) * math.sin(self.StateTime * 14)
		arms.L.out = math.rad(122) + math.rad(18) * math.sin(self.StateTime * 14 + math.pi)
		roll += math.rad(5) * math.sin(self.StateTime * 6)
	elseif state == "Fly" then
		self.Velocity -= Vector3.new(0, Config.World.Gravity * dt, 0)
		self.Position += self.Velocity * dt
		local spinDirection = if self.Velocity.X < 0 then 1 else -1
		self.Spin += math.rad(A.SpinSpeed) * dt * spinDirection
		base = self.Position
		pivot = d.height * 0.5
		roll = self.Spin
		local flail = self.Clock * A.FlailSpeed
		arms.R.out = math.rad(110) + math.rad(45) * math.sin(flail)
		arms.L.out = math.rad(110) + math.rad(45) * math.sin(flail + math.pi)
		legs.R.out = math.rad(20) + math.rad(25) * math.sin(flail * 0.8 + 1)
		legs.L.out = math.rad(20) + math.rad(25) * math.sin(flail * 0.8 + 1 + math.pi)
		legs.R.forward = math.rad(30) * math.sin(flail * 0.7)
		legs.L.forward = -math.rad(30) * math.sin(flail * 0.7)
		cape = math.rad(35) + math.rad(15) * math.sin(flail)
		if self.Position.Y + pivot <= Config.World.WaterY and self.Velocity.Y < 0 then
			Splash.play(self.Position + Vector3.new(0, pivot, 0), math.clamp(s, 0.8, 1.3))
			self:_setState("Water")
			self.NextRipple = self.Clock + 0.6
		end
	elseif state == "Water" or state == "Sink" then
		local floatY = Config.World.WaterY - (d.headCenterY - d.head.Y * 0.38)
		local y = floatY + math.sin(self.StateTime * 3.2) * A.WaterBob * s
		local waving = math.rad(20) * math.sin(self.StateTime * 10)
		arms.R.out = math.rad(128) + waving
		arms.L.out = math.rad(128) - waving
		roll = math.rad(6) * math.sin(self.StateTime * 2.3)
		if state == "Sink" then
			local k = math.min(self.StateTime / A.SinkTime, 1)
			y = floatY - (k * k) * (d.height + 1.5)
			arms.R.out, arms.L.out = math.rad(135), math.rad(135)
			if self.Clock >= self.NextBubble and k < 0.9 then
				self.NextBubble = self.Clock + 0.1
				Splash.bubbles(Vector3.new(self.Position.X, 0, self.Position.Z), 2, s)
			end
			if k >= 1 then
				self:_setState("Gone")
				if self.OnGone then
					task.spawn(self.OnGone)
				end
			end
		else
			if self.Clock >= self.NextRipple then
				self.NextRipple = self.Clock + 0.9
				Splash.ripple(self.Position, s)
			end
			if self.StateTime >= A.WaterFloatTime then
				self:_setState("Sink")
			end
		end
		base = Vector3.new(self.Position.X, y, self.Position.Z)
	elseif state == "Gone" then
		base = Vector3.new(self.Position.X, Config.World.WaterY - 60, self.Position.Z)
	elseif state == "Drop" then
		self.Velocity -= Vector3.new(0, Config.World.Gravity * dt, 0)
		self.Position += self.Velocity * dt
		base = self.Position
		arms.R.out, arms.L.out = math.rad(125), math.rad(125)
		legs.R.out, legs.L.out = math.rad(10), math.rad(10)
		if self.Position.Y <= self.Home.Y then
			self.Position = self.Home
			base = self.Home
			self:_setState("Idle")
			self:_overlay("Land", 0.45)
		end
	end

	-- One-shot overlays on top of the state.
	for i = #self.Overlays, 1, -1 do
		local o = self.Overlays[i]
		o.t += dt
		local p = math.min(o.t / o.duration, 1)
		if o.kind == "Fire" then
			local squash = Curve.keys(p, { { 0, 0 }, { 0.22, -1 }, { 0.4, 0.85 }, { 0.62, -0.2 }, { 0.8, 0.06 }, { 1, 0 } })
				* A.FireSquash
			sy *= 1 + squash
			sx *= 1 - squash * 0.6
			roll += facing
				* math.rad(A.FireLean)
				* Curve.keys(p, { { 0, 0 }, { 0.22, 1 }, { 0.4, -0.7 }, { 0.7, 0.15 }, { 1, 0 } })
			arms[front].out =
				math.rad(Curve.keys(p, { { 0, 118 }, { 0.22, 135 }, { 0.42, 50 }, { 0.75, 32 }, { 1, 0 } }))
			arms[back].out = math.rad(Curve.keys(p, { { 0, 40 }, { 0.42, 70 }, { 1, 0 } }))
			offset += Vector3.new(0, 0.35 * s * Curve.keys(p, { { 0, 0 }, { 0.3, 0 }, { 0.45, 1 }, { 0.65, 0 }, { 1, 0 } }), 0)
		elseif o.kind == "Hit" then
			local away = -o.direction
			local k = Curve.keys(p, { { 0, 0 }, { 0.1, 1 }, { 0.35, -0.4 }, { 0.6, 0.1 }, { 1, 0 } })
			roll += -away
				* math.rad(A.HitLean)
				* Curve.keys(p, { { 0, 0 }, { 0.12, 1 }, { 0.4, -0.3 }, { 0.7, 0.1 }, { 1, 0 } })
			offset += Vector3.new(
				away * 0.45 * s * Curve.keys(p, { { 0, 0 }, { 0.2, 1 }, { 0.6, 0.6 }, { 1, 0 } })
					+ math.sin(p * 60) * 0.06 * (1 - p),
				A.HitHop * s * Curve.keys(p, { { 0, 0 }, { 0.18, 1 }, { 0.38, 0 }, { 1, 0 } }),
				0
			)
			sx *= 1 - 0.15 * k
			sy *= 1 + 0.12 * k
			local fling = math.rad(70) * Curve.keys(p, { { 0, 0 }, { 0.15, 1 }, { 0.6, 0.3 }, { 1, 0 } })
			arms.R.out += fling
			arms.L.out += fling
			headNod -= math.rad(15) * k
		elseif o.kind == "Land" then
			local k = Curve.keys(p, { { 0, 0 }, { 0.15, 1 }, { 0.45, -0.35 }, { 0.7, 0.1 }, { 1, 0 } })
			sy *= 1 - A.LandSquash * k
			sx *= 1 + A.LandSquash * 0.7 * k
		end
		if p >= 1 then
			table.remove(self.Overlays, i)
		end
	end

	-- Face: an override (from an action or a button) wins over the state's face.
	local face = self.Kid.Face
	if self.FaceOverride and self.Clock > self.FaceOverrideUntil then
		self.FaceOverride = nil
	end
	local wanted = self.FaceOverride or STATE_FACES[state] or "Idle"
	if face.Expression ~= wanted then
		face:SetExpression(wanted)
	end
	if self.Clock >= self.NextBlink then
		self.NextBlink = self.Clock + random:NextNumber(Config.Face.BlinkEvery[1], Config.Face.BlinkEvery[2])
		face:Blink()
	end
	face:Update(dt)

	if self.Turntable then
		self.ExtraYaw = (self.ExtraYaw + 45 * dt) % 360
	end

	-- Hand everything to the rig. Kids keep their face toward the camera,
	-- turned a little toward their target.
	local camera = workspace.CurrentCamera
	local toCamera = if camera then camera.CFrame.Position - base else Vector3.zAxis
	local flat = Vector3.new(toCamera.X, 0, toCamera.Z)
	local cameraYaw = if flat.Magnitude > 1e-3 then math.atan2(-flat.X, -flat.Z) else math.pi
	local yaw = cameraYaw + facing * math.rad(Config.Kid.FacingAngle) + math.rad(self.ExtraYaw)
	local rootCF = CFrame.new(base + offset + Vector3.new(0, pivot, 0))
		* CFrame.Angles(0, 0, roll)
		* CFrame.new(0, -pivot, 0)
		* CFrame.Angles(0, yaw, 0)
	KidRig.apply(self.Kid.Rig, {
		root = rootCF,
		squash = Vector2.new(sx, sy),
		bones = {
			ArmR = CFrame.Angles(arms.R.forward, 0, arms.R.out),
			ArmL = CFrame.Angles(arms.L.forward, 0, -arms.L.out),
			LegR = CFrame.Angles(legs.R.forward, 0, legs.R.out),
			LegL = CFrame.Angles(legs.L.forward, 0, -legs.L.out),
			Head = CFrame.Angles(headNod, 0, headRoll),
			Cape = CFrame.Angles(-cape, 0, 0),
		},
	})
end

return KidAnimator
