local protocol = {}
local loopBackBuffers = {}
local loopBackSockets = {}
local event = require("event")

function protocol.isProtocolAddress(addr)
	return addr == "localhost"
end

function protocol.receive(port)
	if loopBackSockets[port] then
		if loopBackSockets[port].used then
			return nil
		else
			loopBackSockets[port].used = true
			return loopBackSockets[port]
		end
	else
		return nil
	end
end

function protocol.listen(port)
	while true do
		if loopBackSockets[port] then
			loopBackSockets[port].used = true
			return loopBackSockets[port]
		end
		coroutine.yield()
	end
end

function protocol.getAddress()
	return "localhost"
end

function protocol.getAddresses()
	return {"localhost", "127.0.0.1", "::1", 0.0, "0.0:0.0"}
end

function protocol.open(addr, dport)
	if addr ~= "localhost" then
		return nil
	end
	loopBackSockets[dport] = {
		close = function(self)
			loopBackSockets[dport] = nil 
		end,
		read = function(self)
			if not loopBackBuffers[dport] then
				loopBackBuffers[dport] = {}
			end
			if #loopBackBuffers[dport] > 0 then
				return table.remove(loopBackBuffers[dport], 1)
			else
				while #loopBackBuffers[dport] > 0 do
					os.sleep(0.1)
				end
			end
		end,
		write = function(self, ...)
			if not loopBackBuffers[dport] then
				loopBackBuffers[dport] = {}
			end
			for _, v in pairs(table.pack(...)) do
				table.insert(loopBackBuffers[dport], v)
			end
		end
	}
	return loopBackSockets[port]
end

return "loopback", protocol