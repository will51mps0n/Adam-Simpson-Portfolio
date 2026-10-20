--!strict
-- Draws the level's objects and runs the ones that live on this client:
-- gold, the exit switch and door, doors and their switches, launch pads, bounce blocks
-- and one-way platforms.
--
-- Gold and switches belong to the server. When our ninja touches one we show it taken
-- (or pressed) straight away and tell the server; the server's answer arrives a moment
-- later. Normal doors, bounce blocks and launch pads are simulated right here so they
-- react to our ninja with no delay.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local LevelBuilder = require(Shared.LevelBuilder)
local LevelObjects = require(Shared.Sim.LevelObjects)
local Collision = require(Shared.Sim.Collision)

local C = Config.COLORS
local R = Config.NINJA_RADIUS
local Z = 0.02 -- objects sit just in front of the level's blocks
local LAUNCH_COOLDOWN_FRAMES = 15

type Box = { x0: number, y0: number, x1: number, y1: number }

type Gold = { id: number, box: Box, parts: { Part } }
type ExitSwitch = { id: number, group: any, box: Box, light: Part }
type ExitDoor = { id: number, group: any, box: Box, panel: Part }
type Door = {
	id: number,
	kind: string,
	cx: number,
	cy: number,
	solid: Collision.Solid,
	part: Part,
	switchBox: Box?,
	switchLight: Part?,
	open: boolean,
}
type Pad = { id: number, x: number, y: number, dx: number, dy: number, cooldown: number }
type BounceBlock = {
	homeX: number,
	homeY: number,
	ox: number,
	oy: number,
	vx: number,
	vy: number,
	solid: Collision.Solid,
	parts: { Part },
	onHit: (any, number, number, number, number) -> number,
}

export type Touch = {
	kind: string, -- "gold", "switch", "exit", "launch"
	id: number,
	dx: number?,
	dy: number?,
}

export type ObjectsView = {
	model: Model,
	frontZ: number,
	golds: { Gold },
	exitSwitches: { ExitSwitch },
	exitDoors: { ExitDoor },
	doors: { Door },
	pads: { Pad },
	bounceBlocks: { BounceBlock },
	oneWays: { Collision.Solid },
	goldTaken: { [number]: boolean },
	pressed: { [number]: boolean },
}

local ObjectsView = {}

local function flat(parent: Instance, x0: number, y0: number, x1: number, y1: number, color: Color3, z: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = Vector3.new(Units.studs(x1 - x0), Units.studs(y1 - y0), 0.1)
	part.CFrame = CFrame.new(Units.toWorld((x0 + x1) / 2, (y0 + y1) / 2, z))
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function inset(box: Box, by: number): (number, number, number, number)
	return box.x0 + by, box.y0 + by, box.x1 - by, box.y1 - by
end

local function makeBox(x0: number, y0: number, x1: number, y1: number): Box
	return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

local function touches(x: number, y: number, box: Box): boolean
	return LevelObjects.circleTouchesBox(x, y, R, box.x0, box.y0, box.x1, box.y1)
end

-- A bounce block takes half of each hit and springs back (see NinjaSim's resolve).
local function bounceHit(b: any, nx: number, ny: number, into: number, _push: number): number
	b.vx += nx * into * 0.5
	b.vy += ny * into * 0.5
	return into * 0.5
end

function ObjectsView.new(built: LevelBuilder.BuiltLevel): ObjectsView
	local model = Instance.new("Model")
	model.Name = "Objects"
	local z = built.frontZ + Z
	local view: ObjectsView = {
		model = model,
		frontZ = built.frontZ,
		golds = {},
		exitSwitches = {},
		exitDoors = {},
		doors = {},
		pads = {},
		bounceBlocks = {},
		oneWays = {},
		goldTaken = {},
		pressed = {},
	}

	for id, obj in built.def.objects do
		local kind = obj.type
		if kind == "gold" then
			local box = makeBox(LevelObjects.goldBox(obj))
			local edge = flat(model, box.x0, box.y0, box.x1, box.y1, C.GOLD_EDGE, z)
			local fill = flat(model, box.x0 + 1, box.y0 + 1, box.x1 - 1, box.y1 - 1, C.GOLD, z + 0.02)
			table.insert(view.golds, { id = id, box = box, parts = { edge, fill } })
		elseif kind == "exitSwitch" then
			local box = makeBox(LevelObjects.exitSwitchBox(obj))
			flat(model, box.x0, box.y0, box.x1, box.y1, C.SWITCH_BASE, z)
			local light = flat(model, box.x0 + 2, box.y0 + 2, box.x1 - 2, box.y1 - 2, C.EXIT_SWITCH, z + 0.02)
			table.insert(view.exitSwitches, { id = id, group = LevelObjects.group(obj), box = box, light = light })
		elseif kind == "exitDoor" then
			local box = makeBox(LevelObjects.exitDoorBox(obj))
			flat(model, box.x0, box.y0, box.x1, box.y1, C.EXIT_DOOR, z)
			local panel = flat(model, box.x0 + 2, box.y0 + 2, box.x1 - 2, box.y1, C.EXIT_DOOR:Lerp(Color3.new(1, 1, 1), 0.12), z + 0.02)
			table.insert(view.exitDoors, { id = id, group = LevelObjects.group(obj), box = box, panel = panel })
		elseif LevelObjects.isDoor(obj) then
			local x0, y0, x1, y1 = LevelObjects.doorBox(obj)
			local color = if kind == "lockedDoor" then C.LOCKED_DOOR elseif kind == "trapDoor" then C.TRAP_DOOR else C.DOOR
			local door: Door = {
				id = id,
				kind = kind,
				cx = (x0 + x1) / 2,
				cy = (y0 + y1) / 2,
				solid = { x0 = x0, y0 = y0, x1 = x1, y1 = y1, tag = "door" },
				part = flat(model, x0, y0, x1, y1, color, z),
				open = kind == "trapDoor",
			}
			local sx, sy = LevelObjects.doorSwitchCenter(obj)
			if sx and sy and kind ~= "door" then
				local switchBox = makeBox(LevelObjects.switchBoxAt(sx, sy))
				flat(model, switchBox.x0, switchBox.y0, switchBox.x1, switchBox.y1, C.SWITCH_BASE, z)
				door.switchBox = switchBox
				local lx0, ly0, lx1, ly1 = inset(switchBox, 2)
				door.switchLight = flat(model, lx0, ly0, lx1, ly1, color, z + 0.02)
			end
			table.insert(view.doors, door)
		elseif kind == "launchPad" then
			local x, y, dx, dy = LevelObjects.launchPad(obj)
			table.insert(view.pads, { id = id, x = x, y = y, dx = dx, dy = dy, cooldown = 0 })
			-- A plate against the wall plus a shorter bar in front of it, pointing the way.
			local function bar(along: number, halfWidth: number, thick: number)
				local px, py = -dy, dx
				local cx, cy = x + dx * along, y + dy * along
				local part = flat(model, 0, 0, halfWidth * 2, thick, C.LAUNCH_PAD, z)
				local center = Units.toWorld(cx, cy, z)
				local xAxis = Vector3.new(px, -py, 0)
				part.CFrame = CFrame.fromMatrix(center, xAxis, Vector3.zAxis:Cross(xAxis))
			end
			bar(0, 8, 3)
			bar(3.5, 4, 2)
		elseif kind == "bounceBlock" then
			local x0, y0, x1, y1 = LevelObjects.bounceBlockBox(obj)
			local block: BounceBlock = {
				homeX = (x0 + x1) / 2,
				homeY = (y0 + y1) / 2,
				ox = 0,
				oy = 0,
				vx = 0,
				vy = 0,
				solid = { x0 = x0, y0 = y0, x1 = x1, y1 = y1, vx = 0, vy = 0 },
				parts = {
					flat(model, x0, y0, x1, y1, C.BOUNCE_BLOCK_EDGE, z),
					flat(model, x0 + 2, y0 + 2, x1 - 2, y1 - 2, C.BOUNCE_BLOCK, z + 0.02),
				},
				onHit = bounceHit,
			}
			block.solid.tag = block
			table.insert(view.bounceBlocks, block)
		elseif kind == "oneWay" then
			local x0, y0, x1, y1, nx, ny = LevelObjects.oneWay(obj)
			table.insert(view.oneWays, { x0 = x0, y0 = y0, x1 = x1, y1 = y1, oneWayNx = nx, oneWayNy = ny, tag = "oneWay" })
			flat(model, x0, y0, x1, y1, C.ONE_WAY, z)
			-- A darker line along the solid face.
			local fx0 = if nx > 0 then x1 - 1 else x0
			local fx1 = if nx < 0 then x0 + 1 else x1
			local fy0 = if ny > 0 then y1 - 1 else y0
			local fy1 = if ny < 0 then y0 + 1 else y1
			flat(model, fx0, fy0, fx1, fy1, C.TILE, z + 0.02)
		end
	end
	model.Parent = built.model
	ObjectsView.render(view)
	return view
end

-- Back to how the level starts, then mark what the server says is already taken / pressed.
function ObjectsView.reset(view: ObjectsView, goldTaken: { number }?, pressed: { number }?)
	table.clear(view.goldTaken)
	table.clear(view.pressed)
	if goldTaken then
		for _, id in goldTaken do
			view.goldTaken[id] = true
		end
	end
	if pressed then
		for _, id in pressed do
			view.pressed[id] = true
		end
	end
	for _, b in view.bounceBlocks do
		b.ox, b.oy, b.vx, b.vy = 0, 0, 0, 0
	end
	for _, p in view.pads do
		p.cooldown = 0
	end
	ObjectsView.render(view)
end

function ObjectsView.isExitOpen(view: ObjectsView, group: any): boolean
	for _, sw in view.exitSwitches do
		if sw.group == group and view.pressed[sw.id] then
			return true
		end
	end
	return false
end

-- Adds every solid object to `out` (closed doors, one-way platforms, bounce blocks).
function ObjectsView.solids(view: ObjectsView, out: { Collision.Solid })
	for _, d in view.doors do
		if not d.open then
			table.insert(out, d.solid)
		end
	end
	for _, s in view.oneWays do
		table.insert(out, s)
	end
	for _, b in view.bounceBlocks do
		table.insert(out, b.solid)
	end
end

-- One frame: doors react to nearby ninjas, bounce blocks spring back, pads reload.
-- `ninjas` holds the centers of every ninja this client knows about.
function ObjectsView.step(view: ObjectsView, ninjas: { { x: number, y: number } })
	for _, d in view.doors do
		if d.kind == "door" then
			local near = false
			for _, n in ninjas do
				if (n.x - d.cx) ^ 2 + (n.y - d.cy) ^ 2 < Config.DOOR_OPEN_DISTANCE_PX ^ 2 then
					near = true
					break
				end
			end
			d.open = near
		elseif d.kind == "lockedDoor" then
			d.open = view.pressed[d.id] == true
		else
			d.open = not view.pressed[d.id]
		end
	end

	local half = Config.BOUNCE_BLOCK_SIZE_PX / 2
	local maxSquash = Config.BOUNCE_MAX_SQUASH_PX
	for _, b in view.bounceBlocks do
		b.vx = (b.vx - b.ox * Config.BOUNCE_STIFFNESS) * Config.BOUNCE_DAMPING
		b.vy = (b.vy - b.oy * Config.BOUNCE_STIFFNESS) * Config.BOUNCE_DAMPING
		b.ox += b.vx
		b.oy += b.vy
		if math.abs(b.ox) > maxSquash then
			b.ox, b.vx = math.clamp(b.ox, -maxSquash, maxSquash), 0
		end
		if math.abs(b.oy) > maxSquash then
			b.oy, b.vy = math.clamp(b.oy, -maxSquash, maxSquash), 0
		end
		local s = b.solid
		s.x0, s.y0 = b.homeX + b.ox - half, b.homeY + b.oy - half
		s.x1, s.y1 = b.homeX + b.ox + half, b.homeY + b.oy + half
		s.vx, s.vy = b.vx, b.vy
	end

	for _, p in view.pads do
		if p.cooldown > 0 then
			p.cooldown -= 1
		end
	end
end

-- What our ninja (center x, y) is touching this frame. Gold and switches are marked
-- taken / pressed locally right away.
function ObjectsView.touch(view: ObjectsView, x: number, y: number): { Touch }
	local result: { Touch } = {}
	for _, g in view.golds do
		if not view.goldTaken[g.id] and touches(x, y, g.box) then
			view.goldTaken[g.id] = true
			table.insert(result, { kind = "gold", id = g.id })
		end
	end
	for _, sw in view.exitSwitches do
		if not view.pressed[sw.id] and touches(x, y, sw.box) then
			view.pressed[sw.id] = true
			table.insert(result, { kind = "switch", id = sw.id })
		end
	end
	for _, d in view.doors do
		local box = d.switchBox
		if box and not view.pressed[d.id] and touches(x, y, box) then
			view.pressed[d.id] = true
			table.insert(result, { kind = "switch", id = d.id })
		end
	end
	for _, door in view.exitDoors do
		if ObjectsView.isExitOpen(view, door.group) and touches(x, y, door.box) then
			table.insert(result, { kind = "exit", id = door.id })
		end
	end
	for _, p in view.pads do
		if p.cooldown <= 0 then
			local ox, oy = x - p.x, y - p.y
			local ahead = ox * p.dx + oy * p.dy
			local side = math.abs(ox * -p.dy + oy * p.dx)
			if ahead > -2 and ahead < R + Config.LAUNCH_PAD_REACH_PX and side < R then
				p.cooldown = LAUNCH_COOLDOWN_FRAMES
				table.insert(result, { kind = "launch", id = p.id, dx = p.dx, dy = p.dy })
			end
		end
	end
	return result
end

local function setVisible(part: BasePart, transparency: number)
	if part.Transparency ~= transparency then
		part.Transparency = transparency
	end
end

-- Brings the parts up to date with the state.
function ObjectsView.render(view: ObjectsView)
	for _, g in view.golds do
		for _, part in g.parts do
			setVisible(part, if view.goldTaken[g.id] then 1 else 0)
		end
	end
	for _, sw in view.exitSwitches do
		sw.light.Color = if view.pressed[sw.id] then C.EXIT_SWITCH_ON else C.EXIT_SWITCH
	end
	for _, door in view.exitDoors do
		door.panel.Color = if ObjectsView.isExitOpen(view, door.group)
			then C.EXIT_DOOR_OPEN
			else C.EXIT_DOOR:Lerp(Color3.new(1, 1, 1), 0.12)
	end
	for _, d in view.doors do
		local openLook = if d.kind == "trapDoor" then 0.75 else 0.85
		setVisible(d.part, if d.open then openLook else 0)
		local light = d.switchLight
		if light then
			setVisible(light, if view.pressed[d.id] then 0.7 else 0)
		end
	end
	local z = view.frontZ + Z
	for _, b in view.bounceBlocks do
		local center = Units.toWorld(b.homeX + b.ox, b.homeY + b.oy, z)
		b.parts[1].CFrame = CFrame.new(center)
		b.parts[2].CFrame = CFrame.new(center + Vector3.new(0, 0, 0.02))
	end
end

return ObjectsView
