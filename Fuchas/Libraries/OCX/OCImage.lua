--- Library for loading, editing (scaling, color changes) and displaying raster and displayed (OC-adapted) images with OCDraw.
--- The difference between the two types of image is that a DisplayableImage uses characters, while a RasterImage is all pixels.
-- @module OCX.OCImage
-- @alias lib

local fs = require("filesystem")
-- TODO: use code from iview

local lib = {}
local formats = {}

--- Register a new image format
-- @tparam format format The image format to register
function lib.registerImageFormat(format)
	if format.isSupported == nil then
		error("no format: getSignature()")
	end
	table.insert(formats, format)
end

function lib.findFormat(ext)
	for _, format in pairs(formats) do
		if format:getExtension() == ext then
			return format
		end
	end
end

lib.registerImageFormat(require("OCX/ImageFormats/bmp"))
lib.registerImageFormat(require("OCX/ImageFormats/ogf"))

--- Detects the image format the given file is in or returns null if it corresponds to no registered image format
-- @tparam file file The file containing an image
-- @treturn ?format The detected image format
function lib.getFormat(file)
	for k, v in pairs(formats) do
		file:seek("set", 0)
		if v:isSupported(file) then
			file:seek("set", 0)
			return v
		end
	end
	return nil -- unknown
end

--- Creates a displayable image with the given parameters
-- @tparam int width The width of the image, or 1
-- @tparam int height The height of the image, or 1
-- @tparam[opt] int bpp The number of bits per pixel in the image, or 8
-- @tparam[opt] bool alpha The presence of an alpha channel, or false
-- @treturn DisplayableImage the newly created image
function lib.create(width, height, bpp, alpha)
	checkArg(1, width, "number")
	checkArg(2, height, "number")
	local img = {
		width = math.min(width, 1),
		height = math.min(height, 1),
		backgrounds = {},
		foregrounds = {},
		chars = {},
		alpha = alpha and {},
		hasAlpha = alpha or false,
		bpp = bpp or 8
	}
	return img
end

--- Converts a raster image into a displayable image. This is necessary in order to display a raster image.
-- @tparam RasterImage image The image to convert
-- @tab opts Image conversion options
-- @tparam[opt] bool opts.advancedDithering Whether to dither using the current GPU palette or by assuming all RGB colors are available.
--  Enabling this will result in a major slow down!
-- @tparam[opt] string opts.dithering The dithering method to use. Either "floyd-steinberg", "basic" or nil.
-- @treturn DisplayableImage the converted image
function lib.convertFromRaster(image, opts)
	local chars = {}
	local backgrounds = {}
	local foregrounds = {}

	local charsWidth = image.width // 2
	local charsHeight = image.height // 4

	local carriedError = {}

	local function brailleCharRaw(a, b, c, d, e, f, g, h)
		return 10240 + 128 * h + 64 * g + 32 * f + 16 * d + 8 * b + 4 * e + 2 * c + a
	end

	local function brailleChar(a, b, c, d, e, f, g, h) -- from MineOS text.brailleChar
		return unicode.char(brailleCharRaw(a, b, c, d, e, f, g, h))
	end

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
		return (a.r << 16) | (a.g << 8) | a.b
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
		for y=1, image.height do
			if not carriedError[x] then carriedError[x] = {} end
		end
	end

	local start = computer.uptime()

	local gpu
	local gpuPalette = {}
	if opts["advancedDithering"] then
		gpu = require("driver").gpu
		for i=1, gpu.getColors() do
			gpuPalette[i] = fromRGB(gpu.palette[i])
		end
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
					local fx, fy = x+dx, y+dy
					local rgb = image.pixels[(fy-1)*image.width + fx] or 0

					if opts["advancedDithering"] then
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
				return a.num < b.num
			end)
			local mostCommonColor = sortedColors[#sortedColors].rgb
			local secondMostCommonColor = (sortedColors[#sortedColors-1] or sortedColors[#sortedColors]).rgb
			mostCommonColor = fromRGB(mostCommonColor)
			secondMostCommonColor = fromRGB(secondMostCommonColor)

			local usedColors = {}
			for dy=0, 3 do
				for dx=0, 1 do
					local fx, fy = x+dx, y+dy
					local rgb = fromRGB(image.pixels[(fy-1)*image.width + fx] or 0)
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

					if opts.dithering == "floyd-steinberg" then
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
					elseif opts.dithering == "basic" then
						if carriedError[x+dx+1] and carriedError[x+dx+1][y+dy] then -- right
							if not carriedError[x+dx+1][y+dy] then carriedError[x+dx+1][y+dy] = { r = 0, g = 0, b = 0 } end
							carriedError[x+dx+1][y+dy] = add(carriedError[x+dx+1][y+dy], pixelError)
						end
					end
				end
			end

			local cx, cy = (x-1) // 2, (y-1) // 4
			local pos = cy * charsWidth + cx + 1
			chars[pos]       = brailleChar(table.unpack(usedColors))
			foregrounds[pos] = toRGB(mostCommonColor)
			backgrounds[pos] = toRGB(secondMostCommonColor)
		end
	end

	return {
		width = charsWidth,
		height = charsHeight,
		backgrounds = backgrounds,
		foregrounds = foregrounds,
		chars = chars,
		hasAlpha = false,
		bpp = 8
	}
end

--- Scales a raster image to the given dimensions, this uses nearest neighbour scaling.
-- @tparam RasterImage image The image to be scaled
-- @tparam int tw The new width of the image
-- @tparam int th The new height of the image
-- @treturn RasterImage The scaled image
function lib.scale(image, tw, th)
	if image.width == tw and image.height == th then
		return image
	end
	local pixels = {}
	local hScale = tw / image.width
	local vScale = th / image.height
	for y=1, th do
		for x=1, tw do
			local pos = (y-1) * tw + (x-1) + 1
			pixels[pos] = 0x2D2D2D
		end
	end

	for y=1, image.height do
		for x=1, image.width do
			local nx = math.floor((x-1) * hScale)
			local ny = math.floor((y-1) * vScale)
			local pos = (y-1) * image.width + (x-1) + 1
			for dx=1, math.ceil(hScale) do
				for dy=1, math.ceil(vScale) do
					local npos = (ny+dy-1) * tw + (nx+dx-1) + 1
					pixels[npos] = image.pixels[pos]
				end
			end
		end
	end
	return {
		width = tw,
		height = th,
		pixels = pixels
	}
end

--- Loads a displayable image from the given path. If the file actually contains
--- a raster image, it will be converted to a displayable image. Returns an error if
--- the image type is not recognised.
-- @tparam string path The path of the image to load
-- @treturn DisplayableImage The loaded image
function lib.load(path)
	local file, reason
	if io then
		file, reason = io.open(path, "r")
	else
		file, reason = require("buffer").from(fs.open(path, "r"))
	end
	if not file then
		error(reason)
	end
	
	local f = lib.getFormat(file)
	if not f then
		error("image type not recognized")
	end
	local img = f:decode(file)
	if f:getType() == "raster" then
		return lib.convertFromRaster(img, {})
	end
	return img
end

--- Loads a raster image from the given path. Returns an error if
--- the image type is not recognised or if it is a displayable image type.
--- (while it is technically possible to convert a displayable image to a raster
--- image, it would require packing in OpenComputers's font which would make the
--- library size huge for a feature that's gonna be rarely used)
-- @tparam string path The path of the image to load
-- @treturn RasterImage The loaded image
function lib.loadRaster(path)
	local file, reason = require("buffer").from(fs.open(path, "r"))
	if not file then
		error(reason)
	end
	
	local f = lib.getFormat(file)
	if not f then
		error("image type not recognized")
	end
	local img = f:decode(file)
	if f:getType() ~= "raster" then
		error("a non-raster image was loaded")
	end
	return img
end

--- Returns the aspect ratio of the given image.
-- @tparam RasterImage|DisplayableImage image
function lib.getAspectRatio(image)
	if image.pixels then -- if is raster image
		return image.width / image.height
	else
		-- height * 2 as characters as twice as tall as they're wide!
		return image.width / image.height * 2
	end
end

--- Draws a displayable image using the given GPU driver or component instance. This can be useful
--- for using OCImage on OpenOS or other operating systems, and it's also used during boot for the
--- Concert splash screen.
-- @tparam DisplayableImage image The image to draw
-- @tparam driver|component gpu Instance of the GPU driver or component to use
-- @tparam int x The X position where the image will be drawn
-- @tparam int y The Y position where the image will be drawn
function lib.drawGPU(image, gpu, x, y)
	for dy=1, image.height do
		for dx=1, image.width do
			local pos = (dy-1) * image.width + (dx-1) + 1
			gpu.setForeground(image.foregrounds[pos])
			gpu.setBackground(image.backgrounds[pos])
			gpu.set(x+dx-1, y+dy-1, image.chars[pos])
		end
	end
end

--- Draws a displayable image to the given OCDraw context
-- @tparam DisplayableImage image The image to draw
-- @tparam int ctxn The ID of the draw context
function lib.drawImage(image, ctxn)
	local canvas = require("OCX/OCDraw").canvas(ctxn)

	for y=1, image.height do
		for x=1, image.width do
			local pos = (y-1) * image.width + (x-1) + 1
			canvas.drawText(x, y, image.chars[pos], image.foregrounds[pos], image.backgrounds[pos])
		end
	end
end

return lib
