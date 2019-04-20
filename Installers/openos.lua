-- Variables
local component     = require("component")
local internet      = component.getPrimary("internet")
local gpu           = require("term").gpu()
local event         = require("event")
local width, height = gpu.getResolution()
local stage         = 1
local selected      = 2
local maxSelect     = 2
local fileList      = nil
local run           = true
local repoURL       = "https://raw.githubusercontent.com/zenith391/Fuchas/master/"
local downloading   = ""

-- Code
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
		gpu.setBackground(0x000000)
		if selected == 1 then
			gpu.setBackground(0xFFFFFF)
			gpu.setForeground(0x000000)
		end
		gpu.set(7, 11, "Erase \"OpenOS\"")
		gpu.setBackground(0x000000)
		gpu.setForeground(0xFFFFFF)
		if selected == 2 then
			gpu.setBackground(0xFFFFFF)
			gpu.setForeground(0x000000)
		end
		gpu.set(7, 12, "Keep \"OpenOS\", go dual-boot")
		gpu.setBackground(0x000000)
		gpu.setForeground(0xFFFFFF)
	end
end

local function download(url)
	local con = internet.request(url)
	--con:finishConnection()
	local buf = ""
	local data = ""
	while data ~= nil do
		data = con:read(math.huge)
		if data ~= nil then
			buf = buf .. data
		end
	end
	return buf
end

local function drawStage()
	gpu.setBackground(0x000000)
	gpu.fill(1, 1, 80, 25, ' ')
	gpu.set(width / 2 - 9, 1, "Fuchas Installation")
	if stage == 1 then
		gpu.set(5, 5, "You are going to install Fuchas on your computer.")
		gpu.set(5, 6, "You can either wipe your drive or put Fuchas")
		gpu.set(5, 7, "next to your OpenOS installation. And so install")
		gpu.set(5, 8, "a dual-boot configuration.")
		drawBorder(6, 10, width - 12, 3)
		drawEntries()
	end
	if stage == 2 then
		if not doErase then
			gpu.set(5, 4, "Information:")
			gpu.set(5, 5, "Dual-boot will be effective on the hard drive.")
			gpu.set(5, 6, "Meaning dual-boot will not affect EEPROM..")
			gpu.set(5, 7, "You will be prompted between launching OpenOS or Fuchas")
			gpu.set(5, 8, "when booting on this hard drive.")
			gpu.set(5, 10, "Please wait..")
		else
			gpu.set(5, 5, "Erasing OpenOS is untested.")
			gpu.set(5, 6, "For security issues, dual-boot will be choosed")
			gpu.set(5, 8, "Please wait..")
			doErase = false
		end
	end
	if stage == 3 then
		gpu.set(5, 5, "Fetching install files..")
	end
	if stage == 4 then
		gpu.set(5, 5, "Downloading..")
		gpu.set(5, 6, downloading)
	end
	if stage == 5 then
		gpu.set(5, 5, "Done.")
		gpu.set(5, 6, "Please restart computer to finish installation.")
		run = false
	end
end

local function install()
	stage = 4
	for k, v in pairs(fileList) do
		downloading = v
		drawStage()
		local content = download(repoURL .. v)
	end
	stage = 5
	drawStage()
end

local doErase = false
local function process()
	if stage == 1 then
		stage = 2
		doErase = selected == 1
		selected = 1
		drawStage()
		os.sleep(5) -- let the user read
		stage = 3
		drawStage()
		
		-- fetch
		fileList = load("return {" .. download(repoURL .. "INSTALL1.LST") .. "}")()
		install()
	end
end

drawStage()
os.sleep(0.5) -- let the input go
while run do
	local id, a, b, c, d = event.pull()
	if id == "interrupted" then
		break
	end
	if id == "key_down" then
		if c == 200 then -- up
			if selected > 1 then
				selected = selected - 1
			end
		end
		if c == 208 then -- down
			if selected < maxSelect then
				selected = selected + 1
			end
		end
		drawEntries()
	end
	if id == "key_up" then
		if c == 28 then  -- enter
			process()
		end
	end
end