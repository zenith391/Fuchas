-- Variables
local internet = component.internet
local event = require("event")
local filesystem = require("filesystem")
local shell = require("shell")
local run           = true
local repoURL       = "https://raw.githubusercontent.com/zenith391/Fuchas/master/"

-- AdorableCatgirl's uncpio
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
			--filesystem.makeDirectory("A:/" .. dir)
		end
		--local hand = io.open("A:/" .. dent.name, "w")
		stream:read(dent.filesize)
		--hand:write(stream:read(dent.filesize))
		--hand:close()
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
		
		if (dent.namesize % 2 ~= 0) then
			stream:seek("cur", 1)
		end
		if (bit32.band(dent.mode, 32768) ~= 0) then
			print("Extracting " .. name)
			fwrite()
		end
		if (dent.filesize % 2 ~= 0) then
			stream:seek("cur", 1)
		end
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

local function install()
	if not filesystem.exists("A:/Temporary") then
		filesystem.makeDirectory("A:/Temporary")
	end
	local sup = string.isUnicodeEnabled()
	string.setUnicodeEnabled(false)
	print("Downloading release..")
	local cpio = download(repoURL .. "release.cpio")
	local tmpCpio = io.open("A:/Temporary/fuchas.cpio", "w")
	tmpCpio:write(cpio)
	tmpCpio:close()
	tmpCpio = require("filesystem").open("A:/Temporary/fuchas.cpio")
	--tmpCpio = io.open("A:/Temporary/fuchas.cpio")
	print("Extracting Fuchas..")
	ext(tmpCpio)
	tmpCpio:close()
	filesystem.remove("A:/Temporary/fuchas.cpio")
	string.setUnicodeEnabled(sup)
end

print("Upgrading Fuchas (no new version check, always forced)")
install()
