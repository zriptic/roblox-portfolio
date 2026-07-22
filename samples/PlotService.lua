--[[
	PlotService
	Server-authoritative plot assignment + structure placement.

	Layout expectations:
		workspace.Plots            — folder of plot Models, each with a "Base" part
		ReplicatedStorage.Structures — folder of placeable structure Models (with PrimaryPart)

	The client only ever *asks* to place. Ownership, catalog membership, funds,
	and bounds are all decided here — an exploiter with full remote access
	can't place on someone else's plot, place off-grid, or place for free.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local STRUCTURE_COSTS = {
	House = 100,
	Turret = 350,
	Wall = 25,
	Generator = 500,
}
local GRID = 4 -- studs

local PlotService = {}

local plots = {} -- [plotModel] = owner Player or nil
local ownedPlot = {} -- [player] = plotModel

-- ---------- internals ----------

local function snapToPlot(plot, position)
	local base = plot.Base
	-- Work in plot-local space so rotated plots snap correctly.
	local localPos = base.CFrame:PointToObjectSpace(position)

	local halfX = base.Size.X / 2
	local halfZ = base.Size.Z / 2
	if math.abs(localPos.X) > halfX or math.abs(localPos.Z) > halfZ then
		return nil -- outside the plot, reject
	end

	local snapped = Vector3.new(
		math.round(localPos.X / GRID) * GRID,
		base.Size.Y / 2,
		math.round(localPos.Z / GRID) * GRID
	)
	return base.CFrame:PointToWorldSpace(snapped)
end

local function assignPlot(player)
	for plot, owner in pairs(plots) do
		if owner == nil then
			plots[plot] = player
			ownedPlot[player] = plot
			plot:SetAttribute("OwnerUserId", player.UserId)
			return plot
		end
	end
	return nil -- server full relative to plot count
end

local function releasePlot(player)
	local plot = ownedPlot[player]
	if not plot then return end

	local structures = plot:FindFirstChild("Structures")
	if structures then
		structures:ClearAllChildren()
	end
	plot:SetAttribute("OwnerUserId", nil)
	plots[plot] = nil
	ownedPlot[player] = nil
end

-- ---------- public API ----------

function PlotService.GetPlot(player)
	return ownedPlot[player]
end

--- Called from the game's existing PlaceStructure RemoteFunction handler.
--- Returns the placed Model on success, nil + reason on failure.
function PlotService.PlaceStructure(player, structureName, position, rotationY)
	local plot = ownedPlot[player]
	if not plot then
		return nil, "no_plot"
	end

	local cost = STRUCTURE_COSTS[structureName]
	local template = cost and ReplicatedStorage.Structures:FindFirstChild(structureName)
	if not template then
		return nil, "unknown_structure" -- client sent something not in the catalog
	end

	local worldPos = snapToPlot(plot, position)
	if not worldPos then
		return nil, "out_of_bounds"
	end

	-- Charge before spawning; SpendCoins is atomic so double-fire can't dupe.
	if not DataService.SpendCoins(player, cost) then
		return nil, "cant_afford"
	end

	local structure = template:Clone()
	structure:PivotTo(CFrame.new(worldPos) * CFrame.Angles(0, math.rad(rotationY or 0), 0))
	structure:SetAttribute("OwnerUserId", player.UserId)
	structure.Parent = plot.Structures

	return structure
end

-- ---------- init ----------

for _, plot in ipairs(workspace.Plots:GetChildren()) do
	plots[plot] = nil
	if not plot:FindFirstChild("Structures") then
		local folder = Instance.new("Folder")
		folder.Name = "Structures"
		folder.Parent = plot
	end
end

Players.PlayerAdded:Connect(assignPlot)
Players.PlayerRemoving:Connect(releasePlot)

return PlotService
