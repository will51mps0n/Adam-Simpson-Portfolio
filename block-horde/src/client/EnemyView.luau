--!strict
-- Where this client thinks enemies are, for instant tracer endpoints.
-- Milestone 1 reads the practice dummies; Milestone 3 replaces this with
-- interpolated enemy snapshots from the server.

local EnemyView = {}

export type Target = { x: number, z: number, radius: number }

function EnemyView.getTargets(): { Target }
	local targets: { Target } = {}
	local folder = workspace:FindFirstChild("PracticeTargets")
	if not folder then
		return targets
	end
	for _, model in folder:GetChildren() do
		local radius = model:GetAttribute("Radius")
		if model:IsA("Model") and typeof(radius) == "number" then
			local pos = model:GetPivot().Position
			table.insert(targets, { x = pos.X, z = pos.Z, radius = radius })
		end
	end
	return targets
end

function EnemyView.circleOf(target: Target): (number, number, number)
	return target.x, target.z, target.radius
end

return EnemyView
