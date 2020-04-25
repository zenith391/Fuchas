local filesystem = require("filesystem")
local driver = ...

local freeID = 0

local fs = {}
local SS = 512
local SO = 513

local function getName(id)
	local a = id * SS + SO
	local name = driver.readBytes(a+5, 32)
	local str = ""
	for i=1, 32 do
		if name[i] == 0 then
			break
		end
		str = str .. string.char(name[i])
	end
	coroutine.yield()
	return str
end

local function setName(id, name)
	local a = id * SS + SO
	driver.writeBytes(a+5, string.rep(string.char(0), 32)) -- be sure name is cleared
	driver.writeBytes(a+5, name)
end

local function getType(id)
	local a = id * SS + SO
	return string.char(driver.readByte(a))
end

local function getFirstFragment(id)
	local a = id * SS + SO
	return io.fromunum(driver.readBytes(a + 39, 2), false, 2)
end

local function setFirstFragment(id, fragment)
	local a = id * SS + SO
	driver.writeBytes(a + 39, io.tounum(fragment, 2, false))
end

local function getNextFragment(id)
	local a = id * SS + SO
	return io.fromunum(driver.readBytes(a + 1, 2), false, 2)
end

local function setNextFragment(id, fragment)
	local a = id * SS + SO
	driver.writeBytes(a + 1, io.tounum(fragment, 2, false))
end

--- Warning! num counts from 0
local function setChildren(id, num, cid)
	local a = id * SS + SO
	driver.writeBytes(a + 41 + (num*2), io.tounum(cid, 2, false))
end

local function setChildrenNum(id, num)
	local a = id * SS + SO
	driver.writeBytes(a + 39, io.tounum(num, 2, false))
end

local function getChildrens(id)
	local a = id * SS + SO
	local num = io.fromunum(driver.readBytes(a + 39, 2), false, 2)
	local childs = {}
	for i=1, num do
		table.insert(childs, {
			id = io.fromunum(driver.readBytes(a + 41 + (i-1)*2, 2), false, 2)
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
	driver.writeBytes(a, string.rep("\0", 50))
	driver.writeBytes(a, type)
	driver.writeBytes(a+3, io.tounum(parent, 2, true))
end

-- TODO: Implement a cache
local function getId(path)
	if path == "/" then
		return 0
	end
	local segments = filesystem.segments(path)
	local id = 0
	for i=1, #segments-1 do
		local seg = segments[i]
		if getType(id) ~= "D" then
			return -1, "one of path segment isn't an directory"
		end
		local childs = getChildrens(id)
		local foundChild = false
		for k, v in pairs(childs) do
			local name = getName(v.id)
			print("child " .. name)
			if name == seg then
				foundChild = true
				id = v.id
				break
			end
		end
		if not foundChild then
			return -1, "a segment of path " .. path .. " (" ..seg .. ") does not exists"
		end
	end
	-- Process last segment of path
	local childs = getChildrens(id)
	for k, v in pairs(childs) do
		--print("CHILD ID = " .. v.id)
		local name = getName(v.id)
		--print("NAME = " .. name)
		if name == segments[#segments] then
			return v.id
		end
	end
	return -1, path .. " does not exists"
end

function fs.format()
	local str = string.rep('\x00', 512)
	driver.writeBytes(1, str)
	driver.writeBytes(1, "Nitro_FS")
	driver.writeBytes(9, "FCH1")
	writeEntry("D", 0, 0)
	setName(0, "/")
	return true
end

function fs.asFilesystem()
	
end

function fs.isDirectory(path)
	if path:len() == 0 or path == "/" then
		return true
	end
	local id = getId(filesystem.canonical(path))
	if id == -1 then return false end
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
	writeEntry("D", nid, id)
	setName(nid, segments[#segments])
	local childs = getChildrens(id)
	local cnum = #childs
	setChildren(id, cnum, nid)
	setChildrenNum(id, cnum+1)
	cnum = #getChildrens(id)
end

function fs.exists(path)
	if path:len() == 0 or path == "/" then
		return true
	end
	path = filesystem.canonical(path)
	local id = getId(path)
	if id == -1 then
		return false
	else
		return true
	end
end

function fs.isFormatted()
	local head = driver.readBytes(1, 8, true)
	return head == "Nitro_FS"
end

function fs.open(path, mode)
	if not fs.exists(path) then
		if mode == "w" then
			-- create file
			local parent = filesystem.path(path)
			local segments = filesystem.segments(path)
			if not fs.exists(parent) then
				return nil, parent .. " does not exists"
			end
			local id, err = getId(parent)
			if err ~= nil then
				return nil, err
			end
			local nid = getFreeID()
			writeEntry("F", nid, id)
			setName(nid, segments[#segments])
			local childs = getChildrens(id)
			setChildren(id, #childs, nid)
			setChildrenNum(id, #childs+1)
		else
			return nil, "file doesn't exists"
		end
	end
	local id = getId(filesystem.canonical(path))
	local curFragment = getFirstFragment(id)
	local firstFragment = curFragment == 0
	
	local function read(self, length)
		if curFragment == 0 then
			return nil
		end
	end

	local function allocateFragment()
		local nid = getFreeID()
		if firstFragment then
			setFirstFragment(id, nid)
			firstFragment = false
		end
		writeEntry("R", nid, id)
		curFragment = nid
	end

	local function write(self, str)
		if str:len() == 0 then
			return
		end
		while true do
			if self.cursor%509 == 1 then
				allocateFragment()
			end
			local part = str:sub(1, 510-self.cursor)
			if part:len() == 0 then
				break
			end
			driver.writeBytes(curFragment*SS+SO+2, part)
			str = str:sub(510-self.cursor+1)
			self.cursor = self.cursor + part:len()
		end
	end

	local handle = {
		close = function(self)
			-- TODO: close
		end,
		cursor = 1
	}
	if mode == "w" then handle.write = write end
	if mode == "r" then handle.read = read end

	return handle
end

return fs, "Nitro_FS", "NitroFS" -- in order: driver, 8-char FS name, fs name
