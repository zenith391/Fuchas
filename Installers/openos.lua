-- Variables
local component     = require("component")
local bit32         = require("bit32")
local internet      = component.getPrimary("internet")
local term          = require("term")
local gpu           = term.gpu()
local event         = require("event")
local filesystem    = require("filesystem")
local width, height = gpu.getResolution()
local stage         = 1
local selected      = 2
local maxSelect     = 2
local run           = true
local cpioURL       = "https://bwsecondary.ddns.net/fuchas/releases/master.cpio"
local repoURL       = "https://raw.githubusercontent.com/zenith391/Fuchas/master/"
local devRelease    = false
local doErase = false
local downloading   = ""
local baseDir = os.getenv("BASE_DIR") or "/"
local cpioBaseDir = os.getenv("CPIO_BASE_DIR") or "/" -- for fast write speeds

if baseDir:sub(-1) ~= "/" then -- missing '/' at the end of BASE_DIR
	baseDir = baseDir .. "/"
end

node = filesystem.findNode(baseDir)
if node.fs.isReadOnly() then
	error("Base directory (" .. baseDir .. ") is read-only, are you trying to install from floppy?")
end

local node = filesystem.findNode(cpioBaseDir)
if node.fs.isReadOnly() then
	cpioBaseDir = baseDir
end

-- Adorable-Catgirl's uncpio
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
	
	local function readint(amt)
		local tmp = 0
		for i=1, amt do
			tmp = bit32.bor(tmp, bit32.lshift(string.byte(stream:read(1)), ((i-1)*8)))
		end
		return tmp
	end
	local function fwrite()
		local dir = dent.name:match("(.+)/.*%.?.+")
		if (dir) then
			filesystem.makeDirectory(baseDir .. dir)
		end
		local hand = io.open(baseDir .. dent.name, "w")
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
		if (name == "TRAILER!!!") then
			break
		end
		dent.name = name
		gpu.setBackground(0x000000)
		gpu.fill(1, 1, 80, 25, ' ')
		gpu.set(width / 2 - 9, 1, "Fuchas Installation")
		gpu.set(5, 5, "Installing..")
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
	if stage == 2 then
		gpu.setBackground(0x000000)
		if selected == 1 then
			gpu.setBackground(0xFFFFFF)
			gpu.setForeground(0x000000)
		end
		gpu.set(7, 11, "Stable release")
		gpu.setBackground(0x000000)
		gpu.setForeground(0xFFFFFF)
		if selected == 2 then
			gpu.setBackground(0xFFFFFF)
			gpu.setForeground(0x000000)
		end
		gpu.set(7, 12, "Dev release (currently paused, don't use that!)")
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
		gpu.set(5, 7, "next to your OpenOS installation, and have")
		gpu.set(5, 8, "a dual-boot configuration.")
		drawBorder(6, 10, width - 12, 3)
		drawEntries()
	end
	if stage == 2 then
		gpu.set(5, 5, "Fuchas is separated in two releases: stable and dev")
		gpu.set(5, 6, "The stable release is the recommended one, it doesn't")
		gpu.set(5, 7, "have latest features but is very stable. The dev release")
		gpu.set(5, 8, "have the latest features but is very buggy and not supported.")
		drawBorder(6, 10, width - 12, 3)
		drawEntries()
	end
	if stage == 3 then
		if not doErase then
			gpu.set(5, 4, "Information:")
			gpu.set(5, 5, "Dual-boot will be effective on the hard drive,")
			gpu.set(5, 6, "meaning dual-boot will not affect EEPROM.")
			gpu.set(5, 7, "You will be prompted between launching OpenOS or Fuchas")
			gpu.set(5, 8, "when booting on this hard drive.")
			gpu.set(5, 10, "Please wait..")
		else
			gpu.set(5, 5, "Erasing OpenOS is untested.")
			gpu.set(5, 6, "For security reasons, dual-boot will be chosen")
			gpu.set(5, 8, "Please wait..")
		end
	end
	if stage == 4 then
		gpu.set(5, 5, "Fetching install files..")
	end
	if stage == 5 then
		gpu.set(5, 5, "Downloading..")
		gpu.set(5, 6, downloading)
	end
	if stage == 6 then
		gpu.set(5, 5, "Create your admin account")
		gpu.set(5, 6, "New account username: admin")
		term.setCursor(5, 9)
		gpu.set(5, 8, "New account password:")
		local pwd = term.read({
			pwchar = '*'
		})
		pwd = pwd:sub(1, pwd:len() - 1) -- remove \n
		filesystem.makeDirectory(baseDir .. "Users/admin/")

		-- Hash using SHA3-512
		local sha3 = dofile(baseDir .. "Fuchas/Libraries/sha3.min.lua")
		local bin = sha3.bin

		local function randomSalt(len)
			local binsalt = ""
			for i=1, len do
				binsalt = binsalt .. string.char(math.floor(math.random() * 255))
			end
			return binsalt
		end

		local salt = randomSalt(32)
		local hash = bin.stohex(sha3.sha3.sha512(salt .. pwd))
		local handle = io.open(baseDir .. "Users/admin/account.lon", "w")
		handle:write([[
{
	name = "admin",
	password = "]] .. hash .. [[",
	salt = ]] .. string.format("%q", salt) .. [[,
	security = "sha3-512",
	userId = 0,
	groups = {}
}
]])
		handle:close()
		stage = 7
	end
	if stage == 7 then
		gpu.set(5, 5, "Done!")
		gpu.set(5, 6, "Now restarting the computer..")
		os.sleep(3)
		require("computer").shutdown(true)
		run = false
	end
end

local function install()
	local tmpCpio = io.open(cpioBaseDir .. "fuchas.cpio", "w")
	if not tmpCpio then
		error("error reading cpio, are you installing from floppy?")
	end
	local ok, err = tmpCpio:write(download(cpioURL))
	if not ok then
		error("Could not download package: " .. err)
	end
	tmpCpio:close()
	tmpCpio = io.open(cpioBaseDir .. "fuchas.cpio", "rb")
	ext(tmpCpio)
	tmpCpio:close()
	filesystem.remove(cpioBaseDir .. "/fuchas.cpio")
	local buf, err = io.open(baseDir .. "init.lua", "w")
	if buf == nil then
		error(err)
	end
	local name = (doErase and "init.lua") or "dualboot_init.lua"
	buf:write(download(repoURL .. name))
	buf:close()
	stage = 6
	drawStage()
end

local function process()
	if stage == 2 then
		if selected == 2 then
			devRelease = true
		end
		selected = 1
		stage = 3
		drawStage()
		os.sleep(5) -- let the user read
		stage = 4
		drawStage()
		install()
	end
	if stage == 1 then
		stage = 2
		doErase = (selected == 1)
		selected = 1
		drawStage()
	end
end

if _VERSION == "Lua 5.2" then
	io.stderr:write("You need Lua 5.3 to install Fuchas.\n")
	return
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
