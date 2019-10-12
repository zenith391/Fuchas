local primaries = {}
local vcomponents = {}

-- original component methods
local cp = component
local _list = component.list
local _type = component.type
local _proxy = component.proxy
local _doc = component.doc
local _methods = component.methods
local _slot = component.slot
local _proxy = component.proxy

function cp.list(filter)
	local list = _list(filter)
	for k, v in pairs(vcomponents) do
		if not filter or v.type == filter then
			list[k] = k.type
		end
	end
	return list
end

function cp.type(addr)
	for k, v in pairs(vcomponents) do
		if k == addr then
			return v.type
		end
	end
	return _type(addr)
end

function cp.proxy(addr)
	for k, v in pairs(vcomponents) do
		if k == addr then
			return v
		end
	end
	return _proxy(addr)
end

function cp.get(addr)
	for k, v in cp.list() do
		if string.startsWith(k, addr) then
			return k
		end
	end
	return nil
end

function cp.isConnected(addr)
	for k, v in pairs(cp.list()) do
		if k == addr then
			return true
		end
	end
	return false
end

function cp.isVirtual(addr)
	if cp.isConnected(addr) then
		return (cp.proxy.isvirtual == true)
	end
end

function cp.addVComponent(addr, proxy)
	proxy.isvirtual = true -- atleast know it's virtual
	vcomponents[addr] = proxy
end

function cp.removeVComponent(addr)
	vcomponents[addr] = nil
end

function cp.isAvailable(type)
	return cp.list(type)() ~= nil
end

function cp.getPrimary(type)
	if primaries[type] == nil then
		if cp.isAvailable(type) then -- if no primary component
			primaries[type] = cp.proxy(cp.list(type)())
		end
	else
		if not cp.isConnected(primaries[type].address) then -- if outdated primary component
			primaries[type] = cp.proxy(cp.list(type)())
		end
	end
	return primaries[type]
end

function cp.setPrimary(type, addr)
	if type(addr) == "string" then
		if not cp.isConnected(addr) then
			error("not connected: " .. addr)
		end
		primaries[type] = cp.proxy(addr)
	elseif type(addr) == "table" or type(addr) == "userdata" then
		primaries[type] = addr
	else
		error("unsupported argument #2: " .. type(addr))
	end
	primaries[type] = addr
end

local cp = component
setmetatable(cp, {
	__index = function(self, key)
		if cp.getPrimary(key) ~= nil then
			return cp.getPrimary(key)
		else
			return cp[key]
		end
	end,
	-- component.gpu: Return component.getPrimary("gpu") if available
	-- component.getPrimary: Return getPrimary function
	__newindex = function(self, key, value)
		if self[key] == nil or cp.getPrimary(key) ~= nil then
			cp.setPrimary(key, value)
		end
	end
	-- component.gpu = addr/proxy: Act same as component.setPrimary("gpu", addr/proxy)
	-- component.xlodkzek = proxy: Also works to set as primary (virtual) component
})

component = setmetatable({}, {
	__index = function(self, key)
		local sec = require("security")
		if sec.hasPermission("critical.component.get") then
			return cp[key]
		else
			error("Not enough permission to access component")
		end
	end,
	__newindex = function(self, key, value)
		local sec = require("security")
		if sec.hasPermission("critical.component.set") then
			cp[key] = value
		end
	end
})

package.loaded["driver"] = dofile("A:/Fuchas/Libraries/driver.lua", cp)
package.loaded["component"] = component
-- Driver need to be inited here in order to pass original component lib