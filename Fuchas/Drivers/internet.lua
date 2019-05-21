local drv = {}
local int = component.getPrimary("internet")
local fs = require("filesystem")

function drv.httpDownload(url, dest)
	local h = int.request(url)
	h.finishConnect()
	local file = fs.open(dest, "w")
	local data = ""
	while data ~= nil do
		file:write(data)
		local data = h.read()
	end
	file.close()
	h.close()
end

function drv.readFully(url)
	local h = int.request(url)
	h.finishConnect()
	local buf = ""
	local data = ""
	while data ~= nil do
		buf = buf .. data
		data = h.read()
	end
	h.close()
	return buf
end

return component.isAvailable("internet"), drv