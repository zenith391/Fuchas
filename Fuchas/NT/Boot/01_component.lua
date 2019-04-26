local primaries = {}

function component.isAvailable(type)
	return component.list(type)() ~= nil
end

function component.isConnected(addr)
	for k, v in component.list() do
		if k == addr then
			return true
		end
	end
	return false
end

function component.getPrimary(type)
	if primaries[type] == nil then
		if component.isAvailable(type) then -- if no primary component
			primaries[type] = component.proxy(component.list(type)())
		end
	else
		if not component.isConnected(primaries[type].address) then -- if outdated primary component
			primaries[type] = component.proxy(component.list(type)())
		end
	end
	return primaries[type]
end

function component.setPrimary(type, addr)
	if type(addr) == "string" then
		if not component.isConnected(addr) then
			error("not connected: " .. addr)
		end
		primaries[type] = component.proxy(addr)
	elseif type(addr) == "table" or type(addr) == "userdata" then
		primaries[type] = addr
	else
		error("unsupported argument #2: " .. type(addr))
	end
	primaries[type] = addr
end

setmetatable(component, {
	__index = function(self, key)
		if component.getPrimary(key) ~= nil then
			return component.getPrimary(key)
		else
			return component[key]
		end
	end,
	-- component.gpu: Return component.getPrimary("gpu") if available
	-- component.getPrimary: Return getPrimary function
	__newindex = function(self, key, value)
		if self[key] == nil or component.getPrimary(key) ~= nil then
			component.setPrimary(key, value)
		else
			error("component API is read-only")
		end
	end
	-- component.gpu = addr/proxy: Act same as component.setPrimary("gpu", addr/proxy)
	-- component.xlodkzek = proxy: Also works to set as primary (virtual) component
	-- component.setPrimary = function() ... end: Throws error
})