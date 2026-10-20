--!strict
-- Collects the kills from one shot, blast or turret burst so they can be
-- scored together (several kills at once earn a multiplier bonus).

export type KillContext = {
	owner: Player?, -- who gets the credit, if anyone
	kills: { number }, -- base score of each enemy killed
}

local KillContext = {}

function KillContext.new(owner: Player?): KillContext
	return { owner = owner, kills = {} }
end

return KillContext
