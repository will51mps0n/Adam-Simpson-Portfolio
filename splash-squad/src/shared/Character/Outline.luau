--!strict
-- Thick dark cartoon outlines using Roblox Highlights (fill off, outline on).
-- Roblox only draws about 31 Highlights at once, so this keeps count and
-- refuses to add more than Config.Outline.MaxHighlights.

local Config = require(script.Parent.Parent.Config)

local Outline = {}

local active: { [Highlight]: boolean } = {}

-- How many outlines exist right now (forgets ones that were destroyed).
function Outline.count(): number
	local n = 0
	for highlight in active do
		if highlight.Parent then
			n += 1
		else
			active[highlight] = nil
		end
	end
	return n
end

function Outline.add(target: Instance): Highlight?
	if Outline.count() >= Config.Outline.MaxHighlights then
		warn("[Outline] Highlight limit reached; this one will have no outline")
		return nil
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "Outline"
	highlight.FillTransparency = 1
	highlight.OutlineColor = Config.Outline.Color
	highlight.OutlineTransparency = Config.Outline.Transparency
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = target
	highlight.Parent = target
	active[highlight] = true
	return highlight
end

function Outline.remove(target: Instance)
	for _, child in target:GetChildren() do
		if child:IsA("Highlight") then
			active[child] = nil
			child:Destroy()
		end
	end
end

return Outline
