-- Modem network lib, trying to be most compatible with 
local protocol = {}
local event = require("event")

function protocol.isProtocolAddress(addr)
	return table.maxn(string.split(addr, ".")) == 4 -- IPv4
end

function protocol.listen(port)
	
end

function protocol.open(addr, dport)
	
end

return "internet", protocol