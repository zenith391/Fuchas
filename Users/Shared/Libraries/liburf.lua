-- liburf v1.0
-- 2019-2019
-- Extension library, being in Users/Shared
-- Implementation details:
--   over 64-bits precisions ALIs are not supported!
local lib = {}

-- Little-Endian bytes operations

local function u32tostr(x)
	local b4=string.char(x%256) x=(x-x%256)/256
	local b3=string.char(x%256) x=(x-x%256)/256
	local b2=string.char(x%256) x=(x-x%256)/256
	local b1=string.char(x%256) x=(x-x%256)/256
	return b1 .. b2 .. b3 .. b4
end

local function u32fromstr(str)
	local arr = {}
	for i = 1, #str do
		table.insert(arr, string.byte(str:sub(i,i)))
	end
	return io.tou32(arr, 1)
end

local function readALI(s)
	local num = 0
	local i = 0
	local continue = true
	while continue do
		local byte = string.byte(s:read(1))
		local inc = bit32.lshift(bit32.band(byte, 127), i)
		num = num + inc
		continue = (bit32.band(byte, 128) == 128) -- if 8th byte = 1
		i = i + 1
	end
	return num
end

local function writeALI(num)
	local bytes = {}
	while num > 0 do
		
	end
	return bytes
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
	entry.getChildrens = function()
		local childs = {}
		for _, v in pairs(getArchive(parent).entries) do
			if v.parent == entry then
				table.insert(childs, v)
			end
		end
		return childs
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

function lib.readArchive(s)
	local arc = {}
	assert(s:read(3) == "URF", "invalid signature")
	assert(s:read(1) == string.char(0x11), "invalid signature")
	arc.version = {}
	arc.version.major = string.byte(s:read(1))
	arc.version.minor = string.byte(s:read(1))
	arc.entries = {}
	arc.root = lib.newEntry(nil, "", true)
	arc.root.parent = arc
	assert(s:read(2) == string.char(0x12) .. string.char(0x0), "invalid signature")
	local ftSize = 0
	local function readEntry()
		local entry = {}
		local type = s:read(1)
		entry.isDirectory = function()
			return type == "D"
		end
		entry.isEOH = function()
			return type == "Z"
		end
		ftSize = ftSize + 1
		if type == "D" then
			entry.name = s:read(string.byte(s:read(1)))
			ftSize = ftSize + 1 + entry.name:len()
		elseif type == "F" then
			entry.name = s:read(string.byte(s:read(1)))
			entry.offset = u32fromstr(s:read(4))
			entry.contentLen = u32fromstr(s:read(4))
			ftSize = ftSize + entry.name:len() + 9
		else
			entry.offset = u32fromstr(s:read(4))
			ftSize = ftSize + 4
		end
		if type ~= "Z" then
			entry.id = string.byte(s:read(1))
			entry.parentId = string.byte(s:read(1))
			ftSize = ftSize + 2
		end
		return entry
	end
	
	while true do
		local entry = readEntry()
		if entry.isEOH() then
			break
		else
			arc.entries[entry.id] = entry
		end
	end
	for _, v in pairs(arc.entries) do
		for _, w in pairs(arc.entries) do
			if w.parentId == v.id then
				w.parent = v
			end
		end
		if not v.isDirectory() then
			s:seek("set", 8 + ftSize + v.offset)
			v.content = s:read(v.contentLen)
		end
	end
	return arc
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
				s:write(u32tostr(dataSize)) -- offset
				dataSize = dataSize + entry.content:len()
				s:write(u32tostr(entry.content:len()))
			end
		end
		if not entry.isEOH() then
			s:write(string.char(entry.id))
			s:write(string.char(entry.parent.id))
		end
	end
	for _, v in pairs(arc.entries) do
		writeEntry(v)
	end
	writeEntry(eohEntry())
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