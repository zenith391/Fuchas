local spec = {}
local fs = require("filesystem")
local cp = ...

function spec.getRank()
	return 1
end

function spec.getName()
	return "EnderNet Conformity 2000"
end

function drv.isCompatible(address)
	return cp.proxy(address).type == "internet"
end

function spec.new(address)
	local drv = {}
	local int = cp.proxy(address)

	function drv.httpDownload(url, dest)
		local h = int.request(url)
		h.finishConnect()
		local file = fs.open(dest, "w")
		local data = ""
		while data ~= nil do
			file:write(data)
			data = h.read()
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

	return drv
end

return drv 
