local filesystem = {}
local drives = {}
local noBit32 = OSDATA.CONFIG["NO_52_COMPAT"] -- cannot be changed by program as filesystem is initialized before any outside program.

local function readAll(node, path)
	local handle = node.open(path, "r")
	local buf = ""
	local data = ""
	while data ~= nil do
		buf = buf .. data
		data = node.read(handle, math.huge)
	end
	node.close(handle)
	return buf
end

local function writeAllTo(node, path, content)
	local handle = node.open(path, "w")
	node.write(handle, content)
	node.close(handle)
end

local function segments(path)
	local parts = {}
	for part in path:gmatch("[^\\/]+") do
		local current, up = part:find("^%.?%.$")
		if current then
			if up == 2 then
				table.remove(parts)
			end
		else
			table.insert(parts, part)
		end
	end
	return parts
end

local function findNode(path)
	checkArg(1, path, "string")
	local seg = segments(path)
	if #seg > 0 then
		local let = seg[1]:sub(1, 1)
		if seg[1]:sub(2, 2) ~= ":" then
			error("no drive separator found (missing \":\", " .. seg[1] .. ") in " .. path)
		end
		if not drives[let] then
			error("Invalid drive letter: " .. let)
		end
		local d = drives[let]
		return d.fs, path:sub(3, path:len()), d
	end
end

-------------------------------------------------------------------------------

function filesystem.canonical(path)
	return table.concat(segments(path), "/")
end

function filesystem.concat(...)
	local set = table.pack(...)
	for index, value in ipairs(set) do
		checkArg(index, value, "string")
	end
	return filesystem.canonical(table.concat(set, "/"))
end

function filesystem.get(path)
	local node, rest = findNode(path)
	if node then
		path = filesystem.canonical(path)
		return node, rest
	end
	return nil, "no such file system"
end

function filesystem.realPath(path)
	local p = filesystem.path(path)
	p = node.letter .. ":/" .. p
	return p
end

function filesystem.unmountDrive(letter)
	if letter:len() ~= 1 then
		return false, "invalid length"
	end
	drives[letter:upper()] = nil
	return true
end

function filesystem.isDriveFormatted(letter)
	local drive = drives[letter:upper()]
	if drive == nil then
		error("invalid drive: " .. letter .. ":/")
	end
	if drive.unmanaged then
		return (drive.fs.readSector(0) == string.rep(string.char(0), drive.fs.getSectorSize()))
	else
		return true
	end
end

function filesystem.isMounted(letter)
	return drives[letter:upper()] ~= nil
end

function filesystem.freeDriveLetter()
	local letter = "A"
	for k in pairs(drives) do
		if k == letter then
			if letter == "Z" then -- Z: is maximum letter
				return nil
			end
			letter = string.char(string.byte(letter) + 1)
		end
	end
	return letter
end

function filesystem.getLetter(address)
	for k, v in pairs(drives) do
		if v.fs.address == address then
			return k
		end
	end
end

function filesystem.getDrive(path)
	return findNode(path)
end

function filesystem.mounts()
	return drives
end

function filesystem.mountDrive(proxy, letter)
	if letter:len() ~= 1 then
		return false, "invalid length"
	end
	drives[letter:upper()] = {
		fs = proxy,
		unmanaged = (proxy.type == "drive"),
		letter = letter
	}
	return true
end

function filesystem.getProxy(letter)
	if letter:len() ~= 1 then
		return false, "invalid length"
	end
	return drives[letter:upper()]
end

function filesystem.path(path)
	local parts = segments(path)
	local result = table.concat(parts, "/", 1, #parts - 1) .. "/"
	return result
end

function filesystem.name(path)
	checkArg(1, path, "string")
	local parts = segments(path)
	return parts[#parts]
end

function filesystem.exists(path)
	if path:len() < 2 then
		return false
	else
		if path:sub(2, 2) ~= ":" then
			return false
		end
	end
	local node, rest = findNode(path)
	if node then
		return node.exists(rest)
	end
	return false
end

function filesystem.isDirectory(path)
	if not filesystem.exists(path) then return false end
	local node, rest = findNode(path)
	if node == nil then return false end
	return node.isDirectory(rest)
end

function filesystem.setAttributes(path, raw)
	local node, rest = findNode(path)
	if node then
		if node.setAttributes then
			node.setAttributes(path, raw)
		else
			
		end
	end
end

function filesystem.getAttributes(path, raw)
	local attr = nil
	local node, rest = findNode(path)
	if node then
		if node.getAttributes then -- unmanaged node that supports attributes natively
			attr = node.getAttributes(path)
		else
			local dir = nil
			local issame = false
			if filesystem.isDirectory(path) then
				dir = path
				if dir:sub(dir:len(), dir:len()) ~= "/" then
					dir = dir .. "/"
				end
				--print(dir)
				issame = true
			else
				dir = filesystem.path(path)
			end
			if filesystem.exists(dir .. ".dir") then
				local node2, rest2 = findNode(dir .. ".dir")
				local content = readAll(node2, rest2)
				local dirAttr = string.byte(content:sub(1, 1))
				if issame then
					attr = dirAttr
				else
					local filesNum = string.byte(content:sub(2, 2))
					local addr = 3
					for i=1, filesNum do
						local len = string.byte(content:sub(addr, addr))
						local name = dir .. content:sub(addr+1, addr+1+len)
						local att = content:sub(addr+2+len, addr+2+len)
						if name == path then
							attr = att
						end
						addr = addr + len + 3
					end
					if attr == nil then
						attr = dirAttr -- no attributes for the specific file
					end
				end
			else
				if dir:len() <= 3 then
					attr = 0
				else
					attr = filesystem.getAttributes(filesystem.path(dir), true)
				end
			end
		end
	end
	if raw then
		return attr
	else
		if bit32 and bit32.band then
			return {
				readOnly = (bit32.band(attr, 1) == 1), -- always read-only
				system = (bit32.band(attr, 2) == 2), -- protected in Read
				protected = (bit32.band(attr, 4) == 4), -- protected in Read/Write
				hidden = (bit32.band(attr, 8) == 8), -- hidden
				noExecute = (bit32.band(attr, 16) == 16) -- not executable (even if the filename suggests it)
			}
		elseif _VERSION ~= "Lua 5.2" then
			return load([[
				local attr = ...
				return {
					readOnly = ((attr & 1) == 1),
					system = ((attr & 2) == 2),
					protected = ((attr & 4) == 4),
					hidden = ((attr & 8) == 8),
					noExecute = ((attr & 16) == 16),
				}
			]])(attr)
		else
			return {} -- unsafe, but only way as we're on Lua 5.2 and we don't have bit32.
			-- Breaking compatibility (using OS arguments) is recommended if on Lua 5.3
		end
	end
end

function filesystem.list(path)
	local node, rest = findNode(path)
	local result = {}
	if node then
		result = node.list(rest)
	else
		error("no drive found for " .. tostring(path))
	end
	local set = {}
	local keys = {}
	table.sort(result)
	for _,name in ipairs(result) do
		if name ~= ".dir" and type(name) == "string" then
			local key = filesystem.canonical(name)
			set[key] = name
			table.insert(keys, key)
		end
	end
	local i = 1
	setmetatable(set, {
		__call = function()
			if i == #keys+1 then
				return nil
			end
			i = i + 1
			return keys[i-1], set[keys[i-1]]
		end
	})
	return set
end

function filesystem.makeDirectory(path)
	local node, rest = findNode(path)
	if node then
		if not node.makeDirectory(rest) then
			error("could not create directory")
		end
	else
		error("no drive")
	end
end

function filesystem.remove(path)
	local node, rest = findNode(path)
	if not node then
		return false
	end
	return node.remove(rest)
end

function filesystem.rename(oldPath, newPath)
	local oldNode, oldRest = findNode(oldPath)
	local newNode, newRest = findNode(newPath)
	if oldNode == newNode then
		return oldNode.rename(oldRest, newRest)
	else
		if not oldNode.exists(oldRest) then
			return false
		end
		local content = readAll(oldNode, oldRest)
		writeAllTo(newNode, newRest, content)
	end
end

function filesystem.unmanagedFilesystems()
	return {}
end

function filesystem.copy(src, dest)
	local oldNode, oldRest = findNode(src)
	local newNode, newRest = findNode(dest)
	local dat = readAll(oldNode, oldRest)
	writeAllTo(newNode, newRest, dat)
end

function filesystem.open(path, mode)
	checkArg(1, path, "string")
	mode = tostring(mode or "r")
	checkArg(2, mode, "string")
	assert(({r=true, rb=true, w=true, wb=true, a=true, ab=true})[mode],
		"bad argument #2 (r[b], w[b] or a[b] expected, got " .. mode .. ")")
	local attributes = filesystem.getAttributes(path)
	if attributes.protected then
		if not require("security").hasPermission("file.protected") then
			return nil, "not enough permissions"
		end
	end
	if mode ~= "r" and mode ~= "rb" and attributes.system and package.loaded.security then
		if not require("security").hasPermission("file.system") then
			return nil, "not enough permissions"
		end
	end
	if mode ~= "r" and mode ~= "rb" then
		local parts = segments(path)
		if parts[#parts] == ".dir" then
			return nil, "file not found"
		end
	end
	local node, rest = findNode(path)
	local segs = segments(path)
	table.remove(segs, 1)
	if not node then
		return nil, "drive not found"
	end
	if (({r=true,rb=true})[mode] and not node.exists(rest)) then
		return nil, "file not found"
	end
	local handle, reason = node.open(rest, mode)
	if not handle then
		return nil, reason
	end

	local function create_handle_method(key)
		return function(self, ...)
			if not self.handle then
				return nil, "file closed"
			end
			return self.fs[key](self.handle, ...)
		end
	end
	local cproc = nil
	if package.loaded.tasks then cproc = require("tasks").getCurrentProcess() end
	local stream =
	{
		fs = node,
		handle = handle,
		proc = cproc,
		close = function(self)
			if self.handle then
				self.fs.close(self.handle)
				self.handle = nil
				if self.proc ~= nil then
					for k, v in pairs(self.proc.exitHandlers) do
						if v == exitHandler then
							table.remove(self.proc.exitHandlers, k)
							break
						end
					end
				end
			end
		end
	}
	stream.read = create_handle_method("read")
	stream.seek = create_handle_method("seek")
	stream.write = create_handle_method("write")
	if stream.proc ~= nil then
		stream.exitHandler = function()
			stream:close()
		end
		table.insert(stream.proc.exitHandlers, stream.exitHandler)
	end
	return stream
end

filesystem.findNode = findNode
filesystem.segments = segments

-------------------------------------------------------------------------------

return filesystem
