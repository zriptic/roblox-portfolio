-- ObjectPool
-- Reuse instances for high churn effects instead of Instance.new/Destroy spam

local ServerStorage = game:GetService("ServerStorage")

local ObjectPool = {}
ObjectPool.__index = ObjectPool

local PoolStorage = Instance.new("Folder")
PoolStorage.Name = "PoolStorage"
PoolStorage.Parent = ServerStorage

function ObjectPool.new(template, startCount)
	local self = setmetatable({
		Template = template,
		Available = {},
		InUse = {},
	}, ObjectPool)
	for _ = 1, startCount or 0 do
		local instance = template:Clone()
		instance.Parent = PoolStorage
		table.insert(self.Available, instance)
	end
	return self
end

function ObjectPool:Get()
	local instance = table.remove(self.Available) or self.Template:Clone()
	self.InUse[instance] = true
	instance.Parent = workspace
	return instance
end

function ObjectPool:Return(instance)
	if not self.InUse[instance] then return end
	self.InUse[instance] = nil
	if instance:IsA("BasePart") then
		instance.AssemblyLinearVelocity = Vector3.zero
		instance.AssemblyAngularVelocity = Vector3.zero
	end
	instance.Parent = PoolStorage
	table.insert(self.Available, instance)
end

function ObjectPool:Destroy()
	for _, instance in ipairs(self.Available) do
		instance:Destroy()
	end
	for instance in pairs(self.InUse) do
		instance:Destroy()
	end
	table.clear(self.Available)
	table.clear(self.InUse)
end

return ObjectPool
