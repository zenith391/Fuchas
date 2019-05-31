-- Minehe WWW server
package.loaded["network"] = nil
local net = require("network")

local config = {
	transport = "modem" -- Implementation of OSI 4 layer
}

local sock = net.listen(80, config.transport)