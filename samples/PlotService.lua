-- PlotService
-- Plot assignment + structure placement, all validated server side

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)

local StructureCosts = {
	House = 100,
	Turret = 350,
	Wall = 25,
	Generator = 500,
}
local GridSize = 4

local PlotService = {}
local PlotOwners = {} -- [plot] = player
local OwnedPlot = {} -- [player] = plot

local function snapToPlot(plot, position)
	local base = plot.Base
	local localPos = base.CFrame:PointToObjectSpace(position)
	if math.abs(localPos.X) > base.Size.X / 2 or math.abs(localPos.Z) > base.Size.Z / 2 then
		return nil
	end
	local snapped = Vector3.new(
		math.round(localPos.X / GridSize) * GridSize,
		base.Size.Y / 2,
		math.round(localPos.Z / GridSize) * GridSize
	)
	return base.CFrame:PointToWorldSpace(snapped)
end

-- Player Join Plot Setup
local function assignPlot(player)
	for _, plot in ipairs(workspace.Plots:GetChildren()) do
		if not PlotOwners[plot] then
			PlotOwners[plot] = player
			OwnedPlot[player] = plot
			plot:SetAttribute("OwnerUserId", player.UserId)
			return plot
		end
	end
end

local function releasePlot(player)
	local plot = OwnedPlot[player]
	if not plot then return end
	plot.Structures:ClearAllChildren()
	plot:SetAttribute("OwnerUserId", nil)
	PlotOwners[plot] = nil
	OwnedPlot[player] = nil
end

function PlotService.GetPlot(player)
	return OwnedPlot[player]
end

-- Called from the game's existing PlaceStructure remote handler
function PlotService.PlaceStructure(player, structureName, position, rotationY)
	local plot = OwnedPlot[player]
	if not plot then
		return nil, "no_plot"
	end
	local cost = StructureCosts[structureName]
	local template = cost and ReplicatedStorage.Structures:FindFirstChild(structureName)
	if not template then
		return nil, "unknown_structure"
	end
	local worldPos = snapToPlot(plot, position)
	if not worldPos then
		return nil, "out_of_bounds"
	end
	if not DataService.SpendCoins(player, cost) then
		return nil, "cant_afford"
	end
	local structure = template:Clone()
	structure:PivotTo(CFrame.new(worldPos) * CFrame.Angles(0, math.rad(rotationY or 0), 0))
	structure:SetAttribute("OwnerUserId", player.UserId)
	structure.Parent = plot.Structures
	return structure
end

Players.PlayerAdded:Connect(assignPlot)
Players.PlayerRemoving:Connect(releasePlot)

return PlotService
