--!strict
-- Finding which ninja an enemy goes after: always the nearest living one it can see.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Collision = require(Shared.Sim.Collision)
local Types = require(script.Parent.Types)

local T = Config.TILE_PX

local Targeting = {}

function Targeting.nearestVisible(ctx: Types.Ctx, x: number, y: number): Types.NinjaInfo?
	local range2 = Config.SIGHT_RANGE_PX ^ 2
	local candidates: { { ninja: Types.NinjaInfo, d: number } } = {}
	for _, n in ctx.ninjas do
		local d = (n.x - x) ^ 2 + (n.y - y) ^ 2
		if d < range2 then
			table.insert(candidates, { ninja = n, d = d })
		end
	end
	table.sort(candidates, function(a, b)
		return a.d < b.d
	end)
	for _, c in candidates do
		if Collision.lineOfSight(ctx.grid, x, y, c.ninja.x, c.ninja.y) then
			return c.ninja
		end
	end
	return nil
end

function Targeting.nearest(ctx: Types.Ctx, x: number, y: number): Types.NinjaInfo?
	local best, bestD = nil, math.huge
	for _, n in ctx.ninjas do
		local d = (n.x - x) ^ 2 + (n.y - y) ^ 2
		if d < bestD then
			best, bestD = n, d
		end
	end
	return best
end

-- The nearest visible ninja lined up with (x, y) in the same row or column (within half a
-- tile), and the grid direction toward it.
function Targeting.inLine(ctx: Types.Ctx, x: number, y: number): (Types.NinjaInfo?, number, number)
	local best, bestD, bdx, bdy = nil, math.huge, 0, 0
	for _, n in ctx.ninjas do
		local ox, oy = n.x - x, n.y - y
		local dx, dy, d = 0, 0, math.huge
		if math.abs(oy) < T / 2 then
			dx, d = if ox > 0 then 1 else -1, math.abs(ox)
		elseif math.abs(ox) < T / 2 then
			dy, d = if oy > 0 then 1 else -1, math.abs(oy)
		end
		if d < bestD and d < Config.SIGHT_RANGE_PX and Collision.lineOfSight(ctx.grid, x, y, n.x, n.y) then
			best, bestD, bdx, bdy = n, d, dx, dy
		end
	end
	return best, bdx, bdy
end

function Targeting.angleTo(x: number, y: number, n: Types.NinjaInfo): number
	return math.atan2(n.y - y, n.x - x)
end

return Targeting
