local gpu = require("driver").gpu
local sound = require("driver").sound
local SKY_COLOR = 0x5c94fc
local currentMusic = nil

local PATH = "A:/Users/Shared/Binaries/mario/"
local json = dofile(PATH .. "lib/json.lua")

local wmContext
if package.loaded.window then
	wmContext = require("window").requestExclusiveContext()
end

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

-- screen size is 20x12.5

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
	local file = io.open(PATH .. "img/" .. path, "r")

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

			-- monochrome mario
			--local avg = math.floor((0.2126*r + 0.7152*g + 0.0722*b))
			--r = avg; g = avg; b = avg;

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

local camX = 0
-- Ground takes 2x 8x4 buffers = 64 bytes
local tiles = { ground = {} }
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

local tileset = {
	"block",
	"ground",
	"hard",
	"mystery_used",
	"mystery",
	"pipe_1",
	"pipe_2",
	"pipe_3",
	"pipe_4",
	"goomba_0", -- never actually used in level rendering as it is transformed into an entity
	"flag_pole_mid",
	"flag_pole_top",
	"flag"
}

local level = {}
local entities = {}
local levelWidth
local collidables = {}

local function loadLevel(name)
	local file = io.open(PATH .. "levels/" .. name .. ".json", "r")
	local text = file:read("*a")
	file:close()

	local tiled = json.decode(text)
	if tiled.height ~= 13 then
		error("Levels must be exactly 13 blocks tall")
	end
	local layer = tiled.layers[1]

	levelWidth = tiled.width
	for x=1, tiled.width do
		level[x] = {}
		for y=1, 13 do
			level[x][y] = layer.data[x + (y-1) * tiled.width]
		end
	end

	collidables = {}
	for x=1, tiled.width do
		for y=1, 13 do
			local id = level[x][y]
			if id == 10 then -- goomba
				local entity = setmetatable({
					sprite = "goomba_0",
					x = (x-1) * 16 - 2,
					y = (y-1) * 16 - 8,
					vx = 0,
					vy = 0
				}, { __index = dofile(PATH .. "Goomba.lua") })
				entity:init()
				table.insert(entities, entity)

				level[x][y] = 0
			elseif id ~= 0 then
				table.insert(collidables, {
					x = (x-1) * 16 - 2,
					y = (y-1) * 16 - 8,
					lx = x,
					ly = y
				})
			end
		end
	end
end
loadLevel("level1")

for name, maxFrame in pairs(maxFrames) do
	mario[name] = {}
	for i=1, maxFrame do
		mario[name][i] = {}
	end
end

local function loadMusic(name)
	if not sound.getCapabilities().asynchronous then return end
	local file = io.open(PATH .. "music/" .. name .. ".aaf", "r")

	file:read(5) -- skip signature
	file:read(2) -- skip capability flags

	local channelsNum = file:read(1):byte()
	--print("Using " .. channelsNum .. " channels")
	local channelNotes = {}
	local channelIdx = {}

	for i=1, channelsNum do
		sound.openChannel(i)
		sound.setWave(i, "square")
		sound.setVolume(i, 0)
		sound.setADSR(i)
		channelNotes[i] = {}
		channelIdx[i] = 1
	end

	local fileEnded = false
	while not fileEnded do
		for i=1, channelsNum do
			local freqStr = file:read(2)
			if not freqStr then fileEnded = true; break; end
			local freq = string.unpack("<I2", freqStr)
			local dur = string.unpack("<I2", file:read(2))
			local start = 0
			if channelNotes[i][#channelNotes[i]] then
				local note = channelNotes[i][#channelNotes[i]]
				start = note.start + note.duration
			end
			table.insert(channelNotes[i], { frequency = freq, duration = math.floor(dur/1.0), start = start })
		end
	end
	file:close()

	currentMusic = { notes = channelNotes, index = channelIdx, channelsNum = channelsNum, time = 0, lastFlush = 0 }
end
loadMusic("song-mario")

local function drawTile(name, x, y)
	local ox = x %  2
	local gx = x // 2
	local gy = y // 4 -- thanks to no vertical scrolling, we don't have to handle that
	if not tiles[name] then
		tiles[name] = {}
	end
	if not tiles[name][ox+1] then
		tiles[name][ox+1] = drawImageToBuf(name .. ".bmp", ox, 0)
	end
	local buf = tiles[name][ox+1]

	gpu.blit(tiles[name][ox+1], gpu.screenBuffer(), gx, gy)
end

local function drawGround()
	for x=1, levelWidth do
		for y=1, 13 do
			if level[x][y] ~= 0 then
				local tile = tileset[level[x][y]]
				local screenX, screenY = (x-1) * 16 - camX, (y-1) * 16 - 1
				if screenX > -15 and screenX < 320 then
					drawTile(tile, screenX, screenY)
				end
			end
		end
	end
end

-- x, y, width and height are in CHARACTERS!
local function drawBackground(x, y, width, height)
	gpu.fill(x, y, width, height, SKY_COLOR)
end

local function drawScenery(x, y, width, height)
	drawBackground(x, y, width, height)
	--drawGround() -- TODO: optimize
	--local tx = x // 2
	--local ty = y // 4
	--if level[tx][ty] then
	--	local tile = tileset[level[tx][ty]]
	--	local screenX, screenY = (tx-1) * 16 - camX, (ty-1) * 16 - 1
	--	if tile then drawTile(tile, screenX, screenY) end
	--end
end

-- Player X and Y coordinates (zero-based !)
local px, py = 20, 140
local pvx, pvy = 0, 0

local function advanceAnimation(name)
	if marioAnim.name ~= name then
		marioAnim.name = name
		marioAnim.frame = 0
	else
		marioAnim.frame = (marioAnim.frame + 1) % maxFrames[marioAnim.name]
	end
end

local oldGX, oldGY = -1, -1
local function drawMario()
	-- TODO: actual subpixel sprite drawing (needs to overflow!)
	local ox, oy = math.floor(px) %  2, math.floor(py) %  4
	local gx, gy = math.floor(px) // 2, math.floor(py) // 4
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

	-- character width
	local w, h = 8, 4

	if dgx > 0 then
		drawScenery(oldGX + 1, oldGY + 1, dgx, h)
	elseif dgx < 0 then
		drawScenery(gx + w + 1, oldGY + 1, -dgx, h)
	end

	if dgy > 0 then
		drawScenery(gx + 1, gy + 1 - dgy, w, dgy)
	elseif dgy < 0 then
		drawScenery(gx + 1, gy + h + 1, w, -dgy)
	end

	gpu.blit(marioSprite[id][ox+1][oy+1], gpu.screenBuffer(), gx + 1, gy + 1)

	oldGX = gx
	oldGY = gy
end

local sprites = {}
local function drawEntity(entity)
	local ox, oy = math.floor(entity.x - camX) %  2, math.floor(entity.y) %  4
	local gx, gy = math.floor(entity.x - camX) // 2, math.floor(entity.y) // 4
	if not entity.oldGX then
		entity.oldGX = gx
		entity.oldGY = gy
	end
	local dgx, dgy = gx - entity.oldGX, gy - entity.oldGY
	if not sprites[entity.sprite] then
		sprites[entity.sprite] = drawImageToBuf(entity.sprite .. ".bmp", ox, oy, SKY_COLOR)
	end

	-- character width
	local w, h = 8, 4

	if dgx > 0 then
		drawScenery(entity.oldGX + 1, entity.oldGY + 1, dgx, h)
	elseif dgx < 0 then
		drawScenery(gx + w + 1, entity.oldGY + 1, -dgx, h)
	end

	if dgy > 0 then
		drawScenery(gx + 1, gy + 1 - dgy, w, dgy)
	elseif dgy < 0 then
		drawScenery(gx + 1, gy + h + 1, w, -dgy)
	end

	gpu.blit(sprites[entity.sprite], gpu.screenBuffer(), gx + 1, gy + 1)

	entity.oldGX = gx
	entity.oldGY = gy
end

local oldCGX = -1
local function redrawGround()
	local cgx = camX // 2
	if oldCGX == -1 then oldCGX = cgx end
	if cgx ~= oldCGX then
		local dx = cgx - oldCGX
		local tx = (cgx + 160) // 8
		gpu.copy(1, 1, 160, 50, -dx, 0)
		oldGX = oldGX - dx
		drawMario()
		gpu.fill(160-dx, 1, dx, 50, SKY_COLOR)
		for x=tx-(dx//8), tx do
			if x >= 1 and x < levelWidth then
				for y=1, 13 do
					if level[x][y] ~= 0 then
						local tile = tileset[level[x][y]]
						local screenX, screenY = (x-1) * 16 - camX, (y-1) * 16 - 1
						if screenX > -15 and screenX < 320 then
							drawTile(tile, screenX, screenY)
						end
					end
				end
			end
		end
		oldCGX = cgx
	end
end

drawBackground(1, 1, 160, 50)
drawGround()
drawMario()

local steps = 0
local lastUptime = computer.uptime()
local pressed = {}
local colliding = false
local musicNoLoad = false

local SPEED = 1.0

table.insert(entities, {
	sprite = "mario/stand_0",
	x = px,
	y = py,
	vx = 0,
	vy = 0
})

while true do
	local name, addr, char, code = require("event").pull(0)
	local redraw = false
	pvy = pvy + 1*SPEED -- gravity

	if name == "interrupt" then
		break
	end

	if name == "key_down" then
		pressed[code] = true
	elseif name == "key_up" then
		pressed[code] = false
	end

	if name == "key_down" or true then
		if pressed[200] and colliding then -- up
			if SPEED == 1 then
				pvy = -11
			elseif SPEED == 0.5 then
				pvy = -8
			end
			redraw = true
		elseif pressed[203] then -- left
			pvx = -3*SPEED
			steps = steps + 1
			redraw = true
		elseif pressed[205] then -- right
			pvx = 3*SPEED
			steps = steps + 1
			redraw = true
		end
		if steps == 3 then
			advanceAnimation("walk")
			steps = 0
		end
	end

	if pvy ~= 0 then
		local oldPy = py
		py = py + pvy

		local function collidesAABB(a,b)
			return a.x+a.w > b.x and a.y+a.h > b.y and a.x < b.x+b.w and a.y < b.y+b.h
		end

		local pb = { x = px + camX, y = py, w = 16, h = 16 }

		colliding = false
		for _,col in pairs(collidables) do
			local colb = { x = col.x, y = col.y, w = 16, h = 16 }
			if collidesAABB(pb, colb) then
				py = oldPy
				if pvy < 0 then py = colb.y + colb.h else
					py = colb.y - colb.h end
				colliding = true
				local id = level[col.lx][col.ly]
				if id == 5 and pvy < 0 then -- ? block
					level[col.lx][col.ly] = 4
					drawGround()
				end
				pvy = 0
				break
			end
		end

		--gpu.drawText(1, 1, "p: " .. pb.x .. "," .. pb.y)
		--gpu.drawText(1, 2, "c: " .. tostring(colliding))

		if not colliding then
			advanceAnimation("jump")
		end
		redraw = true
	end

	if pvx ~= 0 then
		local oldPx = px
		px = px + pvx
		local pb = { x = px + camX, y = py, w = 16, h = 16 }

		local function collidesAABB(a,b)
			return a.x+a.w > b.x and a.y+a.h > b.y and a.x < b.x+b.w and a.y < b.y+b.h
		end

		for _,col in pairs(collidables) do
			local colb = { x = col.x, y = col.y, w = 16, h = 16 }
			if collidesAABB(pb, colb) then
				px = oldPx
				pvx = 0
				break
			end
		end

		if pvx > 0 then pvx = pvx - 0.5*SPEED end
		if pvx < 0 then pvx = pvx + 0.5*SPEED end
		redraw = true
	elseif pvy == 0 then
		if marioAnim.name ~= "stand" then
			advanceAnimation("stand")
			redraw = true
		end
	end

	if redraw then
		if px > 130 then
			local ox = (px - 130) // 2 * 2
			camX = camX + ox
			if camX > levelWidth * 16 then
				camX = 0
			end
			redrawGround()
			px = px - ox
		elseif px < 0 then
			px = 0
		end
		drawMario()
	end

	for k, entity in pairs(entities) do
		if entity.x - camX > 0 and entity.x - camX < 320 then
			entity.vy = entity.vy + 1
			local oldX = entity.x
			entity.x = entity.x + entity.vx
			local pb = { x = entity.x, y = entity.y, w = 16, h = 16 }

			local function collidesAABB(a,b)
				return a.x+a.w > b.x and a.y+a.h > b.y and a.x < b.x+b.w and a.y < b.y+b.h
			end

			for _,col in pairs(collidables) do
				local colb = { x = col.x, y = col.y, w = 16, h = 16 }
				if collidesAABB(pb, colb) then
					entity.x = oldX
					if entity.onHorizontalCollision then
						entity:onHorizontalCollision()
					else
						entity.vx = 0
						entity.horizontalCollision = true
					end
					break
				end
			end

			local oldY = entity.y
			entity.y = entity.y + entity.vy

			local pb = { x = entity.x, y = entity.y, w = 16, h = 16 }
			for _,col in pairs(collidables) do
				local colb = { x = col.x, y = col.y, w = 16, h = 16 }
				if collidesAABB(pb, colb) then
					entity.y = oldY
					if entity.vy < 0 then
						entity.y = colb.y + colb.h
					else
						entity.y = colb.y - colb.h
					end
					entity.vy = 0
					break
				end
			end

			if entity.update then
				entity:update()
			end
			drawEntity(entity)
		end
	end

	if currentMusic then
		if not musicNoLoad then
			local minDur = math.huge
			for i=1, currentMusic.channelsNum do
				local note = currentMusic.notes[i][currentMusic.index[i]]
				if note and (currentMusic.time >= note.start + note.duration) then
					currentMusic.index[i] = currentMusic.index[i] + 1
					note = currentMusic.notes[i][currentMusic.index[i]]
				end
				if note then
					if currentMusic.time >= note.start and not note.played then
						if note.frequency == 0 then
							sound.setFrequency(i, 0)
						else
							sound.setADSR(i) -- reset envelope before setting it
							sound.setADSR(i, 0, 250, 0.3, 100)
							sound.setVolume(i, 1)
							sound.setFrequency(i, note.frequency)
						end
						note.played = true
					end
					local dur = (note.start + note.duration) - currentMusic.time
					minDur = math.min(minDur, dur)
				end
			end
			currentMusic.time = currentMusic.time + minDur
			sound.delay(minDur)
		end
		if currentMusic.time - currentMusic.lastFlush > 1000 then
			if not sound.flush() then
				musicNoLoad = true
			else
				currentMusic.lastFlush = currentMusic.time
				musicNoLoad = false
			end
		end
	end
	
	if computer.uptime() - lastUptime > 0.05 then
		--os.sleep(0.05)
		lastUptime = computer.uptime()
	end
end

if wmContext then
	wmContext:release()
end
