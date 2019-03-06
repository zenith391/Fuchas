local drv = {}
local int = component.getPrimary("internet")
local fs = require("filesystem")

function drv.httpDownload(url, dest)
	local h = int.request(url)
	h:finishConnect()
	local file = fs.open(dest, "w")
	local data = ""
	while data ~= nil do
		local data = h:read()
		file:write(data)
	end
	file:close()
	h:close()
end

return component.isAvailable("internet"), drv