local component     = require("component")
local internet      = component.getPrimary("internet")
local gpu           = require("term").gpu()
local width, height = gpu.getResolution()
local stage         = 1
local selected      = 1
if width > 80 or height > 25 then
	gpu.setResolution(80, 25)
	width = 80
	height = 25
end

gpu.setBackground(0x000000)
gpu.fill(1, 1, width, height, ' ')
gpu.set(1, height, "Ctrl+C = Exit")
gpu.set(width - 15, height, "Enter = Continue")

local function drawBorder(x, y, width, height)
	gpu.set(x, y, "╔")
	gpu.set(x + width, y, "╗")
	gpu.fill(x + 1, y, width - 1, 1, "═")
	gpu.fill(x + 1, y + height, width - 1, 1, "═")
	gpu.set(x, y + height, "╚")
	gpu.set(x + width, y + height, "╝")
	gpu.fill(x, y + 1, 1, height - 1, "║")
	gpu.fill(x + width, y + 1, 1, height - 1, "║")
end

local function drawEntries()
	if stage == 1 then
		gpu.set(7, 11, "Erase \"OpenOS\"")
		gpu.set(7, 12, "Keep \"OpenOS\", go dual-boot")
	end
end

local function drawStage()
	gpu.set(width / 2 - 9, 1, "Fuchas Installation")
	if stage == 1 then
		--drawBorder(width / 8, 3, width - width / 8 * 2, height - 6)
		gpu.set(5, 5, "You are going to install Fuchas on your computer.")
		gpu.set(5, 6, "You can either wipe your drive or put Fuchas")
		gpu.set(5, 7, "next to your OpenOS installation. And so install")
		gpu.set(5, 8, "a dual-boot configuration.")
		
		drawBorder(6, 10, width - 12, 3)
		
		drawEntries()
	end
end

drawStage()

while true do
	local id, a, b, c, d = require("event").pull()
	if id == "interrupted" then
		break
	end
	if id == "key_down" then
	end
	if id == "key_up" then
	end
end