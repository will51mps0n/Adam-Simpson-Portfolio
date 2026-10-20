--!strict
-- Geometry for things that sit on the head (hair, hats, goggles).
-- All positions are in "head space": the head's center is the origin,
-- +Y is up and the face looks toward -Z.

local HeadShape = {}

-- A hair cap is a slightly bigger copy of the head, nudged up and back so
-- that it only covers the top. Where it pokes out of the head is the hairline.
export type Cap = {
	center: Vector3, -- studs, head space
	size: Vector3, -- studs
	normal: Vector3, -- hairline plane (in "unit head" space)
	offset: number,
	puff: number,
}

-- radii: half the head size.
-- front/back: hairline height at the forehead and at the back of the head,
--   from -1 (bottom of the head) to 1 (top).
-- puff: how much bigger than the head the cap is (1.05 = thin, 1.15 = fluffy).
function HeadShape.cap(radii: Vector3, front: number, back: number, puff: number): Cap
	local sf, sb = math.sqrt(1 - front * front), math.sqrt(1 - back * back)
	local theta = math.atan2(front - back, sf + sb)
	local c, s = math.cos(theta), math.sin(theta)
	local offset = front * c - sf * s
	local distance = offset + math.sqrt(offset * offset + puff * puff - 1)
	local center = Vector3.new(0, distance * c, distance * s)
	return {
		center = center * radii,
		size = radii * 2 * puff,
		normal = Vector3.new(0, c, s),
		offset = offset,
		puff = puff,
	}
end

-- Point on the head's surface in a direction, pushed out by `lift` (1 = on the skin).
function HeadShape.surface(radii: Vector3, direction: Vector3, lift: number?): Vector3
	local d = direction.Unit
	return Vector3.new(d.X * radii.X, d.Y * radii.Y, d.Z * radii.Z) * (lift or 1)
end

-- Outward normal of the head's surface at a point.
function HeadShape.normal(radii: Vector3, point: Vector3): Vector3
	return Vector3.new(
		point.X / (radii.X * radii.X),
		point.Y / (radii.Y * radii.Y),
		point.Z / (radii.Z * radii.Z)
	).Unit
end

-- Is this direction (from the head's center) covered by the cap?
function HeadShape.underCap(cap: Cap, direction: Vector3, margin: number?): boolean
	return direction.Unit:Dot(cap.normal) >= cap.offset + (margin or 0)
end

-- Point on the cap's surface, going out from the cap's own center.
function HeadShape.onCap(cap: Cap, direction: Vector3, lift: number?): Vector3
	local d = direction.Unit
	local r = cap.size / 2
	return cap.center + Vector3.new(d.X * r.X, d.Y * r.Y, d.Z * r.Z) * (lift or 1)
end

return HeadShape
