-- Minehe WWW server
package.loaded["network"] = nil
local net = require("network")
local fs = require("filesystem")
local sec = require("security")

local config = {
	transport = "modem", -- Implementation of OSI 4 layer
	wwwpath = "Users/Shared/www"
}

print("Very Basic 1.0 OHTP Server")
if not sec.hasPermission("network.listen") then
	sec.requestPermission("network.listen")
	sec.requestPermission("network.open")
end
print("Listening..")

while true do
	local sock = net.listen(80, config.transport)
	shin32.newProcess("Client-Thread", function() -- use processes as threads
		local ctn = sock:read()
		local resp = ""
		local lines = string.split(ctn, '\n')
		local header = string.split(lines[1], ' ')
		local method = header[2]
		local path = header[3]
		if header[1] == "OHTP/1.0" then
			if method == "GET" then
				if not fs.exists(config.wwwpath .. path) then
					resp = "404"
				else
					local s = io.open(config.wwwpath .. path)
					local c = s:read("a")
					s:close()
					resp = "200\n\n" .. c
				end
			end
		end
		sock:write(resp)
	end)
end