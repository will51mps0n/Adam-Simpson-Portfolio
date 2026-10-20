--!strict
-- Lobby parties. Step onto an empty pad to start a party and become its
-- leader; the leader picks the room, difficulty, party size and friends-only,
-- then presses START. Others join by stepping onto the pad (if there is room
-- and, for friends-only parties, they are the leader's friend). Stepping off
-- leaves the party. When the countdown ends the party goes into a game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local RunState = require(script.Parent.RunState)
local Teleporter = require(script.Parent.Teleporter)

local PartyState = Net.event("PartyState")
local PartyAction = Net.event("PartyAction")
local Announce = Net.event("Announce")

type Party = {
	pad: LobbyBuilder.Pad,
	leader: Player?,
	members: { Player },
	room: string,
	difficulty: string,
	size: number,
	friendsOnly: boolean,
	countdownEnd: number?,
	shownSeconds: number?,
}

local PartyService = {}

local COLOR_OPEN = Color3.fromRGB(60, 200, 90)
local COLOR_FORMING = Color3.fromRGB(240, 200, 40)
local COLOR_STARTING = Color3.fromRGB(240, 120, 30)

local parties: { Party } = {}
local memberOf: { [Player]: Party } = {}
local standingOn: { [Player]: number } = {} -- pad index each player stands on
local waitForStepOff: { [Player]: boolean } = {} -- just launched or turned away: ignore until they leave the pad
local friendCache: { [string]: boolean } = {}
local friendPending: { [string]: boolean } = {}

local function resetParty(party: Party)
	party.leader = nil
	party.members = {}
	party.room = Rooms.ORDER[1]
	party.difficulty = "Intermediate"
	party.size = Config.PARTY_DEFAULT_SIZE
	party.friendsOnly = false
	party.countdownEnd = nil
	party.shownSeconds = nil
end

local function secondsLeft(party: Party): number?
	local finish = party.countdownEnd
	return if finish then math.max(0, math.ceil(finish - os.clock())) else nil
end

local function refresh(party: Party)
	local pad = party.pad
	local color = COLOR_OPEN
	local seconds = secondsLeft(party)
	if #party.members == 0 then
		pad.title.Text = "PARTY " .. pad.index
		pad.detail.Text = "STEP IN TO START A PARTY"
	elseif seconds then
		color = COLOR_STARTING
		pad.title.Text = "STARTING IN " .. seconds
		pad.detail.Text = Rooms.ARENAS[party.room].name .. "  -  " .. string.upper(party.difficulty)
	else
		color = COLOR_FORMING
		pad.title.Text = Rooms.ARENAS[party.room].name .. "  -  " .. string.upper(party.difficulty)
		pad.detail.Text = #party.members .. "/" .. party.size .. " PLAYERS" .. (if party.friendsOnly then "  -  FRIENDS ONLY" else "")
	end
	pad.base.Color = color
	for _, strip in pad.border do
		strip.Color = color
	end

	local names = {}
	for _, member in party.members do
		table.insert(names, member.DisplayName)
	end
	for _, member in party.members do
		PartyState:FireClient(member, {
			pad = pad.index,
			leader = if party.leader then party.leader.DisplayName else "",
			isLeader = party.leader == member,
			members = names,
			room = party.room,
			difficulty = party.difficulty,
			size = party.size,
			friendsOnly = party.friendsOnly,
			countdown = seconds,
		})
	end
end

local function leave(player: Player)
	local party = memberOf[player]
	if not party then
		return
	end
	memberOf[player] = nil
	local index = table.find(party.members, player)
	if index then
		table.remove(party.members, index)
	end
	if #party.members == 0 then
		resetParty(party)
	elseif party.leader == player then
		party.leader = party.members[1]
	end
	if party.size < #party.members then
		party.size = #party.members
	end
	PartyState:FireClient(player, nil)
	refresh(party)
end

-- Whether a player may join; nil while a friend check is still in progress.
local function mayJoin(party: Party, player: Player): (boolean?, string?)
	if #party.members >= party.size then
		return false, "THAT PARTY IS FULL"
	end
	local leader = party.leader
	if party.friendsOnly and leader and leader ~= player then
		local pair = leader.UserId .. ":" .. player.UserId
		local cached = friendCache[pair]
		if cached == nil then
			if not friendPending[pair] then
				friendPending[pair] = true
				task.spawn(function()
					local ok, friends = pcall(function()
						return player:IsFriendsWithAsync(leader.UserId)
					end)
					friendCache[pair] = ok and friends == true
					friendPending[pair] = nil
				end)
			end
			return nil, nil
		end
		if not cached then
			return false, "THAT PARTY IS FRIENDS ONLY"
		end
	end
	return true, nil
end

local function join(party: Party, player: Player)
	memberOf[player] = party
	table.insert(party.members, player)
	if not party.leader then
		party.leader = player
	end
	refresh(party)
end

local function launch(party: Party)
	local members = table.clone(party.members)
	local room, difficulty = party.room, party.difficulty
	for _, member in members do
		memberOf[member] = nil
		waitForStepOff[member] = true
		PartyState:FireClient(member, nil)
	end
	resetParty(party)
	refresh(party)
	if #members > 0 then
		Teleporter.launch(members, room, difficulty)
	end
end

local function padAt(pads: { LobbyBuilder.Pad }, position: Vector3): number?
	for _, pad in pads do
		if position.X >= pad.minX and position.X <= pad.maxX and position.Z >= pad.minZ and position.Z <= pad.maxZ then
			return pad.index
		end
	end
	return nil
end

local function onAction(player: Player, action: unknown, value: unknown)
	local party = memberOf[player]
	if not party or party.leader ~= player or typeof(action) ~= "string" then
		return
	end
	if action == "room" and typeof(value) == "string" and Rooms.ARENAS[value] then
		party.room = value
	elseif action == "difficulty" and typeof(value) == "string" and Config.DIFFICULTIES[value] then
		party.difficulty = value
	elseif action == "size" and typeof(value) == "number" and value == value then
		party.size = math.clamp(math.floor(value), math.max(1, #party.members), Config.PARTY_MAX_PLAYERS)
	elseif action == "friends" and typeof(value) == "boolean" then
		party.friendsOnly = value
	elseif action == "start" and not party.countdownEnd then
		party.countdownEnd = os.clock() + Config.PARTY_COUNTDOWN
	elseif action == "cancel" then
		party.countdownEnd = nil
		party.shownSeconds = nil
	end
	refresh(party)
end

local function tick(pads: { LobbyBuilder.Pad })
	for _, player in Players:GetPlayers() do
		if RunState.isParticipant(player) then
			if memberOf[player] then
				leave(player)
			end
			standingOn[player] = nil
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local index: number? = nil
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			index = padAt(pads, root.Position)
		end
		if waitForStepOff[player] then
			if index == nil then
				waitForStepOff[player] = nil
			end
			continue
		end
		if index ~= standingOn[player] then
			leave(player)
			if index then
				standingOn[player] = index
			else
				standingOn[player] = nil
			end
		end
		if index and not memberOf[player] then
			local party = parties[index]
			local allowed, reason = mayJoin(party, player)
			if allowed then
				join(party, player)
			elseif allowed == false then
				Announce:FireClient(player, reason or "CAN'T JOIN", "info")
				waitForStepOff[player] = true
			end
		end
	end

	for _, party in parties do
		local seconds = secondsLeft(party)
		if seconds and #party.members == 0 then
			party.countdownEnd = nil
		elseif seconds == 0 then
			launch(party)
		elseif seconds ~= party.shownSeconds then
			party.shownSeconds = seconds
			refresh(party)
		end
	end
end

function PartyService.start(pads: { LobbyBuilder.Pad })
	for _, pad in pads do
		local party: Party = {
			pad = pad,
			leader = nil,
			members = {},
			room = Rooms.ORDER[1],
			difficulty = "Intermediate",
			size = Config.PARTY_DEFAULT_SIZE,
			friendsOnly = false,
			countdownEnd = nil,
			shownSeconds = nil,
		}
		parties[pad.index] = party
		refresh(party)
	end
	PartyAction.OnServerEvent:Connect(onAction)
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		standingOn[player] = nil
		waitForStepOff[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			tick(pads)
		end
	end)
end

return PartyService
