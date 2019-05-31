local net = {}
local fs = require("filesystem")

local protocols = nil

function net.detectProtocol(addr)
	for k, v in pairs(net.protocolList()) do
		if v.isProtocolAddress(addr) then
			return k
		end
	end
end

function net.open(addr, port, protocol)
	local pname = protocol or net.detectProtocol(addr)
	local p = net.protocolList()[pname]
	return p.open(addr, port)
end

function net.listen(port, protocol)
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
		for k, v in fs.list("A:/Fuchas/Drivers/Network/") do
			local id, lib = dofile("A:/Fuchas/Drivers/Network/" .. k)
			protocols[id] = lib
		end
	end
	return protocols
end

return net