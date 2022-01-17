local format = {}
local buffer = require("buffer")

function format:getType()
	return "oc"
end

function format:getExtension()
	return "ogf"
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
		local data = file:read(length)
		local entry = buffer.fromString(data)
		if type == 2 then
			local width = string.unpack("<I2", entry:read(2))
			local height = string.unpack("<I2", entry:read(2))
			local bitDepth = string.unpack("<I1", entry:read(1))
			local compression = string.unpack("<I1", entry:read(1))
			local palette = string.unpack("<I4", entry:read(4))
			if bitDepth ~= 3 then
				error("unsupported bit depth: " .. bitDepth)
			elseif compression ~= 0 then
				error("compression not supported")
			elseif palette ~= 0 then
				error("palette not supported")
			end

			local textLength = string.unpack("<I4", entry:read(4))
			local text = entry:read(textLength)
			local chars = {}
			local imageSize = width * height
			local i = 1
			for p, c in utf8.codes(text) do
				chars[i] = utf8.char(c)
				i = i + 1
			end

			local backgrounds = {}
			for i=1, imageSize do
				local rgb = string.unpack("<I3", entry:read(3))
				table.insert(backgrounds, rgb)
			end

			local foregrounds = {}
			for i=1, imageSize do
				local rgb = string.unpack("<I3", entry:read(3))
				table.insert(foregrounds, rgb)
			end

			return {
				width = width,
				height = height,
				backgrounds = backgrounds,
				foregrounds = foregrounds,
				chars = chars,
				hasAlpha = false,
				bpp = 8
			}
		else
			error("unsupported entry type: " .. type)
		end
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

	local charsBuf = buffer.fromString("")
	for _, char in pairs(image.chars) do
		charsBuf:write(char)
	end
	entry:write(string.pack("<I4", charsBuf.data:len()))
	entry:write(charsBuf.data)

	for _, bg in pairs(image.backgrounds) do
		entry:write(string.pack("<I3", bg))
	end

	for _, fg in pairs(image.foregrounds) do
		entry:write(string.pack("<I3", fg))
	end

	file:write(string.pack("<I1", 2)) -- entry type 2: OC Image Data
	file:write(string.pack("<I4", entry.data:len()))
	file:write(entry.data)
end 

return format
