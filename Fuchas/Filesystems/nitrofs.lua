local filesystem = require("filesystem")

local SECTOR_IO_TRESHOLD = 5
local freeID = {}

local sectorCache = { -- sectors are cached for faster properties/content reading.
	id = -1,
	addr = "",
	text = ""
}

local function readBytes(addr, off, len, asString) -- optimized function for reading bytes
	local bytes = {}
	if sectorCache.id ~= off / 512 or sectorCache.addr ~= addr then
		sectorCache.id = off / 512
		sectorCache.addr = addr
		sectorCache.text = component.invoke(addr, "readSector", off / 512+1)
	end
	bytes = string.byte(sectorCache.text:sub(1, off % 512))
	if asString then
		return table.pack(string.char(bytes))
	else
		return bytes
	end
end

local function writeBytes(addr, off, data) -- optimized function for writing bytes
	if type(data) == "string" then
		data = table.pack(string.byte(data, 1, string.len(data)))
	end
	if #data > SECTOR_IO_TRESHOLD and false then -- if it became more efficient to use sector i/o
		local sector = off/512+1
		local offset = off%512
		local sec = component.invoke(addr, "readSector", sector)
		sec = sec:sub(1, offset-1) .. string.char(table.unpack(data)) .. sec:sub(offset+#data+1)
		--print(sec)
		component.invoke(addr, "writeSector", sector, sec)
	else
		for i=1, #data do
			component.invoke(addr, "writeByte", off+i-1, data[i])
		end
	end
end

local fs = {}
local SS = 512
local SO = 8 -- add 1 for the 1-number base

local function getName(addr, id)
	local a = id * SS + SO
	local name = readBytes(addr, a + 5, 32)
	local str = ""
	for i=1, 32 do
		if name[i] == 0 then
			break
		end
		str = str .. string.char(name[i])
	end
	return str
end

local function setName(addr, id, name)
	local a = id * SS + SO
	writeBytes(addr, a+5, string.rep(string.char(0), 32)) -- be sure name is cleared
	writeBytes(addr, a+5, name)
end

local function getType(addr, id)
	local a = id * SS + SO
	return readBytes(addr, a, 1, true)
end

--- Warning! num counts from 0
local function setChildren(addr, id, num, ctype, cid)
	local a = id * SS + SO
	writeBytes(addr, a + 39 + (num*3), {string.byte(ctype), table.unpack(io.tounum(cid, 2, true))})
end

local function setChildrenNum(addr, id, num)
	local a = id * SS + SO
	writeBytes(addr, a + 37, io.tounum(num, 2, true))
end

local function getChildrens(addr, id)
	local a = id * SS + SO
	local num = io.fromunum(readBytes(addr, a + 37, 2), true, 2)
	local childs = {}
	for i=1, num do
		table.append(childs, {
			directory = (readBytes(addr, a + 39 + (i-1)*3, 1, true) == 'D'),
			id = io.fromunum(readBytes(addr, a + 41 + (i-1)*3, 2), true, 2)
		})
	end
	return childs
end

local function isOccupied(addr, id)
	return readBytes(addr, id*SS+SO+1, 1) ~= 0
end

local function getFreeID(addr, startFID)
	if not freeID[addr] or freeID[addr] == 0 then
		local fid = startFID or 0
		while fid < math.huge do
			if isOccupied(addr, fid) then
				fid = fid + 1
			else
				break
			end
		end
		freeID[addr] = fid
	end
	if isOccupied(addr, freeID[addr]) then
		local sfid = freeID[addr]
		freeID[addr] = 0
		getFreeID(addr, sfid)
	end
	return freeID[addr]
end

local function writeEntry(addr, type, id, parent)
	local a = id * SS + SO
	component.invoke(addr, "writeSector", a/512+1, string.rep(string.char(0), 512))
	writeBytes(addr, a, type)
	writeBytes(addr, a+1, string.rep(string.char(0), 2))
	writeBytes(addr, a+3, io.tounum(parent, 2, true))
end

-- TODO: Implement a cache
local function getId(addr, path)
	if path == "/" then
		return 0
	end
	local segments = filesystem.segments(path)
	local id = 0
	for i=2, #segments-1 do -- start at 2 to skip "/" and skip the last part
		local seg = segments[i]
		if getType(addr, id) ~= "D" then
			return -1, "one of path segment isn't an directory"
		end
		local childs = getChildrens(addr, id)
		local foundChild = false
		for k, v in pairs(childs) do
			local name = getName(addr, v.id)
			if name == seg then
				foundChild = true
				id = v.id
				break
			end
		end
		if not foundChild then
			return -1, "a segment of path " .. path .. " (" ..seg .. ") is unexisting"
		end
	end
	-- Process last segment of path
	local childs = getChildrens(addr, id)
	for k, v in pairs(childs) do
		local name = getName(addr, v.id)
		if name == segments[#segments] then
			return v.id
		end
	end
	return -1, path .. " does not exists"
end

function fs.format(addr)
	for i=1, 16 do -- clear sectors
		component.invoke(addr, "writeSector", i, string.rep(string.char(0), 512))
	end
	if component.type(addr) ~= "osdi_partition" then
		writeBytes(addr, 0, "NTRFS1")
	end
	writeEntry(addr, "D", 0, 0)
	setName(addr, 0, "/")
	return true
end

function fs.asFilesystem(addr)
	
end

function fs.isDirectory(addr, path)
	local id = getId(addr, path)
	return (getType(addr, id) == "D")
end

function fs.isFile(addr, path)
	local id = getId(addr, path)
	return (getType(addr, id) == "F")
end

function fs.getMaxFileNameLength()
	return 32
end

function fs.makeDirectory(addr, path)
	local parent = filesystem.path(path)
	local segments = filesystem.segments(path)
	if not fs.exists(addr, parent) then
		error(parent .. " does not exists")
	end
	local id, err = getId(addr, parent)
	if err ~= nil then
		error(err)
	end
	local nid = getFreeID(addr)
	print("New ID: " .. nid)
	writeEntry(addr, "D", nid, id)
	setName(addr, nid, segments[#segments])
	local childs = getChildrens(addr, id)
	local cnum = #childs
	print("Children ID: " .. cnum)
	setChildren(addr, id, cnum, "D", nid)
	setChildrenNum(addr, id, cnum+1)
	print("Children Count: " .. cnum)
end

function fs.exists(addr, path)
	if path:len() == 0 or path == "/" then
		return true
	end
	if path:sub(1, 1) ~= "/" then
		path = "/" .. path
	end
	path = filesystem.canonical(path)
	print(path)
	local id = getId(addr, path)
	if id == -1 then
		return false
	else
		return true
	end
end

function fs.isValid(addr)
	if component.type(addr) == "osdi_partition" then
		return true -- is on OSDI partition, which is a form of formatting
	end
	local head = readBytes(addr, 0, 6, true)
	return head == "NTRFS1"
end

function fs.open(addr, path, mode)
	
end

return "NTRFS1", fs, true, false -- in order: label, filesystem, osdiSupported, osdiForced
