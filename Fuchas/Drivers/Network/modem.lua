-- Modem network lib, trying to be most compatible with legacy app using direct "modem" network and
-- the new socket object aspect used by network library
local protocol = {}
local event = require("event")

function protocol.isProtocolAddress(addr)
	return addr:len() == 36 -- todo: more checks
end

function protocol.listen(port)
	local modem = component.modem
	local sock = {}
	modem.open(port)
	while true do
		local sig = table.pack(event.pull())
		local name, sender, p = sig[1], sig[3], sig[4]
		if name == "modem_message" and p == port then
			sock = protocol.open(sender, p)
			sock.rbuf = sig[5]
			break
		end
	end
	return sock
end

function protocol.open(addr, dport)
	component.modem.open(dport)
	return {
		modem = component.getPrimary("modem"),
		rbuf = nil,
		dest = addr,
		port = dport,
		close = function(self)
			modem.close(self.port)
		end,
		write = function(self, ...)
			if dest == "ffffffff-ffff-ffff-ffff-ffffffffffff" then  -- broadcast address
				self.modem.broadcast(self.port, ...)
			else
				self.modem.send(self.dest, self.port, ...)
			end
		end,
		read = function(self)
			if self.rbuf ~= nil then
				local r = self.rbuf
				self.rbuf = nil
				return r
			end
			while true do
				local sig = table.pack(event.pull())
				if sig[1] == "modem_message" and sig[3] == self.dest and sig[4] == self.port then -- if is from destination/receiver and same port
					return sig[5]
				end
			end
		end
	}
end

return "modem", protocol