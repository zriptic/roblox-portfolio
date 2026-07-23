-- EventService
-- Global events, every server picks the same event from a seeded cycle

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Warp = require(Packages:WaitForChild("Warp"))
local Server = Warp.Server()

local EventConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EventConfig"))
local CharacterData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CharacterData"))
local Npc = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("NpcManager"))
local QuestService = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("QuestService"))

Server.reg_namespaces({ "EventStarted", "EventEnded", "EventStrike", "RequestEventState", "ShowNotification" })

local OverrideMap = MemoryStoreService:GetHashMap("EventOverride")
local OverrideKey = "current"
local OverrideTtl = 7 * 24 * 60 * 60
local MessagingTopic = "EventOverride"

local rng = Random.new()

-- new players are guaranteed a strike per event
local NewPlayerSeconds = 29 * 60

local joinTimes = {}
Players.PlayerAdded:Connect(function(player)
	joinTimes[player] = os.clock()
end)
Players.PlayerRemoving:Connect(function(player)
	joinTimes[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	joinTimes[player] = os.clock()
end

local function isNewPlayer(userId)
	local player = userId and Players:GetPlayerByUserId(userId)
	local joined = player and joinTimes[player]
	return joined ~= nil and (os.clock() - joined) < NewPlayerSeconds
end

local EventService = {}

local override = nil
local running = nil
local started = false

local function pickEventForCycle(anchor, cycleIndex, forced)
	if forced and cycleIndex == 0 then
		return EventConfig.Resolve(forced)
	end
	local order = EventConfig.EventOrder
	if #order == 0 then return nil end
	local pick = Random.new(anchor * 1000 + cycleIndex)
	return order[pick:NextInteger(1, #order)]
end

local function getEligibleUnits(eventName, struckPlots)
	local units = {}
	for _, plot in ipairs(workspace.Plots:GetChildren()) do
		if (plot:GetAttribute("OwnerId") or 0) ~= 0 and not struckPlots[plot] then
			local structure = plot:FindFirstChild("Structure")
			local npcs = structure and structure:FindFirstChild("Npcs")
			if npcs then
				for _, model in ipairs(npcs:GetChildren()) do
					local npc = Npc.get(model)
					if npc and not npc:hasCharm(eventName) and #npc.charms < EventConfig.MaxCharmsPerUnit then
						table.insert(units, { npc = npc, plot = plot })
					end
				end
			end
		end
	end
	return units
end

local function pickUnit(units)
	local total = 0
	for _, unit in ipairs(units) do
		unit.weight = 1
		total += unit.weight
	end

	local roll = rng:NextNumber() * total
	for _, unit in ipairs(units) do
		roll -= unit.weight
		if roll <= 0 then
			return unit
		end
	end

	return units[#units]
end

local function notifyOwner(npc, cfg)
	local owner = npc.ownerId and Players:GetPlayerByUserId(npc.ownerId)
	if not owner then return end

	local data = CharacterData[npc.npcName]
	local charName = (data and data.displayName) or npc.npcName
	local color = cfg.Color or "#FFFFFF"
	local pct = math.floor((cfg.Charm and cfg.Charm.CashAdd or 0) * 100 + 0.5)
	local text = string.format(
		'Your <b>%s</b> was struck by the <font color="%s"><b>%s</b></font> Event! <font color="%s">+%d%% cash</font>',
		charName, color, cfg.DisplayName or "", color, pct
	)
	Server.Fire("ShowNotification", true, owner, text, { RichText = true, Length = 6 })
end

local function doStrike(eventName, cfg)
	if not running then return end
	if running.struckCount >= (EventConfig.MaxStrikesPerEvent or math.huge) then return end

	local units = getEligibleUnits(eventName, running.struckPlots)
	if #units == 0 then return end

	-- new players get hit first and skip the chance roll
	local newPlayerUnits = {}
	for _, unit in ipairs(units) do
		if isNewPlayer(unit.plot:GetAttribute("OwnerId")) then
			table.insert(newPlayerUnits, unit)
		end
	end

	if #newPlayerUnits > 0 then
		units = newPlayerUnits
	elseif rng:NextNumber() > (cfg.StrikeChance or 1) then
		return
	end

	local choice = pickUnit(units)
	if choice.npc:addCharm(eventName) then
		running.struckPlots[choice.plot] = true
		running.struckCount += 1
		local hrp = choice.npc.model:FindFirstChild("HumanoidRootPart")
		if hrp then
			Server.Fires("EventStrike", true, eventName, hrp)
		end
		notifyOwner(choice.npc, cfg)
	end
end

local function startEvent(eventName, cycleStart, endsAt)
	local cfg = EventConfig.GetEvent(eventName)
	if not cfg then return end

	running = { name = eventName, cycleStart = cycleStart, endsAt = endsAt, struckCount = 0, struckPlots = {} }
	Server.Fires("EventStarted", true, eventName, endsAt)

	for _, player in ipairs(Players:GetPlayers()) do
		QuestService.AddProgress(player, "Event", 1)
	end

	running.thread = task.spawn(function()
		while running and running.name == eventName and os.time() < endsAt do
			doStrike(eventName, cfg)
			task.wait(cfg.StrikeEverySeconds or 8)
		end
	end)
end

local function stopEvent()
	if not running then return end
	local eventName = running.name
	running = nil
	Server.Fires("EventEnded", true, eventName)
end

local function applyOverride(data)
	if data and data.anchor and data.event then
		override = { anchor = data.anchor, event = data.event }
	end
end

local function refreshOverride()
	local ok, data = pcall(function()
		return OverrideMap:GetAsync(OverrideKey)
	end)
	if ok then
		applyOverride(data)
	end
end

-- fired by the Cmdr command, re-anchors the cycle on every server
function EventService.ManualFire(eventName)
	local resolved = EventConfig.Resolve(eventName)
	if not resolved then return false end

	local data = { anchor = os.time(), event = resolved }
	pcall(function()
		OverrideMap:SetAsync(OverrideKey, data, OverrideTtl)
	end)
	pcall(function()
		MessagingService:PublishAsync(MessagingTopic, data)
	end)
	applyOverride(data)
	return true
end

local function evaluate()
	local now = os.time()
	local anchor = override and override.anchor or 0
	local forced = override and override.event or nil

	local cycleIndex = math.floor((now - anchor) / EventConfig.CycleSeconds)
	local cycleStart = anchor + cycleIndex * EventConfig.CycleSeconds
	local endsAt = cycleStart + EventConfig.EventSeconds

	local activeName
	if now < endsAt then
		activeName = pickEventForCycle(anchor, cycleIndex, forced)
	end

	if running and (not activeName or running.name ~= activeName or running.cycleStart ~= cycleStart) then
		stopEvent()
	end

	if activeName and not running then
		startEvent(activeName, cycleStart, endsAt)
	end
end

function EventService.Start()
	if started then return end
	started = true

	pcall(function()
		MessagingService:SubscribeAsync(MessagingTopic, function(message)
			applyOverride(message.Data)
		end)
	end)
	refreshOverride()

	-- late joiners ask for the current event state
	Server.Connect("RequestEventState", function(player)
		if running then
			Server.Fire("EventStarted", true, player, running.name, running.endsAt)
		end
	end)

	local refreshClock = 0
	while true do
		evaluate()

		refreshClock += 1
		if refreshClock >= 30 then
			refreshClock = 0
			refreshOverride()
		end

		task.wait(1)
	end
end

return EventService
