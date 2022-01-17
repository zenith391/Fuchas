local format = {}

function format:getType()
	return "raster"
end

function format:getExtension()
	return "bmp"
end

function format:isSupported(file)
	local signature = file:read(2)
	return signature == "BM"
end

function format:decode(file)
	local function trailingZeroBits(bitmask)
		local copy = bitmask
		local bits = 0
		while (copy & 1) == 0 do
			copy = copy >> 1
			bits = bits + 1
			if bits > 32 then
				return 0
			end
		end
		return bits
	end

	-- color used for transparency
	local BG_COLOR = 0x000000

	file:read(10) -- skip over unused data
	local pixelStart = string.unpack("<I4", file:read(4))
	local dibSize = string.unpack("<I4", file:read(4))
	local width = string.unpack("<i4", file:read(4))
	local height = string.unpack("<i4", file:read(4))
	file:read(2) -- color planes
	local bpp = string.unpack("<I2", file:read(2))
	local bytes = math.ceil(bpp / 8)
	local compressionMethod = string.unpack("<I4", file:read(4))
	file:read(20) -- read unused data
	local redBitMask   = 0x000000FF
	local greenBitMask = 0x0000FF00
	local blueBitMask  = 0x00FF0000
	local alphaBitMask = 0xFF000000
	local redShift = 0
	local greenShift = 8
	local blueShift = 16
	local alphaShift = 24
	if dibSize == 124 and compressionMethod == 3 then -- BITMAPV5HEADER and BI_BITFIELDS
		redBitMask = string.unpack(">I4", file:read(4))
		greenBitMask = string.unpack(">I4", file:read(4))
		blueBitMask = string.unpack(">I4", file:read(4))
		alphaBitMask = string.unpack(">I4", file:read(4))
		redShift = trailingZeroBits(redBitMask)
		greenShift = trailingZeroBits(greenBitMask)
		blueShift = trailingZeroBits(blueBitMask)
		alphaShift = trailingZeroBits(alphaBitMask)
	end

	file:seek("set", pixelStart)
	local pixels = {}
	for j=height, 1, -1 do
		for i=1, width do
			local pixel = string.unpack(">I" .. bytes, file:read(bytes))
			local a = (bpp == 24 and 255) or (pixel & alphaBitMask) >> alphaShift
			local r = (pixel & redBitMask)   >> redShift
			local g = (pixel & greenBitMask) >> greenShift
			local b = (pixel & blueBitMask)  >> blueShift

			--if opts["grayscale"] then
			--	local avg = math.floor((0.2126*r + 0.7152*g + 0.0722*b))
			--	r = avg; g = avg; b = avg;
			--end

			if a < 128 and alphaBitMask ~= 0 then -- atleast semi-transparent
				r = (BG_COLOR >> 16) & 0xFF
				g = (BG_COLOR >> 8)  & 0xFF
				b = BG_COLOR         & 0xFF
			end
			local rgb = (r << 16) | (g << 8) | b
			if not pixels[i] then pixels[i] = {} end
			pixels[(j-1)*width + i] = rgb
		end
		if width*bytes % 4 ~= 0 then
			file:read(4 - width*bytes % 4)
		end
	end

	return {
		width = width,
		height = height,
		pixels = pixels
	}
end

return format
