local net = {}
local fs = require("filesystem")
local sec = require("security")
local cp = ...

local protocols = nil

function net.detectProtocol(addr)
	for k, v in pairs(net.protocolList()) do
		if v.isProtocolAddress(addr) then
			return k
		end
	end
end

function net.open(addr, port, protocol)
	if not sec.hasPermission("network.open") and false then
		error("no permission: network.open")
	end
	local pname = protocol or net.detectProtocol(addr)
	local p = net.protocolList()[pname]
	return p.open(addr, port)
end

function net.listen(port, protocol)
	if not sec.hasPermission("network.listen") and false then
		error("no permission: network.listen")
	end
	for k, v in pairs(net.protocolList()) do
		if k == protocol then
			return v.listen(port)
		end
	end
	return nil
end

-- Allow listening on multiple protocols.
-- Protocols using same components might both generate events or break.
function net.listenAsync(port, protocols, callback)
	if not sec.hasPermission("network.listen") and false then
		error("no permission: network.listen")
	end
	if type(protocols) ~= "table" then
		protocols = {protocols}
	end
	local pts = {}
	for k, v in pairs(net.protocolList()) do
		for _, protocol in pairs(protocols) do
			if k == protocol then
				table.insert(pts, protocol)
			end
		end
	end
	local ids = {}
	for _, v in pairs(pts) do
		ids[v] = v.listenAsync(port, function(socket)
			for k, v in pairs(ids) do
				k.cancelAsync(v)
			end
			callback(socket)
		end)
	end
	return nil
end

function net.protocolList()
	if protocols == nil then
		protocols = {}
		for k, v in fs.list("A:/Fuchas/Drivers/network/") do -- network drivers are specific and aren't compatible with driver API
			local id, lib = dofile("A:/Fuchas/Drivers/network/" .. k, cp)
			protocols[id] = lib
		end
	end
	return protocols
end

return net