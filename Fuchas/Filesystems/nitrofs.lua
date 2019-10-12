local filesystem = require("filesystem")
local driver = ...

local freeID = -1

local fs = {}
local SS = 512
local SO = 512 -- add 1 for the 1-number base

local function getName(id)
	local a = id * SS + SO
	local name = driver.readBytes(a + 5, 32)
	local str = ""
	for i=1, 32 do
		if name[i] == 0 then
			break
		end
		str = str .. string.char(name[i])
	end
	return str
end

local function setName(id, name)
	local a = id * SS + SO
	driver.writeBytes(a+5, string.rep(string.char(0), 32)) -- be sure name is cleared
	driver.writeBytes(a+5, name)
end

local function getType(id)
	local a = id * SS + SO
	return readBytes(a, 1, true)
end

--- Warning! num counts from 0
local function setChildren(id, num, ctype, cid)
	local a = id * SS + SO
	driver.writeBytes(a + 40 + (num*3), {string.byte(ctype), table.unpack(io.tounum(cid, 2, true))})
end

local function setChildrenNum(id, num)
	local a = id * SS + SO
	driver.writeBytes(a + 38, io.tounum(num, 2, true))
end

local function getChildrens(id)
	local a = id * SS + SO
	local num = io.fromunum(driver.readBytes(a + 38, 2, true), true, 2)
	local childs = {}
	for i=1, num do
		table.insert(childs, {
			directory = (driver.readBytes(a + 39 + (i-1)*3, 1, true) == 'D'),
			id = io.fromunum(driver.readBytes(a + 41 + (i-1)*3, 2), true, 2)
		})
	end
	return childs
end

local function isOccupied(id)
	return driver.readByte(id*SS+SO) ~= 0
end

local function getFreeID(startFID)
	if not freeID or freeID == 0 then
		local fid = startFID or 0
		while fid < math.huge do
			if isOccupied(fid) then
				fid = fid + 1
			else
				break
			end
		end
		freeID = fid
	end
	if isOccupied(freeID) then
		local sfid = freeID
		freeID = 0
		getFreeID(sfid)
	end
	return freeID
end

local function writeEntry(type, id, parent)
	local a = id * SS + SO
	--component.invoke(addr, "writeSector", a/512+1, string.rep(string.char(0), 512))
	driver.writeBytes(a, string.rep("\0", 512))
	driver.writeBytes(a, type)
	driver.writeBytes(a+1, string.rep(string.char(0), 2))
	driver.writeBytes(a+3, io.tounum(parent, 2, true))
end

-- TODO: Implement a cache
local function getId(path)
	if path == "/" then
		return 0
	end
	local segments = filesystem.segments(path)
	local id = 0
	for i=2, #segments-1 do -- start at 2 to skip "/" and skip the last part
		local seg = segments[i]
		if getType(id) ~= "D" then
			return -1, "one of path segment isn't an directory"
		end
		local childs = getChildrens(id)
		local foundChild = false
		for k, v in pairs(childs) do
			local name = getName(v.id)
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
	local childs = getChildrens(id)
	for k, v in pairs(childs) do
		local name = getName(v.id)
		if name == segments[#segments] then
			return v.id
		end
	end
	return -1, path .. " does not exists"
end

function fs.format()
	local str = string.rep('\0', 512)
	driver.writeBytes(0, str)
	driver.writeBytes(0, "NTRFS1")
	driver.writeBytes(7, "FUCHAS")
	writeEntry("D", 0, 0)
	setName(0, "/")
	return true
end

function fs.asFilesystem()
	
end

function fs.isDirectory(path)
	local id = getId(path)
	return (getType(id) == "D")
end

function fs.isFile(path)
	local id = getId(path)
	return (getType(id) == "F")
end

function fs.getMaxFileNameLength()
	return 32
end

function fs.makeDirectory(path)
	local parent = filesystem.path(path)
	local segments = filesystem.segments(path)
	if not fs.exists(parent) then
		error(parent .. " does not exists")
	end
	local id, err = getId(parent)
	if err ~= nil then
		error(err)
	end
	local nid = getFreeID()
	print("Parent ID: " .. id)
	print("New ID: " .. nid)
	writeEntry("D", nid, id)
	setName(nid, segments[#segments])
	local childs = getChildrens(id)
	local cnum = #childs
	print("Children ID: " .. cnum)
	setChildren(id, cnum, "D", nid)
	setChildrenNum(id, cnum+1)
	cnum = #getChildrens(id)
	print("Children Count: " .. cnum)
end

function fs.exists(path)
	if path:len() == 0 or path == "/" then
		return true
	end
	if path:sub(1, 1) ~= "/" then
		path = "/" .. path
	end
	path = filesystem.canonical(path)
	print(path)
	local id = getId(path)
	if id == -1 then
		return false
	else
		return true
	end
end

function fs.isValid()
	local head = driver.readBytes(0, 6, true)
	return head == "NTRFS1"
end

function fs.open(path, mode)
	
end

return fs, "NTRFS1", "NitroFS" -- in order: driver, OSDI label, fs name
