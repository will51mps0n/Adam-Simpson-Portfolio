--!strict
-- Named colors used by outfits and characters.
-- Outfit data refers to colors by these names (e.g. "Coral"), so you can
-- retune a color here and every kid using it updates.

local Palette = {}

Palette.Skin = {
	Peach = Color3.fromRGB(255, 214, 186),
	Rosy = Color3.fromRGB(250, 196, 170),
	Honey = Color3.fromRGB(232, 178, 128),
	Caramel = Color3.fromRGB(196, 138, 92),
	Cocoa = Color3.fromRGB(150, 100, 68),
	Espresso = Color3.fromRGB(112, 74, 52),
}

Palette.Hair = {
	Chestnut = Color3.fromRGB(122, 74, 44),
	Ginger = Color3.fromRGB(226, 112, 46),
	Blond = Color3.fromRGB(250, 206, 96),
	Ink = Color3.fromRGB(46, 40, 52),
	Mocha = Color3.fromRGB(86, 56, 40),
	Bubblegum = Color3.fromRGB(255, 130, 186),
	Lilac = Color3.fromRGB(170, 132, 236),
	Seafoam = Color3.fromRGB(96, 214, 182),
}

-- Clothes, hats, rafts and anything else.
Palette.Cloth = {
	White = Color3.fromRGB(250, 250, 248),
	Cream = Color3.fromRGB(246, 234, 204),
	Charcoal = Color3.fromRGB(52, 50, 62),
	Navy = Color3.fromRGB(38, 62, 140),
	Royal = Color3.fromRGB(52, 108, 230),
	Sky = Color3.fromRGB(118, 196, 255),
	Aqua = Color3.fromRGB(64, 214, 222),
	Mint = Color3.fromRGB(132, 232, 170),
	Grass = Color3.fromRGB(86, 192, 86),
	Leaf = Color3.fromRGB(46, 140, 82),
	Sunny = Color3.fromRGB(255, 214, 58),
	Gold = Color3.fromRGB(255, 186, 36),
	Tangerine = Color3.fromRGB(255, 140, 40),
	Coral = Color3.fromRGB(255, 106, 96),
	Red = Color3.fromRGB(230, 54, 60),
	Cherry = Color3.fromRGB(196, 30, 58),
	Pink = Color3.fromRGB(255, 150, 196),
	Lavender = Color3.fromRGB(176, 146, 240),
	Grape = Color3.fromRGB(122, 74, 196),
	Brown = Color3.fromRGB(128, 82, 52),
	Tan = Color3.fromRGB(214, 170, 114),
	Steel = Color3.fromRGB(168, 178, 192),
	Horn = Color3.fromRGB(246, 236, 206),
	Glass = Color3.fromRGB(120, 220, 255),
}

-- Face drawing colors.
Palette.Face = {
	Eye = Color3.fromRGB(38, 30, 52),
	Shine = Color3.fromRGB(255, 255, 255),
	Brow = Color3.fromRGB(58, 40, 40),
	Blush = Color3.fromRGB(255, 120, 150),
	MouthLine = Color3.fromRGB(70, 34, 40),
	MouthInside = Color3.fromRGB(120, 30, 46),
	Tongue = Color3.fromRGB(255, 120, 136),
	Teeth = Color3.fromRGB(255, 255, 255),
	Tear = Color3.fromRGB(130, 210, 255),
}

-- Every color name must be unique across the tables above.
do
	local seen = {}
	local groups: { { [string]: Color3 } } = { Palette.Skin, Palette.Hair, Palette.Cloth, Palette.Face }
	for _, group in groups do
		for name in group do
			if seen[name] then
				warn(`[Palette] Color name "{name}" is used twice; rename one of them`)
			end
			seen[name] = true
		end
	end
end

-- Look up a color by name in any of the tables above, or pass a Color3 through.
function Palette.resolve(value: string | Color3 | nil, fallback: Color3?): Color3
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		local found = Palette.Cloth[value] or Palette.Hair[value] or Palette.Skin[value] or Palette.Face[value]
		if found then
			return found
		end
		warn(`[Palette] Unknown color name "{value}"`)
	end
	return fallback or Color3.fromRGB(255, 0, 255)
end

return Palette
