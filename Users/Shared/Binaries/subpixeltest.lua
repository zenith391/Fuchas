local gpu = require("driver").gpu
local SKY_COLOR = 0x5c94fc

-- a b
-- c d
-- e f
-- g h
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
	end
	return bits
end

local function readBMP(path)
	local file = io.open("A:/Users/Shared/Binaries/img/" .. path, "r")

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
			if a < 128 then -- atleast semi-transparent
				r = (SKY_COLOR >> 16) & 0xFF
				g = (SKY_COLOR >> 8)  & 0xFF
				b = SKY_COLOR         & 0xFF
			end
			local rgb = (r << 16) | (g << 8) | b
			if not pixels[i] then pixels[i] = {} end
			pixels[i][j] = { red = r, green = g, blue = b, rgb = rgb }
		end
		if width*3 % 4 ~= 0 then
			file:read(4 - width*3 % 4)
		end
	end
	file:close()

	return {
		width = width,
		height = height,
		pixels = pixels
	}
end

local function offset(image, dx, dy, color)
	local newImage = {
		width = image.width,
		height = image.height,
		pixels = {}
	}
	if color then
		for y=1, image.height do
			for x=1, image.width do
				if not newImage.pixels[x] then newImage.pixels[x] = {} end
				newImage.pixels[x][y] = { rgb = color }
			end
		end
	end
	for y=1, image.height do
		for x=1, image.width do
			local pixel = image.pixels[x][y]
			local newX = x + dx
			local newY = y + dy
			if not color then
				newX = (x + dx - 1) % image.width + 1
				newY = (y + dy - 1) % image.height + 1
			end
			if newX > 0 and newX <= newImage.width and newY > 0 and newY <= newImage.height then
				if not newImage.pixels[newX] then newImage.pixels[newX] = {} end
				newImage.pixels[newX][newY] = image.pixels[x][y]
			end
		end
	end
	return newImage
end

local function process(image)
	local chars = {}
	for y=1, image.height, 4 do
		for x=1, image.width, 2 do
			local colorsOccurances = {}
			for dy=0, 3 do
				for dx=0, 1 do
					local rgb = image.pixels[x+dx][y+dy].rgb
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

			-- https://en.wikipedia.org/wiki/Color_difference
			local function distance(a, b)
				local Ar = (a >> 16) & 0xFF
				local Ag = (a >> 8) & 0xFF
				local Ab = a & 0xFF
				local Br = (b >> 16) & 0xFF
				local Bg = (b >> 8) & 0xFF
				local Bb = b & 0xFF

				local dR, dG, dB = math.abs(Ar-Br)^2, math.abs(Ag-Bg)^2, math.abs(Ab-Bb)^2
				if Ar + Br < 128 then
					return 2 * dR + 4 * dG + 3 * dB
				else
					return 3 * dR + 4 * dG + 2 * dB
				end
			end

			local usedColors = {}
			for dy=0, 3 do
				for dx=0, 1 do
					local rgb = image.pixels[x+dx][y+dy].rgb
					local pos = dx + dy * 2 + 1
					if distance(rgb, mostCommonColor) < distance(rgb, secondMostCommonColor) then
						usedColors[pos] = 1 -- foreground == mostCommonColor
					else
						usedColors[pos] = 0 -- background == secondMostCommonColor
					end
				end
			end

			local cx, cy = (x-1) // 2 + 1, (y-1) // 4 + 1
			if not chars[cx] then chars[cx] = {} end
			chars[cx][cy] = {
				char = brailleChar(table.unpack(usedColors)),
				fg = mostCommonColor,
				bg = secondMostCommonColor
			}
		end
	end
	chars.width = image.width / 2
	chars.height = image.height / 4
	return chars
end

local function drawImageToBuf(path, offsetX, offsetY, color)
	local image = offset(readBMP(path), offsetX, offsetY, color)
	local chars = process(image)

	local buffer = gpu.newBuffer(chars.width, chars.height, gpu.BUFFER_WO_NR_D)
	buffer:bind()
	for y=1, chars.height do
		for x=1, chars.width do
			gpu.setColor(chars[x][y].bg)
			gpu.setForeground(chars[x][y].fg)
			gpu.drawText(x, y, chars[x][y].char)
		end
	end
	buffer:unbind()

	return buffer
end

-- x, y, width and height are in CHARACTERS!

local function drawBackground(x, y, width, height)
	gpu.fill(x, y, width, height, SKY_COLOR)
end

local function drawScenery(x, y, width, height)
	drawBackground(x, y, width, height)
end

local groundOffsetX = 0
-- Ground takes 2x 8x4 buffers = 64 bytes
local ground = {}
local mario = {}
local maxFrames = {
	stand = 1,
	dead = 1,
	jump = 1,
	walk = 3
}
local marioAnim = {
	name = "stand",
	frame = 0
}

for name, maxFrame in pairs(maxFrames) do
	mario[name] = {}
	for i=1, maxFrame do
		mario[name][i] = {}
	end
end

-- Player X and Y coordinates (zero-based !)
local px, py = 20, 136
local pvx, pvy = 0, 0

local function advanceAnimation(name)
	if marioAnim.name ~= name then
		marioAnim.name = name
		marioAnim.frame = 0
	else
		marioAnim.frame = (marioAnim.frame + 1) % maxFrames[marioAnim.name]
	end
end

local function drawGround()
	local ox = groundOffsetX %  2
	local gx = groundOffsetX // 2
	if not ground[ox+1] then
		ground[ox+1] = drawImageToBuf("ground.bmp", ox, 0)
	end
	local buf = ground[ox+1]

	for x=-7,160,8 do
		gpu.blit(ground[ox+1], gpu.screenBuffer(), x + gx, 50 - 3)
		gpu.blit(ground[ox+1], gpu.screenBuffer(), x + gx, 50 - 7)
	end
end

local oldGX, oldGY = -1, -1
local function drawMario()
	-- TODO: actual subpixel sprite drawing (needs to overflow!)
	local ox, oy = px %  2, py %  4
	local gx, gy = px // 2, py // 4
	if oldGX == -1 then
		oldGX = gx
		oldGY = gy
	end
	local dgx, dgy = gx - oldGX, gy - oldGY
	local marioSprite = mario[marioAnim.name]
	local id = marioAnim.frame + 1
	if not marioSprite[id][ox+1] then marioSprite[id][ox+1] = {} end
	if not marioSprite[id][ox+1][oy+1] then
		marioSprite[id][ox+1][oy+1] = drawImageToBuf("mario/" .. marioAnim.name .. "_" .. marioAnim.frame .. ".bmp", ox, oy, SKY_COLOR)
	end
	gpu.blit(marioSprite[id][ox+1][oy+1], gpu.screenBuffer(), gx + 1, gy + 1)

	if dgx > 0 then
		drawScenery(gx - dgx + 1, gy + 1, dgx, 8)
	elseif dgx < 0 then
		drawScenery(gx + 17, gy + 1, -dgx, 8)
	end

	if dgy > 0 then
		drawScenery(gx + 1, gy + 1 - dgy, 16, dgy)
	elseif dgy < 0 then
		drawScenery(gx + 1, gy + 9, 16, -dgy)
	end

	oldGX = gx
	oldGY = gy
end

drawBackground(1, 1, 160, 50)
drawGround()
drawMario()

local steps = 0
local lastUptime = computer.uptime()
local pressed = {}

while true do
	local name, addr, char, code = require("event").pull(0)
	local redraw = false

	if py < 136 then
		pvy = pvy + 1
	elseif pvy > 0 then
		pvy = 0
	end

	if name == "key_down" then
		pressed[code] = true
	elseif name == "key_up" then
		pressed[code] = false
	end

	if name == "key_down" then
		if pressed[200] and py == 136 then -- up
			pvy = -10
			redraw = true
		elseif pressed[203] then -- left
			pvx = -3
			steps = steps + 1
			redraw = true
		elseif pressed[205] then -- right
			pvx = 3
			steps = steps + 1
			redraw = true
		end
		if steps == 3 then
			advanceAnimation("walk")
			steps = 0
		end
		pressed = {}
	end

	if pvx ~= 0 then
		px = px + pvx
		if pvx > 0 then pvx = pvx - 1 end
		if pvx < 0 then pvx = pvx + 1 end
		redraw = true
	elseif pvy == 0 then
		if marioAnim.name ~= "stand" then
			advanceAnimation("stand")
			redraw = true
		end
	end

	if pvy ~= 0 then
		py = math.min(136, py + pvy)
		if py > 0 then
			advanceAnimation("jump")
		end
		redraw = true
	elseif pvx == 0 then
		if marioAnim.name ~= "stand" then
			advanceAnimation("stand")
			redraw = true
		end
	end

	if redraw then
		if px > 261 then
			local ox = px - 261
			groundOffsetX = (groundOffsetX - ox) % 16
			drawGround()
			px = 261
		elseif px < 0 then
			px = 0
		end
		drawMario()
	end
	
	if computer.uptime() - lastUptime > 0.05 then
		os.sleep(0)
	end
end