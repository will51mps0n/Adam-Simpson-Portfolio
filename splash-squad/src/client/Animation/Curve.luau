--!strict
-- Tiny keyframe curves for hand-made animation.
-- Curve.keys(0.3, { {0, 0}, {0.25, 1}, {1, 0} }) eases between the keys.

local Curve = {}

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

function Curve.keys(p: number, keys: { { number } }): number
	if p <= keys[1][1] then
		return keys[1][2]
	end
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if p <= b[1] then
			local t = (p - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * smooth(t)
		end
	end
	return keys[#keys][2]
end

function Curve.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

return Curve
