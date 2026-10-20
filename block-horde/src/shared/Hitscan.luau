--!strict
-- Hitscan math on the flat XZ plane: bullets are rays, enemies are circles.
-- Shared so the server (which applies damage) and the shooter's client (which
-- draws the tracer instantly) get the same answer.

local Hitscan = {}

-- Casts a ray from (ox, oz) along the unit direction (dx, dz), up to maxDist.
-- circleOf(target) returns the target's x, z and radius.
-- Returns the targets hit in order (at most `pierce` of them), how far the
-- bullet traveled before stopping, and the distance to each hit.
function Hitscan.cast<T>(
	ox: number,
	oz: number,
	dx: number,
	dz: number,
	maxDist: number,
	targets: { T },
	circleOf: (T) -> (number, number, number),
	pierce: number
): ({ T }, number, { number })
	local candidates: { { target: T, dist: number } } = {}
	for _, target in targets do
		local cx, cz, radius = circleOf(target)
		local fx, fz = cx - ox, cz - oz
		local along = fx * dx + fz * dz
		local distSq = fx * fx + fz * fz
		local perpSq = distSq - along * along
		local radiusSq = radius * radius
		if perpSq > radiusSq then
			continue
		end
		local enter
		if distSq <= radiusSq then
			enter = 0 -- the ray starts inside this target
		elseif along < 0 then
			continue -- behind the shooter
		else
			enter = along - math.sqrt(radiusSq - perpSq)
		end
		if enter <= maxDist then
			table.insert(candidates, { target = target, dist = enter })
		end
	end

	table.sort(candidates, function(a, b)
		return a.dist < b.dist
	end)

	local hits: { T } = {}
	local dists: { number } = {}
	local travel = maxDist
	for i, candidate in candidates do
		if i > pierce then
			break
		end
		table.insert(hits, candidate.target)
		table.insert(dists, candidate.dist)
		if i == pierce then
			travel = candidate.dist
		end
	end
	return hits, travel, dists
end

return Hitscan
