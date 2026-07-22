--[[
	DataService
	Session-locked player data on top of ProfileService.
	Require it from any server script — data is guaranteed loaded before Get() resolves.

	ProfileService: https://github.com/MadStudioRoblox/ProfileService
]]

local Players = game:GetService("Players")

local ProfileService = require(script.Parent.ProfileService)

local PROFILE_TEMPLATE = {
	Coins = 0,
	Gems = 0,
	Rebirths = 0,
	Inventory = {},
	Settings = {
		MusicEnabled = true,
	},
	LoginCount = 0,
}

local DataService = {}

local profileStore = ProfileService.GetProfileStore("PlayerData_v1", PROFILE_TEMPLATE)
local profiles = {} -- [player] = profile
local loadedSignals = {} -- [player] = { thread, ... } waiting on load

-- ---------- internals ----------

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

local function onPlayerAdded(player)
	local profile = profileStore:LoadProfileAsync("Player_" .. player.UserId)
	if not profile then
		-- Another server refuses to release the session — never risk overwriting it.
		player:Kick("Your data is loaded on another server. Rejoin in a moment.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile() -- fill in any keys added to the template since last save

	profile:ListenToRelease(function()
		profiles[player] = nil
		player:Kick("Your session was claimed elsewhere. Rejoin in a moment.")
	end)

	if not player:IsDescendantOf(Players) then
		profile:Release() -- left while loading
		return
	end

	profile.Data.LoginCount += 1
	profiles[player] = profile
	buildLeaderstats(player, profile)

	local waiting = loadedSignals[player]
	if waiting then
		loadedSignals[player] = nil
		for _, thread in ipairs(waiting) do
			task.spawn(thread)
		end
	end
end

local function onPlayerRemoving(player)
	local profile = profiles[player]
	if profile then
		profile:Release()
	end
	loadedSignals[player] = nil
end

-- ---------- public API ----------

--- Yields until the player's profile is loaded (or they leave). Returns profile.Data or nil.
function DataService.Get(player)
	local profile = profiles[player]
	if profile then
		return profile.Data
	end
	if not player:IsDescendantOf(Players) then
		return nil
	end

	loadedSignals[player] = loadedSignals[player] or {}
	table.insert(loadedSignals[player], coroutine.running())
	coroutine.yield()

	profile = profiles[player]
	return profile and profile.Data or nil
end

function DataService.AddCoins(player, amount)
	local data = DataService.Get(player)
	if not data then return end

	data.Coins += amount
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Coins.Value = data.Coins
	end
end

--- Atomic spend: returns true only if the player could afford it.
function DataService.SpendCoins(player, amount)
	local data = DataService.Get(player)
	if not data or data.Coins < amount then
		return false
	end

	data.Coins -= amount
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Coins.Value = data.Coins
	end
	return true
end

-- ---------- init ----------

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

return DataService
