--[[
	ObjectPool
	Reuse instances for high-churn effects (shell casings, debris, hit VFX)
	instead of hammering Instance.new/Destroy every frame.

		local casingPool = ObjectPool.new(casingTemplate, 50)

		local casing = casingPool:Get()
		casing.CFrame = muzzle.CFrame
		task.delay(2, function()
			casingPool:Return(casing)
		end)
]]

local ObjectPool = {}
ObjectPool.__index = ObjectPool

-- Pooled instances park here instead of nil-parenting, so physics and
-- rendering fully stop between uses.
local storage = Instance.new("Folder")
storage.Name = "_PoolStorage"
storage.Parent = game:GetService("ServerStorage")

function ObjectPool.new(template, initialSize)
	local self = setmetatable({
		_template = template,
		_available = {},
		_inUse = {},
	}, ObjectPool)

	for _ = 1, initialSize or 0 do
		local instance = template:Clone()
		instance.Parent = storage
		table.insert(self._available, instance)
	end

	return self
end

function ObjectPool:Get()
	local instance = table.remove(self._available)
	if not instance then
		instance = self._template:Clone() -- pool grows on demand
	end

	self._inUse[instance] = true
	instance.Parent = workspace
	return instance
end

function ObjectPool:Return(instance)
	if not self._inUse[instance] then
		return -- already returned (or never ours) — double-Return is a no-op
	end

	self._inUse[instance] = nil
	if instance:IsA("BasePart") then
		instance.AssemblyLinearVelocity = Vector3.zero
		instance.AssemblyAngularVelocity = Vector3.zero
	end
	instance.Parent = storage
	table.insert(self._available, instance)
end

function ObjectPool:Destroy()
	for _, instance in ipairs(self._available) do
		instance:Destroy()
	end
	for instance in pairs(self._inUse) do
		instance:Destroy()
	end
	table.clear(self._available)
	table.clear(self._inUse)
end

return ObjectPool
