local protocol = {}
local event = require("event")
local listenedPorts = {}
local component = component
local int = component.internet

function protocol.isProtocolAddress(addr)
	local s = string.split(addr, ".")
	if #s == 4 then -- TODO more check
		return true -- IPv4
	else
		return false -- TODO: detect IPv6
	end
end

function protocol.cancelAsync(id)
	error("unsupported operation")
end

function protocol.listenAsync(port, callback)
	error("unsupported operation")
end

function protocol.listen(port)
	error("unsupported operation")
end

function protocol.getAddress()
	return nil -- unknown
end

function protocol.setComponentAddress(address)
	if component.type(address) ~= "internet" then
		error("invalid component")
	end
	int = component.proxy(address)
end

function protocol.getComponentAddress()
	if int then
		return int.address
	else
		return nil
	end
end

function protocol.getAddresses()
	return {} -- unknown
end

function protocol.open(addr, port)
	local handle = int.connect(addr, port)
	local ok, err = handle.finishConnect()
	if not ok then
		error("could not open socket: " .. err)
	end
	return {
		dest = addr,
		port = port,
		close = function(self)
			handle.close()
		end,
		write = function(self, ...)
			handle.write(...)
		end,
		read = function(self, n)
			return handle.read(n)
		end
	}
end

return "internet", protocol
