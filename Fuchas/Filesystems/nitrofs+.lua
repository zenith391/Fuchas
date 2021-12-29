local filesystem = require("filesystem")
local driver, partitionUUID = ...
local fs = {}

local _allocatedBlocks = nil
local _blockIds = {}

-- Blocks are one-indexed
local function getAllocatedBlocks()
	if not _allocatedBlocks then
		_allocatedBlocks = {}
		local bytes = driver.readBytes(512, 8192)
		for i=1, #bytes do
			for n=7, 0, -1 do
				local bit = bit32.band(bit32.rshift(bytes[i], n), 1)
				table.insert(_allocatedBlocks, bit == 1)
			end
		end
	end
	return _allocatedBlocks
end

-- Blocks are one-indexed
local function allocateBlock(n)
	if not n then
		local blocks = getAllocatedBlocks()
		for k, block in ipairs(blocks) do
			if block == false then
				n = k
				break
			end
		end
	end

	if _allocatedBlocks then
		_allocatedBlocks[n] = true
	end
	local addr = 512 + math.floor((n - 1) / 8)
	local byte = driver.readByte(addr)
	local shift = 7 - (n-1) % 8
	byte = bit32.bor(byte, bit32.lshift(1, shift))
	driver.writeByte(addr, byte)
	return n
end

-- Blocks are one-indexed
local function deallocateBlock(n)
	if _allocatedBlocks then
		_allocatedBlocks[n] = false
	end
	local addr = 512 + math.floor((n - 1) / 8)
	local byte = driver.readByte(addr)
	local shift = 7 - (n-1) % 8
	byte = bit32.band(byte, bit32.bnot(bit32.lshift(1, shift)))
	driver.writeByte(addr, byte)
end

local function getEntryName(block)
	local addr = 512 * block
	local name = driver.readBytes(addr + 7, 32, true)
	local nameEnd = name:find("\x00") or name:len()+1
	return name:sub(1, nameEnd-1)
end

local function getDirectoryChildren(block)
	local addr = 512 * block
	local numChildren = io.fromunum(driver.readBytes(addr + 43, 2, true))
	local children = {}
	for i=1, numChildren do
		local childId = io.fromunum(driver.readBytes(addr + 45 + (i-1)*2, 2, true))
		table.insert(children, childId)
	end
	return children
end

local function writeDirectoryEntry(block, opts)
	local addr = 512 * block
	driver.writeBytes(addr, "D\x00\x00\x00\x00")
	driver.writeBytes(addr + 5, io.tounum(opts.parent, 2))
	driver.writeBytes(addr + 7, opts.name .. ("\x00"):rep(32 - opts.name:len()))
	driver.writeBytes(addr + 39, io.tounum(opts.attributes, 4))
	driver.writeBytes(addr + 43, io.tounum(#opts.children, 2)) -- no childrens
	for i, child in pairs(opts.children) do
		driver.writeBytes(addr + 45 + (i-1)*2, io.tounum(child, 2))
	end
end

local function readDirectoryEntry(block)
	local addr = 512 * block
	return {
		parent = io.fromunum(driver.readBytes(addr + 5, 2, true)),
		name = getEntryName(block),
		attributes = io.fromunum(driver.readBytes(addr + 39, 4, true)),
		children = getDirectoryChildren(block)
	}
end

local function readFileEntry(block)
	local addr = 512 * block
	return {
		size = io.fromunum(driver.readBytes(addr + 1, 4, true)),
		parent = io.fromunum(driver.readBytes(addr + 5, 2, true)),
		name = getEntryName(block),
		attributes = io.fromunum(driver.readBytes(addr + 39, 4, true)),
		firstFragment = io.fromunum(driver.readBytes(addr + 43, 2, true))
	}
end

local function writeFileEntry(block, opts)
	local addr = 512 * block
	driver.writeBytes(addr, "F")
	driver.writeBytes(addr + 1, io.tounum(opts.size, 4))
	driver.writeBytes(addr + 5, io.tounum(opts.parent, 2))
	driver.writeBytes(addr + 7, opts.name .. ("\x00"):rep(32 - opts.name:len()))
	driver.writeBytes(addr + 39, io.tounum(opts.attributes, 4))
	driver.writeBytes(addr + 43, io.tounum(opts.firstFragment or 0, 2))
end

local function getEntryType(block)
	local addr = 512 * block
	local entryType = driver.readBytes(addr, 1, true)
	return entryType
end

local function isDirectory(block)
	return getEntryType(block) == "D"
end

local function getBlockId(path)
	-- canonicalize the path
	while path:sub(-1) == "/" do path = path:sub(1, path:len()-1) end
	if path:sub(1, 1) ~= "/" then path = "/" .. path end

	if path == "/" then
		return 18
	end
	local lastSlash = path:len()
	for i=path:len(), 1, -1 do
		if path:sub(i, i) == "/" then
			lastSlash = i
			break
		end
	end

	if _blockIds[path] then
		return _blockIds[path]
	end
	-- e.g. /home/a/b/c
	--               ^
	if path:sub(lastSlash, lastSlash) == "/" then
		local basepath = path:sub(1, lastSlash - 1)
		local filename = path:sub(lastSlash + 1)
		local baseId = getBlockId(basepath)
		-- TODO: check if it is really a directory
		if not isDirectory(baseId) then
			error(basepath .. " is not a directory")
		end

		for _, child in pairs(getDirectoryChildren(baseId)) do
			if getEntryName(child) == filename then
				_blockIds[path] = child
				return child
			end
		end
		error(path .. " (" .. filename .. ") does not exists")
	else
		error("API error '" .. path .. "'")
	end
end

local handles = {}

function fs.makeDirectory(path)
	path = filesystem.canonical(path)
	local parent = filesystem.path(path)
	local segments = filesystem.segments(path)
	local name = segments[#segments]
	if not fs.exists(parent) then
		return false, parent .. " does not exists"
	end
	if name:len() > 32 then
		return false, "name too long"
	end
	local parentBlock = getBlockId(parent)
	local parentEntry = readDirectoryEntry(parentBlock)
	local newBlock = allocateBlock()
	table.insert(parentEntry.children, newBlock)
	writeDirectoryEntry(newBlock, { parent = parentBlock, name = name, attributes = 0, children = {} })
	writeDirectoryEntry(parentBlock, parentEntry)

	return true
end

function fs.isDirectory(path)
	path = filesystem.canonical(path)
	local block = getBlockId(path)
	return getEntryType(block) == "D"
end

function fs.list(path)
	path = filesystem.canonical(path)
	local block = getBlockId(path)
	local list = {}
	for _, child in pairs(getDirectoryChildren(block)) do
		table.insert(list, getEntryName(child))
	end
	return list
end

function fs.open(path, mode)
	path = filesystem.canonical(path)
	if mode == "a" or mode == "ab" then
		error("TODO: append files")
	end

	if mode == "w" or mode == "wb" then
		if not fs.exists(path) then
			local parent = filesystem.path(path)
			local segments = filesystem.segments(path)
			local name = segments[#segments]
			if not fs.exists(parent) then
				return false, parent .. " does not exists"
			end
			if name:len() > 32 then
				return false, "name too long"
			end
			local parentBlock = getBlockId(parent)
			local parentEntry = readDirectoryEntry(parentBlock)
			local newBlock = allocateBlock()
			table.insert(parentEntry.children, newBlock)
			writeFileEntry(newBlock, { parent = parentBlock, name = name, attributes = 0, size = 0, firstFragment = 0 })
			writeDirectoryEntry(parentBlock, parentEntry)
			_blockIds[path] = newBlock
		end
	end

	local handle = math.random(0, 0xFFFFFFFF)
	local block = getBlockId(path)
	local entry = readFileEntry(block)
	handles[handle] = { block = block, path = path, cursor = 0, fragment = entry.fragment, size = entry.size, entry = entry }
	return handle
end

function fs.seek(handle, cur, off)
	if cur == "cur" and off == 0 then return end
	if cur == "beg" and off == handles[handle].cursor then return end
	error("seek unimplemented")
end

function fs.read(handle, len)
	if handles[handle].cursor >= handles[handle].size then
		return nil
	end
	handles[handle].cursor = handles[handle].cursor + len
	return ""
end

function fs.write(handle, data)
	local h = handles[handle]
	if #data > 0 then
		if h.fragment == 0 then
			h.fragment = allocateBlock()
			h.entry.firstFragment = h.fragment
			writeFileEntry(h.block, h.entry)
		end
		
	end
end

function fs.close(handle)
	handles[handle] = nil
end

function fs.exists(path)
	path = filesystem.canonical(path)
	local ok, err = pcall(getBlockId, path)
	if not ok then
		if not err:find("does not exists") then
			error(err)
		end
		return false
	else
		return true
	end
end

function fs.spaceUsed()
	local used = 0
	for _, isAllocated in pairs(getAllocatedBlocks()) do
		if isAllocated then
			used = used + 512
		end
	end
	return used
end

function fs.spaceTotal()
	return driver.getCapacity()
end

function fs.asFilesystem()
	return {
		exists = fs.exists,
		makeDirectory = fs.makeDirectory,
		isDirectory = fs.isDirectory,
		list = fs.list,
		open = fs.open,
		seek = fs.seek,
		read = fs.read,
		write = fs.write,
		close = fs.close,
		spaceUsed = fs.spaceUsed,
		spaceTotal = fs.spaceTotal,

		address = partitionUUID or driver.address
	}
end

function fs.format()
	local str = "NTRFS2" -- signature
		.. "FCH2" -- attribute type
		.. io.tounum(0, 2, false, true) -- boot file
		.. io.tounum(1, 1, false, true) -- block allocation: bit map
	driver.writeBytes(0, str)
	driver.writeBytes(512, ("\x00"):rep(8192))
	driver.writeBytes(512, "\xff\xff\x80") -- reserve the 17 first blocks

	local block = allocateBlock()
	writeDirectoryEntry(block, { parent = 0, name = "", attributes = 0, children = {} })
	return true
end

function fs.isFormatted()
	local head = driver.readBytes(1, 6, true)
	return head == "NTRFS2"
end

return fs, "NitroFS+", "NitroFS+" -- in order: driver, 8-char FS name, fs name 
