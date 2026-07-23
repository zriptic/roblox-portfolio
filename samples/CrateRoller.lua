-- CrateRoller
-- Shared crate roll logic, crates and dice play through the same reveal reel

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Warp = require(Packages:WaitForChild("Warp"))
local CrateConfig = require(Modules:WaitForChild("CrateConfig"))
local DiceConfig = require(Modules:WaitForChild("DiceConfig"))
local CharacterData = require(Modules:WaitForChild("CharacterData"))
local UpgradesConfig = require(Modules:WaitForChild("UpgradesConfig"))
local DataManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("DataManager"))

local Server = Warp.Server()
Server.reg_namespaces({ "CrateResult" })

local CrateRoller = {}

local function grantReward(player, crateKey, reward, revealDelay)
	if reward.Type == "Character" then
		DataManager.GiveToolRevealed(player, reward.Id, nil, revealDelay or 7)
	elseif reward.Type == "Cash" then
		DataManager.AddCash(player, reward.Amount or 0, "CrateReward", "Crate:" .. crateKey, nil, Enum.AnalyticsEconomyTransactionType.Shop.Name)
	elseif reward.Type == "Gems" then
		DataManager.AddGems(player, reward.Amount or 0, "CrateReward", "Crate:" .. crateKey, nil, Enum.AnalyticsEconomyTransactionType.Shop.Name)
	end
end

local function toSlot(reward, totalWeight)
	local info = CharacterData[reward.Id]
	return {
		CharacterId = reward.Id,
		DisplayName = (info and info.displayName) or reward.Id,
		Rarity = reward.Rarity,
		Chance = DiceConfig.GetChanceText(reward.Weight or 0, totalWeight),
	}
end

local function buildSlots(crate, reward)
	local totalWeight = 0
	for _, r in ipairs(CrateConfig.GetRollableRewards(crate)) do
		totalWeight += r.Weight or 0
	end

	local slotCount = DiceConfig.Rolling.SlotCount
	local winningIndex = slotCount - 2
	local slots = table.create(slotCount)

	for i = 1, slotCount do
		slots[i] = toSlot(i == winningIndex and reward or CrateConfig.RollReward(crate), totalWeight)
	end

	return slots, winningIndex
end

CrateRoller.grantReward = grantReward

-- rolls a reward with luck applied, grants it, then fires the reel reveal
function CrateRoller.spin(player, crate, revealDelay)
	local luck = 1
	local data = DataManager.Get(player)
	if data and data.Upgrades then
		luck = 1 + UpgradesConfig.GetEffect("DiceLuck", data.Upgrades.DiceLuck or 0) / 100
	end

	local reward = CrateConfig.RollReward(crate, luck)
	if not reward then return false end

	grantReward(player, crate.Key, reward, revealDelay)

	local slots, winningIndex = buildSlots(crate, reward)
	Server.Fire("DiceRollResult", true, player, {
		Slots = slots,
		WinningIndex = winningIndex,
	})

	return reward
end

return CrateRoller
