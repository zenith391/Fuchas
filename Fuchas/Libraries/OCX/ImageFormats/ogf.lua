local format = {}
local buffer = require("buffer")

function format:getType()
	return "raster"
end

function format:isSupported(file)
	local signature = file:read(8)
	local version = string.byte(file:read(1))
	return signature == "OGFIMAG\x03" and version == 2
end

function format:decode(file)
	file:read(9) -- skip signature and version
	file:read(1) -- skip flags

	local numEntries = string.byte(file:read(1))
	for i=1, numEntries do
		local type = string.unpack("<I1", file:read(1))
		local length = string.unpack("<I4", file:read(4))
		file:seek("cur", length)
	end
end

function format:encode(file, image)
	file:write("OGFIMAG\x03") -- signature
	file:write("\x02") -- version
	file:write("\x00") -- flags: image is not animated
	file:write("\x01") -- only one entry: Bitmap Image Data

	local entry = buffer.fromString("")
	entry:write(string.pack("<I2", image.width))
	entry:write(string.pack("<I2", image.height))
	entry:write(string.pack("<I1", 3)) -- bit depth = 24-bit
	entry:write(string.pack("<I1", 0)) -- no compression
	entry:write(string.pack("<I4", 0)) -- 0 offset = no palette

	entry:write(string.pack("<I4", image.width * image.height)) -- byte length
	for _, char in pairs(image.chars) do
		entry:write()
	end


	file:write(string.pack("<I1", 3)) -- entry type 3: Bitmap Image Data
	file:write(string.pack("<I4", entry.data:len()))
	file:write(entry.data)
end 

return format
