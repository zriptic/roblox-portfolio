--[[
	Roblox Live Analytics SDK
	Drop this ModuleScript into ServerScriptService and initialize once from a server Script:

		local Analytics = require(game.ServerScriptService.Analytics)
		Analytics.init({
			endpoint = "https://your-app.up.railway.app",
			key = "YOUR_GAME_API_KEY",
			mirrorToRoblox = true, -- also log funnel steps to Roblox's own AnalyticsService
		})

	Requires "Allow HTTP Requests" in Game Settings > Security.
	Everything is server-side only.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local AnalyticsService = game:GetService("AnalyticsService")
local LocalizationService = game:GetService("LocalizationService")

local Analytics = {}

local config = nil
local queue = {}
local sessions = {} -- [userId] = { sessionId, startedAt }
local productInfoCache = {} -- ["type_id"] = { price, name }
local FLUSH_INTERVAL = 20
local HEARTBEAT_INTERVAL = 30
local MAX_BATCH = 400

-- ---------- internals ----------

local function enqueue(eventType, userId, data)
	if not config then return end
	local session = userId and sessions[userId]
	table.insert(queue, {
		type = eventType,
		userId = userId,
		sessionId = session and session.sessionId or nil,
		serverId = game.JobId ~= "" and game.JobId or "studio",
		ts = os.time(),
		data = data or {},
	})
end

local function flush()
	if #queue == 0 or not config then return end
	local batch = {}
	for i = 1, math.min(#queue, MAX_BATCH) do
		batch[i] = queue[i]
	end
	local body = HttpService:JSONEncode({ gameKey = config.key, events = batch })

	local ok = pcall(function()
		HttpService:PostAsync(config.endpoint .. "/v1/events", body, Enum.HttpContentType.ApplicationJson)
	end)
	if ok then
		for _ = 1, #batch do
			table.remove(queue, 1)
		end
	end
	-- on failure events stay queued and retry next flush
end

local function getProductInfo(id, infoType)
	local cacheKey = tostring(infoType) .. "_" .. tostring(id)
	if productInfoCache[cacheKey] then return productInfoCache[cacheKey] end
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
	if ok and info then
		productInfoCache[cacheKey] = { price = info.PriceInRobux or 0, name = info.Name or "" }
		return productInfoCache[cacheKey]
	end
	return { price = 0, name = "" }
end

-- ---------- session tracking ----------

local function onPlayerAdded(player)
	local sessionId = HttpService:GenerateGUID(false)
	sessions[player.UserId] = { sessionId = sessionId, startedAt = os.clock() }
	task.spawn(function()
		-- Country powers the Audience tab; the lookup yields so it runs
		-- off the join path. Platform needs a client ping (Roblox exposes
		-- no server-side device API) — "unknown" until that's added.
		local country = "unknown"
		pcall(function()
			country = LocalizationService:GetCountryRegionForPlayerAsync(player)
		end)
		enqueue("session_start", player.UserId, {
			accountAge = player.AccountAge,
			platform = "unknown",
			country = country,
			followedFriend = player.FollowUserId ~= 0,
		})
	end)
end

local function onPlayerRemoving(player)
	local session = sessions[player.UserId]
	if session then
		enqueue("session_end", player.UserId, {
			duration = math.floor(os.clock() - session.startedAt),
		})
		sessions[player.UserId] = nil
	end
end

-- ---------- monetization hooks ----------

local function hookMarketplace()
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
		local info = getProductInfo(productId, Enum.InfoType.Product)
		enqueue("purchase_completed", userId, {
			kind = "product", productId = productId, productName = info.name,
			price = info.price, wasPurchased = wasPurchased,
		})
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
		local info = getProductInfo(gamePassId, Enum.InfoType.GamePass)
		enqueue("purchase_completed", player.UserId, {
			kind = "gamepass", productId = gamePassId, productName = info.name,
			price = info.price, wasPurchased = wasPurchased,
		})
	end)

	MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, wasPurchased)
		local info = getProductInfo(assetId, Enum.InfoType.Asset)
		enqueue("purchase_completed", player.UserId, {
			kind = "asset", productId = assetId, productName = info.name,
			price = info.price, wasPurchased = wasPurchased,
		})
	end)
end

-- ---------- public API ----------

function Analytics.init(cfg)
	assert(cfg and cfg.endpoint and cfg.key, "Analytics.init requires { endpoint, key }")
	assert(config == nil, "Analytics.init called twice")

	-- Live analytics only run in real servers: Studio playtests would pollute
	-- sessions, retention and funnels with test data. config stays nil, so
	-- every public function silently no-ops.
	if RunService:IsStudio() then
		return
	end

	config = cfg
	config.endpoint = config.endpoint:gsub("/+$", "")

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	hookMarketplace()

	task.spawn(function()
		while true do
			task.wait(HEARTBEAT_INTERVAL)
			enqueue("heartbeat", nil, { playerCount = #Players:GetPlayers() })
		end
	end)

	task.spawn(function()
		while true do
			task.wait(FLUSH_INTERVAL)
			flush()
		end
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			onPlayerRemoving(player)
		end
		flush()
	end)
end

--- Custom event: Analytics.track("egg_hatched", player, { egg = "legendary" })
function Analytics.track(eventName, player, data)
	data = data or {}
	data.name = eventName
	enqueue("custom", player and player.UserId or nil, data)
end

--- One-time onboarding funnel (mirrors AnalyticsService:LogOnboardingFunnelStepEvent).
--- Server dedupes per player, so calling repeatedly is safe.
function Analytics.logOnboardingStep(player, step, stepName)
	enqueue("onboarding_step", player.UserId, {
		funnelName = "Onboarding", step = step, stepName = stepName,
	})
	if config and config.mirrorToRoblox then
		pcall(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
		end)
	end
end

--- Repeatable funnel (mirrors AnalyticsService:LogFunnelStepEvent).
--- funnelSessionId groups one pass through the funnel (e.g. one shop visit).
function Analytics.logFunnelStep(player, funnelName, funnelSessionId, step, stepName)
	enqueue("funnel_step", player.UserId, {
		funnelName = funnelName, funnelSessionId = funnelSessionId,
		step = step, stepName = stepName,
	})
	if config and config.mirrorToRoblox then
		pcall(function()
			AnalyticsService:LogFunnelStepEvent(player, funnelName, funnelSessionId, step, stepName)
		end)
	end
end

--- Call this one line from your existing ProcessReceipt handler (ground truth for dev products):
---   Analytics.trackReceipt(receiptInfo)
function Analytics.trackReceipt(receiptInfo)
	enqueue("receipt", receiptInfo.PlayerId, {
		productId = receiptInfo.ProductId,
		price = receiptInfo.CurrencySpent,
		purchaseId = receiptInfo.PurchaseId,
	})
end

--- Generate a funnel session id (convenience wrapper).
function Analytics.newFunnelSession()
	return HttpService:GenerateGUID(false)
end

return Analytics
