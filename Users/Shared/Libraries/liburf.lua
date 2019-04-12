-- Extension library, being in Users/Shared
-- Implementation details:
-- over 64-bits precisions ALIs are not supported!
local lib = {}
--local bit32 = require("bit32")

-- Little-Endian bytes operations
--local function fromu16(x)
--	local b2=string.char(x%256) x=(x-x%256)/256
--	local b1=string.char(x%256) x=(x-x%256)/256
--	return {b1, b2}
--end

local function u32tostr(x)
	local b4=string.char(x%256) x=(x-x%256)/256
	local b3=string.char(x%256) x=(x-x%256)/256
	local b2=string.char(x%256) x=(x-x%256)/256
	local b1=string.char(x%256) x=(x-x%256)/256
	return b1 .. b2 .. b3 .. b4
end

local function readALI(bytes)
	local i = 1
	local num = 0
	
	while true do
		local b = bytes[i]
		local _b =  bit32.rshift(b, 1 + (7 * (i - 1)))
		num = num + _b
		if bit32.lshift(b, 7) == 0 then
			break
		end
	end
	
	return num
end

local function writeALI(num)
	
end

local function getArchive(obj)
	local parent = obj.parent
	if parent.isArchive then
		return parent
	else
		return getArchive(parent.parent)
	end
end

function lib.newEntry(parent, name, isdir)
	checkArg(2, name, "string")
	checkArg(3, isdir, "boolean")
	local entry = {}
	if parent == 0 then
		entry.id = 0
	else
		entry.id = getArchive(parent).freeID
		getArchive(parent).freeID = getArchive(parent).freeID + 1
	end
	entry.parent = parent
	if not isdir then
		entry.content = ""
	end
	entry.isDirectory = function()
		return isdir
	end
	entry.childEntry = function (n, d)
		return lib.newEntry(entry.id, n, d)
	end
	return entry
end

function lib.writeArchive(arc, s) -- arc = archive, s = stream
	s:write("URF")
	s:write(string.char(0x11)) -- DC1
	s:write(string.char(arc.version.major)) -- version major
	s:write(string.char(arc.version.minor)) -- version minor
	s:write(string.char(0x12)) -- DC2
	s:write(string.char(0x0)) -- NULL
end

function lib.newArchive()
	local arc = {}
	
	-- Root
	arc.freeID = 1
	arc.version = {
		major=1,
		minor=0
	}
	arc.root = lib.newEntry(0, "", true)
	
	arc.isArchive = function()
		return true
	end
	
	return arc
end

return lib