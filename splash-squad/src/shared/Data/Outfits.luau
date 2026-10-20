--!strict
-- The wardrobe: every hair style, hat, top, bottom, shoe and accessory a kid can wear.
-- To add a new color option, add it to Palette and list it here.
-- To add a new hair style or hat, add an entry here and a matching builder
-- in Character/Hair.luau or Character/Hats.luau.

local Outfits = {}

export type ColorRef = string | Color3

export type Piece = {
	style: string,
	color: ColorRef?,
	accent: ColorRef?,
}

export type Outfit = {
	skin: ColorRef,
	hair: Piece,
	hat: Piece?,
	top: Piece,
	bottom: Piece,
	shoes: Piece,
	cape: Piece?, -- style is ignored, color = cape, accent = knot
	goggles: Piece?, -- color = lenses, accent = strap
	lifeRing: Piece?, -- color = ring, accent = stripes
	mask: ColorRef?, -- superhero eye mask drawn on the face
	emblem: { letter: string, color: ColorRef?, ink: ColorRef? }?,
	proportions: {
		scale: number?, -- overall size (1 = normal)
		bodyStretch: number?, -- taller body and legs
		headScale: number?,
	}?,
}

export type CatalogItem = {
	id: string,
	name: string,
	price: number,
	color: ColorRef?,
	accent: ColorRef?,
}

Outfits.HairStyles = {
	{ id = "Spiky", name = "Spiky", price = 0 },
	{ id = "BowlCut", name = "Bowl Cut", price = 0 },
	{ id = "Ponytail", name = "Ponytail", price = 40 },
	{ id = "Curly", name = "Curly", price = 40 },
} :: { CatalogItem }

Outfits.Hats = {
	{ id = "None", name = "No Hat", price = 0 },
	{ id = "Tricorn", name = "Pirate Hat", price = 150, color = "Charcoal", accent = "Gold" },
	{ id = "VikingHorns", name = "Viking Helmet", price = 200, color = "Steel", accent = "Gold" },
	{ id = "Cap", name = "Sporty Cap", price = 80, color = "Royal", accent = "White" },
	{ id = "Crown", name = "Tiny Crown", price = 300, color = "Gold", accent = "Red" },
	{ id = "Flower", name = "Hair Flower", price = 60, color = "Pink", accent = "Sunny" },
} :: { CatalogItem }

Outfits.Tops = {
	{ id = "None", name = "No Shirt", price = 0 },
	{ id = "Tee", name = "T-Shirt", price = 0 },
	{ id = "Stripes", name = "Sailor Stripes", price = 60, accent = "Red" },
	{ id = "Suit", name = "Hero Suit", price = 250, accent = "Sunny" },
} :: { CatalogItem }

Outfits.Bottoms = {
	{ id = "Trunks", name = "Swim Trunks", price = 0, accent = "White" },
	{ id = "Shorts", name = "Shorts", price = 0 },
	{ id = "Pants", name = "Long Pants", price = 40 },
} :: { CatalogItem }

Outfits.Shoes = {
	{ id = "Bare", name = "Bare Feet", price = 0 },
	{ id = "Sneakers", name = "Sneakers", price = 50, accent = "White" },
	{ id = "Boots", name = "Boots", price = 80 },
} :: { CatalogItem }

Outfits.Accessories = {
	{ id = "Cape", name = "Towel Cape", price = 200, color = "Red", accent = "Sunny" },
	{ id = "Goggles", name = "Swim Goggles", price = 70, color = "Glass", accent = "Aqua" },
	{ id = "LifeRing", name = "Life Ring", price = 90, color = "Red", accent = "White" },
	{ id = "Mask", name = "Hero Mask", price = 120, color = "Red" },
} :: { CatalogItem }

-- Color choices offered in the wardrobe.
Outfits.SkinTones = { "Peach", "Rosy", "Honey", "Caramel", "Cocoa", "Espresso" }
Outfits.HairColors = { "Chestnut", "Ginger", "Blond", "Ink", "Mocha", "Bubblegum", "Lilac", "Seafoam" }
Outfits.ClothColors = {
	"White",
	"Navy",
	"Royal",
	"Sky",
	"Aqua",
	"Mint",
	"Grass",
	"Sunny",
	"Tangerine",
	"Coral",
	"Red",
	"Pink",
	"Lavender",
	"Grape",
	"Brown",
	"Charcoal",
}

function Outfits.find(list: { CatalogItem }, id: string): CatalogItem?
	for _, item in list do
		if item.id == id then
			return item
		end
	end
	return nil
end

-- Deep copy, so editing one kid's outfit never changes another's.
function Outfits.copy(outfit: Outfit): Outfit
	local function deep(value: any): any
		if type(value) ~= "table" then
			return value
		end
		local out = {}
		for k, v in value do
			out[k] = deep(v)
		end
		return out
	end
	return deep(outfit)
end

return Outfits
