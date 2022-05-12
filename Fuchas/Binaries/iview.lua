-- Image viewing program, most code is derived from my OpenComputers subpixel test
local shell = require("shell")
local filesystem = require("filesystem")
local gpu = require("driver").gpu

local args, opts = shell.parse(...)
local verbose = opts.v or opts.verbose

if opts["h"] or opts["help"] then
	print("iview <file>")
	print("  --advanced-dithering: when enabled, the GPU palette is accounted for in dithering, this considerably slow downs rendering")
	print("                        implies the '--dithering' flag")
	print("  --dithering=[none/basic/floyd-steinberg]: this selects a dithering method")
	print("  --grayscale: convert image to grayscale")
	print("  --monochrome: force image to be black and white")
	print("  -p / --change-palette: allow to change the palette to have more fitting colors")
	print("  -v / --verbose: print debug information")
	return
end

if #args < 1 then
	io.stderr:write("Usage: iview <file>\n")
	return
end

-- monochrome conflicts with advanced-dithering
if opts["monochrome"] then
	opts["advanced-dithering"] = nil
end

if not opts["dithering"] then opts["dithering"] = "floyd-steinberg" end
if opts["dithering"] ~= "none" and opts["dithering"] ~= "basic" and opts["dithering"] ~= "floyd-steinberg" then
	io.stderr:write("invalid dithering method: '" .. opts["dithering"] .. "', expected: none / basic / floyd-steinberg\n")
	return
end

local file = shell.resolve(args[1])
if not file then
	io.stderr:write("No such file: " .. args[1] .. "\n")
	return
end

local function verbosePrint(text)
	if verbose then print(text) end
end

verbosePrint("Dithering method: " .. opts["dithering"])

local function brailleCharRaw(a, b, c, d, e, f, g, h)
	return 10240 + 128 * h + 64 * g + 32 * f + 16 * d + 8 * b + 4 * e + 2 * c + a
end

local function brailleChar(a, b, c, d, e, f, g, h) -- from MineOS text.brailleChar
	return unicode.char(brailleCharRaw(a, b, c, d, e, f, g, h))
end

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

local function readBMP(file)
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

			if opts["grayscale"] then
				local avg = math.floor((0.2126*r + 0.7152*g + 0.0722*b))
				r = avg; g = avg; b = avg;
			end

			if a < 128 and alphaBitMask ~= 0 then -- atleast semi-transparent
				r = (BG_COLOR >> 16) & 0xFF
				g = (BG_COLOR >> 8)  & 0xFF
				b = BG_COLOR         & 0xFF
			end
			local rgb = (r << 16) | (g << 8) | b
			if not pixels[i] then pixels[i] = {} end
			pixels[i][j] = rgb
		end
		if width*3 % 4 ~= 0 then
			file:read(4 - width*3 % 4)
		end
	end

	return {
		width = width,
		height = height,
		pixels = pixels
	}
end

local function process(image)
	local chars = {}
	local carriedError = {}

	-- https://en.wikipedia.org/wiki/Color_difference
	local function distance(a, b)
		local dR, dG, dB = math.abs(a.r-b.r)^2, math.abs(a.g-b.g)^2, math.abs(a.b-b.b)^2
		if a.r + b.r < 128 then
			return 2 * dR + 4 * dG + 3 * dB
		else
			return 3 * dR + 4 * dG + 2 * dB
		end
	end

	local function fromRGB(a)
		local Ar = (a >> 16) & 0xFF
		local Ag = (a >> 8) & 0xFF
		local Ab = a & 0xFF
		return { r = Ar, g = Ag, b = Ab }
	end

	local function toRGB(a)
		if a.r < 0 then a.r = 0 end
		if a.g < 0 then a.g = 0 end
		if a.b < 0 then a.b = 0 end
		if a.r > 255 then a.r = 255 end
		if a.g > 255 then a.g = 255 end
		if a.b > 255 then a.b = 255 end
		return (math.floor(a.r) << 16) | (math.floor(a.g) << 8) | math.floor(a.b)
	end

	local function toString(a)
		return string.format("0x%x 0x%x 0x%x", a.r, a.g, a.b)
	end

	local function add(a, b)
		return { r = a.r + b.r, g = a.g + b.g, b = a.b + b.b }
	end

	local function sub(a, b)
		return { r = a.r - b.r, g = a.g - b.g, b = a.b - b.b }
	end

	local function mulScalar(a, scalar)
		return { r = math.ceil(a.r * scalar), g = math.ceil(a.g * scalar), b = math.ceil(a.b * scalar) }
	end

	for x=1, image.width do
		--for y=1, image.height do
			if not carriedError[x] then carriedError[x] = {} end
		--end
	end

	local start = computer.uptime()
	if opts["p"] or opts["change-palette"] then
		--[[local allColorsOccurances = {}
		for y=1, image.height do
			if computer.uptime() > start + 1 then -- avoid 'too long without yielding'
				coroutine.yield()
				start = computer.uptime()
			end
			for x=1, image.width do
				local rgb = image.pixels[x][y]
				allColorsOccurances[rgb] = (allColorsOccurances[rgb] or 0) + 1
			end
		end
		local allPalette = {}
		for rgb, num in pairs(allColorsOccurances) do
			table.insert(allPalette, { rgb = rgb, num = num })
		end
		table.sort(allPalette, function(a, b)
			return a.num < b.num
		end)--]]
		local averages = {}
		for i=1, gpu.getPalettedColors() do averages[i] = 0x000000 end

		for y=1, image.height do
			if computer.uptime() > start + 1 then -- avoid 'too long without yielding'
				coroutine.yield()
				start = computer.uptime()
			end
			for x=1, image.width do
				local rgb = image.pixels[x][y]
				for i=1, gpu.getPalettedColors() do
					-- the influence of the current pixel on the average
					local t = 1 / (i^2)
					local avg = fromRGB(averages[i])
					avg = add(
						mulScalar(avg, 1 - t),
						mulScalar(fromRGB(rgb), t)
					)
					averages[i] = toRGB(avg)
				end
			end
		end

		for i=1, math.min(#averages, gpu.getPalettedColors()) do
			--gpu.palette[i] = allPalette[i].rgb
			gpu.palette[i] = averages[i]
		end
	end

	local gpuPalette = {}
	verbosePrint(tostring(gpu.getColors()) .. " colors available")
	for i=1, gpu.getColors() do
		gpuPalette[i] = fromRGB(gpu.palette[i])
	end
	for y=1, image.height, 4 do
		if computer.uptime() > start + 1 then -- avoid 'too long without yielding'
			coroutine.yield()
			start = computer.uptime()
		end
		for x=1, image.width, 2 do
			local colorsOccurances = {}
			for dy=0, 3 do
				for dx=0, 1 do
					local rgb = image.pixels[x+dx][y+dy]
					--local error = carriedError[x+dx][y+dy] or {r=0,g=0,b=0}
					--rgb = toRGB(add(fromRGB(rgb), error))

					if opts["advanced-dithering"] then
						local error = carriedError[x+dx][y+dy] or {r=0,g=0,b=0}
						rgb = fromRGB(rgb)
						rgb = add(rgb, error)

						local closest = 0
						local closestDist = math.huge
						for i=1, gpu.getColors() do
							if distance(gpuPalette[i], rgb) < closestDist then
								closest = gpuPalette[i]
								closestDist = distance(gpuPalette[i], rgb)
							end
						end
						rgb = toRGB(closest)
					end

					colorsOccurances[rgb] = (colorsOccurances[rgb] or 0) + 1
				end
			end
			local sortedColors = {}
			for rgb, num in pairs(colorsOccurances) do
				table.insert(sortedColors, { rgb = rgb, num = num })
			end
			table.sort(sortedColors, function(a, b)
				return a.num > b.num
			end)
			local mostCommonColor = sortedColors[1].rgb
			local secondMostCommonColor = (sortedColors[2] or sortedColors[1]).rgb

			if opts["monochrome"] then
				mostCommonColor = 0x000000
				secondMostCommonColor = 0xffffff
			end
			mostCommonColor = fromRGB(mostCommonColor)
			secondMostCommonColor = fromRGB(secondMostCommonColor)

			local usedColors = {}
			for dy=0, 3 do
				for dx=0, 1 do
					local rgb = fromRGB(image.pixels[x+dx][y+dy])
					local error = carriedError[x+dx][y+dy] or { r = 0, g = 0, b = 0 }
					rgb = add(rgb, error)
					--carriedError[x+dx][y+dx] = nil -- remove when unused
					local pos = dx + dy * 2 + 1
					local pixelError = 0
					if distance(rgb, mostCommonColor) < distance(rgb, secondMostCommonColor) then
						usedColors[pos] = 1 -- foreground == mostCommonColor
						pixelError = sub(rgb, mostCommonColor)
					else
						usedColors[pos] = 0 -- background == secondMostCommonColor
						pixelError = sub(rgb, secondMostCommonColor)
					end
					pixelError = mulScalar(pixelError, 1/2)

					if opts["dithering"] == "floyd-steinberg" then
						if carriedError[x+dx+1] then -- right
							if not carriedError[x+dx+1][y+dy] then carriedError[x+dx+1][y+dy] = { r = 0, g = 0, b = 0 } end
							carriedError[x+dx+1][y+dy] = add(carriedError[x+dx+1][y+dy], mulScalar(pixelError, 7/16))
						end

						if carriedError[x+dx+1] then -- down right
							if not carriedError[x+dx+1][y+dy+1] then carriedError[x+dx+1][y+dy+1] = { r = 0, g = 0, b = 0 } end
							carriedError[x+dx+1][y+dy+1] = add(carriedError[x+dx+1][y+dy+1], mulScalar(pixelError, 1/16))
						end

						if carriedError[x+dx-1] then -- down left
							if not carriedError[x+dx-1][y+dy+1] then carriedError[x+dx-1][y+dy+1] = { r = 0, g = 0, b = 0 } end
							carriedError[x+dx-1][y+dy+1] = add(carriedError[x+dx-1][y+dy+1], mulScalar(pixelError, 3/16))
						end

						if carriedError[x+dx][y+dy+1] then -- down
							if not carriedError[x+dx][y+dy+1] then carriedError[x+dx][y+dy+1] = { r = 0, g = 0, b = 0 } end
							carriedError[x+dx][y+dy+1] = add(carriedError[x+dx][y+dy+1], mulScalar(pixelError, 5/16))
						end
					elseif opts["dithering"] == "basic" then
						if carriedError[x+dx+1] and carriedError[x+dx+1][y+dy] then -- right
							if not carriedError[x+dx+1][y+dy] then carriedError[x+dx+1][y+dy] = { r = 0, g = 0, b = 0 } end
							carriedError[x+dx+1][y+dy] = add(carriedError[x+dx+1][y+dy], pixelError)
						end
					end
				end
			end

			local cx, cy = (x-1) // 2 + 1, (y-1) // 4 + 1
			if not chars[cx] then chars[cx] = {} end
			chars[cx][cy] = {
				char = brailleChar(table.unpack(usedColors)),
				fg = toRGB(mostCommonColor),
				bg = toRGB(secondMostCommonColor)
			}
		end
	end

	--error("carried error[1][1] = " .. toString(carriedError[10][10]))

	chars.width = image.width // 2
	chars.height = image.height // 4
	return chars
end

local function drawImage(image, x, y)
	local chars = process(image)

	for iy=1, chars.height do
		for ix=1, chars.width do
			gpu.setColor(chars[ix][iy].bg)
			gpu.setForeground(chars[ix][iy].fg)
			gpu.drawText(x + ix - 1, y + iy - 1, chars[ix][iy].char)
		end
	end

	return buffer
end

local stream = io.open(file, "r")
--io.stdout:write(stream:read("a"))
if string.endsWith(file, ".bmp") then
	local image = readBMP(stream)
	local charHeight = image.height // 4
	for i=1, charHeight do print() end

	local x, y = shell.getCursor()
	y = y - charHeight
	drawImage(image, x, y)
end
stream:close()
