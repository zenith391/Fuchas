local filesystem = {}
local drives = {}

local function readAll(node, path)
	local handle = node.open(path)
	local buf = ""
	local data = ""
	while data ~= nil do
		buf = buf .. data
		data = node.read(handle, math.huge)
	end
	node.close(handle)
end

local function writeAllTo(node, path, content)
	local handle = node.open(path)
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
		d.letter = let
		return d, path:sub(3, path:len())
	end
end

-------------------------------------------------------------------------------

function filesystem.canonical(path)
  local result = table.concat(segments(path), "/")
  if unicode.sub(path, 1, 1) == "/" then
	return "/" .. result
  else
	return result
  end
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

function filesystem.mountDrive(proxy, letter)
	if letter:len() ~= 1 then
		return false, "invalid length"
	end
	drives[letter:upper()] = proxy
	return true
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

function filesystem.proxy(filter, options)
	checkArg(1, filter, "string")
	if not component.list("filesystem")[filter] or next(options or {}) then
		-- if not, load fs full library, it has a smarter proxy that also supports options
		return filesystem.internal.proxy(filter, options)
	end
	return component.proxy(filter) -- it might be a perfect match
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

function filesystem.list(path)
	local node, rest = findNode(path)
	local result = {}
	if node then
		result = node.list(rest)
	end
	local set = {}
	for _,name in ipairs(result) do
		set[filesystem.canonical(name)] = name
	end
	return function()
		local key, value = next(set)
		set[key or false] = nil
		return value
	end
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

function filesystem.open(path, mode)
	checkArg(1, path, "string")
	mode = tostring(mode or "r")
	checkArg(2, mode, "string")

	assert(({r=true, rb=true, w=true, wb=true, a=true, ab=true})[mode],
		"bad argument #2 (r[b], w[b] or a[b] expected, got " .. mode .. ")")

	local node = findNode(path)
	local segs = segments(path)
	table.remove(segs, 1)
	local rest = table.concat(segs, "/")
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
				return nil, "file is closed"
			end
			return self.fs[key](self.handle, ...)
		end
	end

	local stream =
	{
		fs = node,
		handle = handle,
		close = function(self)
			if self.handle then
				self.fs.close(self.handle)
				self.handle = nil
			end
		end
	}
	stream.read = create_handle_method("read")
	stream.seek = create_handle_method("seek")
	stream.write = create_handle_method("write")
	return stream
end

filesystem.findNode = findNode
filesystem.segments = segments

-------------------------------------------------------------------------------

return filesystem
