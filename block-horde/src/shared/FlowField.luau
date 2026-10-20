--!strict
-- Enemy pathfinding: one shortest-path search outward from every player's
-- cell (Dijkstra over the room grid). Afterwards every floor cell knows which
-- neighbour cell leads toward the nearest player. Cells cost more to walk
-- through when a barrel or wall is in them, so enemies go around if they can
-- and chew through if they can't.

export type Field = {
	width: number,
	height: number,
	dist: { number }, -- path cost to the nearest player, per cell
	toward: { number }, -- index of the next cell to step into (0 = none)
}

export type CellRef = { c: number, r: number }

local FlowField = {}

local DIAGONAL = math.sqrt(2)
local NEIGHBORS = {
	{ 1, 0 },
	{ -1, 0 },
	{ 0, 1 },
	{ 0, -1 },
	{ 1, 1 },
	{ 1, -1 },
	{ -1, 1 },
	{ -1, -1 },
}

-- cost(c, r) returns nil for walls, otherwise the cost of stepping into the cell (1 = plain floor).
function FlowField.compute(width: number, height: number, cost: (number, number) -> number?, sources: { CellRef }): Field
	local count = width * height
	local dist = table.create(count, math.huge)
	local toward = table.create(count, 0)
	local costs = table.create(count, 0) -- 0 = impassable
	for r = 1, height do
		for c = 1, width do
			costs[(r - 1) * width + c] = cost(c, r) or 0
		end
	end

	-- Binary min-heap of cell indexes keyed by distance.
	local heapCells: { number } = {}
	local heapDist: { number } = {}
	local size = 0
	local function push(cell: number, d: number)
		size += 1
		local i = size
		heapCells[i] = cell
		heapDist[i] = d
		while i > 1 do
			local parent = i // 2
			if heapDist[parent] <= heapDist[i] then
				break
			end
			heapCells[parent], heapCells[i] = heapCells[i], heapCells[parent]
			heapDist[parent], heapDist[i] = heapDist[i], heapDist[parent]
			i = parent
		end
	end
	local function pop(): (number, number)
		local cell, d = heapCells[1], heapDist[1]
		heapCells[1], heapDist[1] = heapCells[size], heapDist[size]
		size -= 1
		local i = 1
		while true do
			local left, right = i * 2, i * 2 + 1
			local smallest = i
			if left <= size and heapDist[left] < heapDist[smallest] then
				smallest = left
			end
			if right <= size and heapDist[right] < heapDist[smallest] then
				smallest = right
			end
			if smallest == i then
				break
			end
			heapCells[smallest], heapCells[i] = heapCells[i], heapCells[smallest]
			heapDist[smallest], heapDist[i] = heapDist[i], heapDist[smallest]
			i = smallest
		end
		return cell, d
	end

	for _, source in sources do
		if source.c >= 1 and source.c <= width and source.r >= 1 and source.r <= height then
			local index = (source.r - 1) * width + source.c
			if dist[index] > 0 then
				dist[index] = 0
				push(index, 0)
			end
		end
	end

	while size > 0 do
		local index, d = pop()
		if d > dist[index] then
			continue
		end
		local c = (index - 1) % width + 1
		local r = (index - 1) // width + 1
		-- Walking from a neighbour into this cell costs this cell's cost.
		local enterCost = math.max(costs[index], 1)
		for _, offset in NEIGHBORS do
			local nc, nr = c + offset[1], r + offset[2]
			if nc < 1 or nc > width or nr < 1 or nr > height then
				continue
			end
			local neighbor = (nr - 1) * width + nc
			if costs[neighbor] == 0 then
				continue
			end
			local diagonal = offset[1] ~= 0 and offset[2] ~= 0
			-- No cutting corners past walls.
			if diagonal and (costs[(r - 1) * width + nc] == 0 or costs[(nr - 1) * width + c] == 0) then
				continue
			end
			local nd = d + (if diagonal then DIAGONAL else 1) * enterCost
			if nd < dist[neighbor] then
				dist[neighbor] = nd
				toward[neighbor] = index
				push(neighbor, nd)
			end
		end
	end

	return { width = width, height = height, dist = dist, toward = toward }
end

-- The next cell to walk into from (c, r), or nil if there is no path.
function FlowField.next(field: Field, c: number, r: number): (number?, number?)
	if c < 1 or c > field.width or r < 1 or r > field.height then
		return nil, nil
	end
	local target = field.toward[(r - 1) * field.width + c]
	if target == 0 then
		return nil, nil
	end
	return (target - 1) % field.width + 1, (target - 1) // field.width + 1
end

return FlowField
