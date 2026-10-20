--!strict
-- The kids. Each one is just an outfit (see Data/Outfits.luau), so you can
-- restyle anyone by editing this table.

local Outfits = require(script.Parent.Outfits)

export type Character = {
	id: string,
	name: string,
	blurb: string,
	outfit: Outfits.Outfit,
}

local Characters = {}

-- The two hero kids for solo play.
Characters.Heroes = {
	{
		id = "Pip",
		name = "Pip",
		blurb = "Small, brave, and always in swim trunks.",
		outfit = {
			skin = "Peach",
			hair = { style = "Spiky", color = "Chestnut" },
			top = { style = "None" },
			bottom = { style = "Trunks", color = "Coral", accent = "White" },
			shoes = { style = "Bare" },
			goggles = { style = "Goggles", color = "Glass", accent = "Aqua" },
			proportions = { scale = 0.9 },
		},
	},
	{
		id = "Max",
		name = "Captain Max",
		blurb = "Pip's big sibling, in a homemade superhero costume.",
		outfit = {
			skin = "Peach",
			hair = { style = "BowlCut", color = "Chestnut" },
			top = { style = "Suit", color = "Royal", accent = "Sunny" },
			bottom = { style = "Trunks", color = "Red", accent = "Red" },
			shoes = { style = "Boots", color = "Red" },
			cape = { style = "Cape", color = "Red", accent = "Sunny" },
			mask = "Red",
			emblem = { letter = "M", color = "Sunny", ink = "Red" },
			proportions = { scale = 1.06, bodyStretch = 1.2, headScale = 0.96 },
		},
	},
} :: { Character }

-- Extra kids that show off the outfit system on the test stage.
Characters.Extras = {
	{
		id = "Polly",
		name = "Polly",
		blurb = "Pirate fan.",
		outfit = {
			skin = "Honey",
			hair = { style = "Ponytail", color = "Ginger" },
			hat = { style = "Tricorn", color = "Charcoal", accent = "Gold" },
			top = { style = "Stripes", color = "White", accent = "Red" },
			bottom = { style = "Shorts", color = "Navy" },
			shoes = { style = "Sneakers", color = "Red", accent = "White" },
		},
	},
	{
		id = "Bjorn",
		name = "Bjorn",
		blurb = "Tiny Viking.",
		outfit = {
			skin = "Rosy",
			hair = { style = "Curly", color = "Blond" },
			hat = { style = "VikingHorns", color = "Steel", accent = "Gold" },
			top = { style = "Tee", color = "Grass" },
			bottom = { style = "Pants", color = "Brown" },
			shoes = { style = "Boots", color = "Brown" },
		},
	},
	{
		id = "Kai",
		name = "Kai",
		blurb = "Never without a life ring.",
		outfit = {
			skin = "Caramel",
			hair = { style = "Spiky", color = "Ink" },
			hat = { style = "Cap", color = "Royal", accent = "White" },
			top = { style = "Tee", color = "Tangerine" },
			bottom = { style = "Trunks", color = "Aqua", accent = "White" },
			shoes = { style = "Sneakers", color = "Sky", accent = "White" },
			lifeRing = { style = "LifeRing", color = "Red", accent = "White" },
		},
	},
	{
		id = "Rae",
		name = "Rae",
		blurb = "Beach royalty.",
		outfit = {
			skin = "Cocoa",
			hair = { style = "Ponytail", color = "Lilac" },
			hat = { style = "Crown", color = "Gold", accent = "Red" },
			top = { style = "Tee", color = "Lavender" },
			bottom = { style = "Shorts", color = "Pink" },
			shoes = { style = "Sneakers", color = "White", accent = "Pink" },
		},
	},
	{
		id = "Mo",
		name = "Mo",
		blurb = "Flower power.",
		outfit = {
			skin = "Espresso",
			hair = { style = "Curly", color = "Ink" },
			hat = { style = "Flower", color = "Pink", accent = "Sunny" },
			top = { style = "Tee", color = "Mint" },
			bottom = { style = "Trunks", color = "Coral", accent = "White" },
			shoes = { style = "Bare" },
		},
	},
} :: { Character }

function Characters.get(id: string): Character?
	for _, list in { Characters.Heroes, Characters.Extras } do
		for _, character in list do
			if character.id == id then
				return character
			end
		end
	end
	return nil
end

return Characters
