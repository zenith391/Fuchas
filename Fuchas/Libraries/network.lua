local net = {}
local fs = require("filesystem")
local sec = require("security")

local protocols = nil

function net.detectProtocol(addr)
	for k, v in pairs(net.protocolList()) do
		if v.isProtocolAddress(addr) then
			return k
		end
	end
end

function net.open(addr, port, protocol)
	if not sec.hasPermission("network.open") then
		error("no permission: network.open")
	end
	local pname = protocol or net.detectProtocol(addr)
	local p = net.protocolList()[pname]
	return p.open(addr, port)
end

function net.listen(port, protocol)
	if not sec.hasPermission("network.listen") then
		error("no permission: network.listen")
	end
	for k, v in pairs(net.protocolList()) do
		if k == protocol then
			return v.listen(port)
		end
	end
	return nil
end

function net.protocolList()
	if protocols == nil then
		protocols = {}
		for k, v in fs.list("A:/Fuchas/Drivers/network/") do -- network drivers are specific and aren't compatible with driver API
			local id, lib = dofile("A:/Fuchas/Drivers/network/" .. k)
			protocols[id] = lib
		end
	end
	return protocols
end

return net