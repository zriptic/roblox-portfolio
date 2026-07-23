-- DataService
-- Session-locked player data on ProfileService

local Players = game:GetService("Players")
local ProfileService = require(script.Parent.ProfileService)

local ProfileTemplate = {
	Coins = 0,
	Gems = 0,
	Rebirths = 0,
	Inventory = {},
	LoginCount = 0,
}

local DataService = {}
local ProfileStore = ProfileService.GetProfileStore("PlayerData_v1", ProfileTemplate)
local Profiles = {}

local function buildLeaderstats(player, profile)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = profile.Data.Coins
	coins.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = profile.Data.Rebirths
	rebirths.Parent = leaderstats
	leaderstats.Parent = player
end

-- Player Data Load
local function onPlayerAdded(player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
	if not profile then
		player:Kick("Data is loaded on another server, rejoin in a moment")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile:ListenToRelease(function()
		Profiles[player] = nil
		player:Kick("Session claimed elsewhere, rejoin in a moment")
	end)
	if not player:IsDescendantOf(Players) then
		profile:Release()
		return
	end
	profile.Data.LoginCount += 1
	Profiles[player] = profile
	buildLeaderstats(player, profile)
end

function DataService.Get(player)
	while not Profiles[player] and player:IsDescendantOf(Players) do
		task.wait()
	end
	local profile = Profiles[player]
	return profile and profile.Data
end

function DataService.AddCoins(player, amount)
	local data = DataService.Get(player)
	if not data then return end
	data.Coins += amount
	player.leaderstats.Coins.Value = data.Coins
end

function DataService.SpendCoins(player, amount)
	local data = DataService.Get(player)
	if not data or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	player.leaderstats.Coins.Value = data.Coins
	return true
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]
	if profile then
		profile:Release()
	end
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

return DataService
