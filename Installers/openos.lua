-- Variables
local component     = require("component")
local internet      = component.getPrimary("internet")
local gpu           = require("term").gpu()
local event         = require("event")
local filesystem    = require("filesystem")
local width, height = gpu.getResolution()
local stage         = 1
local selected      = 2
local maxSelect     = 2
local fileList      = nil
local run           = true
local repoURL       = "https://raw.githubusercontent.com/zenith391/Fuchas/master/"
local downloading   = ""

-- AwesomeCatgirl's uncpio
local function ext(stream)
	local dent = {
		magic = 0,
		dev = 0,
		ino = 0,
		mode = 0,
		uid = 0,
		gid = 0,
		nlink = 0,
		rdev = 0,
		mtime = 0,
		namesize = 0,
		filesize = 0
	}
	local function readint(amt, rev)
		local tmp = 0
		for i=1, amt do
			tmp = bit32.bor(tmp, bit32.lshift(string.byte(stream:read(1)), ((i-1)*8)))
		end
		return tmp
	end
	local function fwrite()
		local dir = dent.name:match("(.+)/.*%.?.+")
		if (dir) then
			filesystem.makeDirectory("/" .. dir)
		end
		local hand = io.open("/" .. dent.name, "w")
		hand:write(stream:read(dent.filesize))
		hand:close()
	end
	while true do
		dent.magic = readint(2)
		local rev = false
		if (dent.magic ~= tonumber("070707", 8)) then rev = true end
		dent.dev = readint(2)
		dent.ino = readint(2)
		dent.mode = readint(2)
		dent.uid = readint(2)
		dent.gid = readint(2)
		dent.nlink = readint(2)
		dent.rdev = readint(2)
		dent.mtime = bit32.bor(bit32.lshift(readint(2), 16), readint(2))
		dent.namesize = readint(2)
		dent.filesize = bit32.bor(bit32.lshift(readint(2), 16), readint(2))
		local name = stream:read(dent.namesize):sub(1, dent.namesize-1)
		if (name == "TRAILER!!!") then break end
		dent.name = name
		gpu.setBackground(0x000000)
		gpu.fill(1, 1, 80, 25, ' ')
		gpu.set(width / 2 - 9, 1, "Fuchas Installation")
		gpu.set(5, 5, "Downloading..")
		gpu.set(5, 6, name)
		
		if (dent.namesize % 2 ~= 0) then
			stream:seek("cur", 1)
		end
		if (bit32.band(dent.mode, 32768) ~= 0) then
			fwrite()
		end
		if (dent.filesize % 2 ~= 0) then
			stream:seek("cur", 1)
		end
	end
end

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
	local buf = ""
	local data = ""
	while data ~= nil do
		data = con.read(math.huge)
		if data ~= nil then
			buf = buf .. data
		end
	end
	con.close()
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
		gpu.set(5, 5, "Done!")
		gpu.set(5, 6, "Now restarting the computer..")
		os.sleep(0.5)
		require("computer").shutdown(true)
		run = false
	end
end

local function install()
	local cpio = download(repoURL .. "release.cpio")
	local tmpCpioPath = os.tmpname()
	print(tmpCpioPath)
	local tmpCpio = io.open(tmpCpioPath, "w")
	tmpCpio:write(cpio)
	tmpCpio:close()
	tmpCpio = io.open(tmpCpioPath, "rb")
	ext(tmpCpio)
	tmpCpio:close()
	
	local buf, err = io.open("/init.lua", "w")
	if buf == nil then
		error(err)
	end
	buf:write(download(repoURL .. "dualboot_init.lua"))
	buf:close()
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
		local f, err = load("return {" .. download(repoURL .. ".install") .. "}")
		if err ~= nil then
			error(err)
		end
		fileList = f()
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