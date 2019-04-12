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
	if parent == nil then
		entry.id = 0
		entry.parent = nil
	else
		entry.id = getArchive(parent).freeID
		getArchive(parent).freeID = getArchive(parent).freeID + 1
		getArchive(parent).entries[entry.id] = entry
		entry.parent = parent
	end
	entry.name = name
	if not isdir then
		entry.content = ""
	end
	entry.isDirectory = function()
		return isdir
	end
	entry.childEntry = function (n, d)
		return lib.newEntry(entry, n, d)
	end
	entry.isEOH = function()
		return false
	end
	return entry
end

local function eohEntry()
	local eoh = {}
	eoh.isDirectory = function()
		return false
	end
	eoh.isEOH = function()
		return true
	end
	return eoh
end

function lib.writeArchive(arc, s) -- arc = archive, s = stream
	s:write("URF")
	s:write(string.char(0x11)) -- DC1
	s:write(string.char(arc.version.major)) -- version major
	s:write(string.char(arc.version.minor)) -- version minor
	s:write(string.char(0x12)) -- DC2
	s:write(string.char(0x0)) -- NULL
	
	local ftSize = 0
	local dataSize = 0
	for _, v in pairs(arc.entries) do
		if v.isDirectory() then
			ftSize = ftSize + 2 + v.name:len()
		else
			if v.isEOH() then
				ftSize = ftSize + 5
			else
				ftSize = ftSize + 2 + v.name:len() + 8
				dataSize = dataSize + v.content:len()
			end
		end
	end
	
	local function writeEntry(entry)
		if entry.isDirectory() then
			s:write("D")
			s:write(string.char(entry.name:len()))
			s:write(entry.name)
		else
			if entry.isEOH() then
				s:write("Z")
				s:write(u32tostr(dataSize))
			else
				s:write("F")
				s:write(string.char(entry.name:len()))
				s:write(entry.name)
				s:write(u32tostr(ftSize + dataSize)) -- offset
				dataSize = dataSize + entry.content:len()
				s:write(u32tostr(entry.content:len()))
			end
		end
		s:write(string.char(entry.id))
		s:write(string.char(entry.parent.id))
	end
	for _, v in pairs(arc.entries) do
		writeEntry(v)
	end
	for _, v in pairs(arc.entries) do
		if not v.isDirectory() and not v.isEOH() then
			s:write(v.content)
		end
	end
end

function lib.newArchive()
	local arc = {}
	
	-- Root
	arc.freeID = 1
	arc.entries = {}
	arc.version = {
		major=1,
		minor=0
	}
	arc.root = lib.newEntry(nil, "", true)
	arc.root.parent = arc
	
	arc.isArchive = function()
		return true
	end
	
	return arc
end

return lib