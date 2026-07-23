-- GlobalStockService
-- Cross server stock caps for limited shop items

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")

local Warp = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Warp"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ShopConfig"))

local Server = Warp.Server()
Server.reg_namespaces({ "LimitedStockUpdate" })

local Store = DataStoreService:GetDataStore("LimitedStock_1")
local MessagingTopic = "LimitedStock"
local MaxReceiptHistory = 250
local RefreshEvery = 30

local GlobalStockService = {}

local soldCounts = {}
local started = false

local function allKeys()
	local keys = {}
	for _, item in ipairs(ShopConfig.Limited) do
		if item.Key then
			table.insert(keys, item.Key)
		end
	end
	return keys
end

local function readSold(key)
	local ok, data = pcall(function()
		return Store:GetAsync(key)
	end)
	if ok and typeof(data) == "table" then
		return tonumber(data.sold) or 0
	end
	return nil
end

function GlobalStockService.GetRemaining(key)
	local stock = ShopConfig.GetLimitedStock(key)
	local sold = soldCounts[key] or 0
	return math.max(0, stock - sold)
end

function GlobalStockService.CanBuy(key)
	if not key then return false end
	return GlobalStockService.GetRemaining(key) > 0
end

function GlobalStockService.GetRemainingMap()
	local map = {}
	for _, key in ipairs(allKeys()) do
		map[key] = GlobalStockService.GetRemaining(key)
	end
	return map
end

local function broadcastToClients()
	Server.Fires("LimitedStockUpdate", true, GlobalStockService.GetRemainingMap())
end

local function applySold(key, sold)
	sold = tonumber(sold)
	if not sold then return end
	-- never let a stale message lower a count
	if sold > (soldCounts[key] or 0) then
		soldCounts[key] = sold
		broadcastToClients()
	end
end

-- called from ProcessReceipt after payment, deduped by PurchaseId since Roblox retries receipts
function GlobalStockService.RecordSale(key, purchaseId)
	if not key then return end
	purchaseId = tostring(purchaseId or "")

	local newSold
	local ok = pcall(function()
		Store:UpdateAsync(key, function(data)
			data = (typeof(data) == "table") and data or { sold = 0, receipts = {} }
			data.sold = tonumber(data.sold) or 0
			data.receipts = data.receipts or {}

			if purchaseId ~= "" and table.find(data.receipts, purchaseId) then
				newSold = data.sold
				return data
			end

			data.sold += 1
			if purchaseId ~= "" then
				table.insert(data.receipts, purchaseId)
				while #data.receipts > MaxReceiptHistory do
					table.remove(data.receipts, 1)
				end
			end
			newSold = data.sold
			return data
		end)
	end)

	if ok and newSold then
		applySold(key, newSold)
		pcall(function()
			MessagingService:PublishAsync(MessagingTopic, { key = key, sold = newSold })
		end)
	end
end

local function refreshAll()
	local changed = false
	for _, key in ipairs(allKeys()) do
		local sold = readSold(key)
		if sold ~= nil and sold > (soldCounts[key] or 0) then
			soldCounts[key] = sold
			changed = true
		elseif sold ~= nil and soldCounts[key] == nil then
			soldCounts[key] = sold
			changed = true
		end
	end
	if changed then
		broadcastToClients()
	end
end

function GlobalStockService.Start()
	if started then return end
	started = true

	pcall(function()
		MessagingService:SubscribeAsync(MessagingTopic, function(message)
			local data = message.Data
			if typeof(data) == "table" and data.key then
				applySold(data.key, data.sold)
			end
		end)
	end)

	for _, key in ipairs(allKeys()) do
		soldCounts[key] = readSold(key) or 0
	end

	-- new joiners get the current map
	Players.PlayerAdded:Connect(function()
		task.defer(broadcastToClients)
	end)

	task.spawn(function()
		while true do
			task.wait(RefreshEvery)
			refreshAll()
		end
	end)
end

return GlobalStockService
