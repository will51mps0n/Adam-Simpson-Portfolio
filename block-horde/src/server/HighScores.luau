--!strict
-- Best scores per room and difficulty, saved in OrderedDataStores.
-- Saving needs a published place with Studio API access turned on
-- (Game Settings > Security); without it, saves quietly do nothing.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

export type Row = { name: string, score: number }

local HighScores = {}

local warned = false
local names: { [number]: string } = {}

local function warnOnce(err: any)
	if not warned then
		warned = true
		warn("[Block Horde] high scores unavailable (publish the game and enable Studio API access): " .. tostring(err))
	end
end

local function store(roomId: string, difficulty: string): OrderedDataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore("BlockHorde_" .. roomId .. "_" .. difficulty)
	end)
	if ok then
		return result
	end
	warnOnce(result)
	return nil
end

-- Calls fn up to three times, waiting a little longer after each failure.
local function retry(fn: () -> any): (boolean, any)
	local ok, result = false, nil
	for attempt = 1, 3 do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		task.wait(attempt)
	end
	warnOnce(result)
	return false, result
end

local function nameFor(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and typeof(name) == "string" then name else "Player " .. userId
	names[userId] = result
	return result
end

-- Saves the score if it beats the player's best. Yields.
function HighScores.submit(roomId: string, difficulty: string, userId: number, score: number)
	local scores = store(roomId, difficulty)
	local value = math.floor(score)
	if not scores or value <= 0 or userId <= 0 then
		return
	end
	local transform: any = function(old: number?): number?
		if old and old >= value then
			return nil -- keep the old best
		end
		return value
	end
	retry(function()
		return scores:UpdateAsync(tostring(userId), transform)
	end)
end

-- The top scores for a room and difficulty, best first, or nil if unavailable. Yields.
function HighScores.top(roomId: string, difficulty: string, count: number): { Row }?
	local scores = store(roomId, difficulty)
	if not scores then
		return nil
	end
	local ok, pages = retry(function()
		return scores:GetSortedAsync(false, count)
	end)
	if not ok or not pages then
		return nil
	end
	local rows: { Row } = {}
	for _, item in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(item.key) or 0
		table.insert(rows, { name = nameFor(userId), score = item.value })
	end
	return rows
end

return HighScores
