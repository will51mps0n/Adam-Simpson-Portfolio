-- Minimal stand-ins for the Roblox globals the simulated server modules use.
local clock = 0

local function noop() end

local service = setmetatable({}, {
	__index = function()
		return noop
	end,
})

local Random = {}
Random.__index = Random
function Random.new(seed: number?)
	return setmetatable({ seed = seed }, Random)
end
function Random.NextNumber(_self: any, low: number?, high: number?): number
	local a, b = low or 0, high or 1
	return a + math.random() * (b - a)
end
function Random.NextInteger(_self: any, low: number, high: number): number
	return math.random(low, high)
end

return {
	game = {
		GetService = function()
			return service
		end,
	},
	workspace = {
		GetServerTimeNow = function()
			return clock
		end,
	},
	Random = Random,
	Color3 = {
		fromRGB = function(r: number, g: number, b: number)
			return { r, g, b }
		end,
		new = function(r: number, g: number, b: number)
			return { r, g, b }
		end,
	},
	setClock = function(t: number)
		clock = t
	end,
}
