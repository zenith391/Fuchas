local filesystem = {}
local drives = {}

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
			error("no drive separator found (missing \":\", " .. seg[1] .. ")")
		end
		if not drives[let] then
			error("Invalid drive letter: " .. let)
		end
		return drives[let]
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
  local node = findNode(path)
  if node.fs then
	local proxy = node.fs
	path = ""
	while node and node.parent do
	  path = filesystem.concat(node.name, path)
	  node = node.parent
	end
	path = filesystem.canonical(path)
	if path ~= "/" then
	  path = "/" .. path
	end
	return proxy, path
  end
  return nil, "no such file system"
end

function filesystem.realPath(path)
  checkArg(1, path, "string")
  local node, rest = findNode(path, false, true)
  if not node then return nil, rest end
  local parts = {rest or nil}
  repeat
	table.insert(parts, 1, node.name)
	node = node.parent
  until not node
  return table.concat(parts, "/")
end

function filesystem.mountDrive(fs, letter)
	if letter:len() ~= 1 then
		return false, "invalid length"
	end
	drives[letter:upper()] = component.proxy(fs)
	return true
end

function filesystem.path(path)
  local parts = segments(path)
  local result = table.concat(parts, "/", 1, #parts - 1) .. "/"
  if unicode.sub(path, 1, 1) == "/" and unicode.sub(result, 1, 1) ~= "/" then
	return "/" .. result
  else
	return result
  end
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
  if not filesystem.realPath(filesystem.path(path)) then
	return false
  end 
  local node, rest, vnode, vrest = findNode(path)
  if not vrest or vnode.links[vrest] then -- virtual directory or symbolic link
	return true
  elseif node and node.fs then
	return node.fs.exists(rest)
  end
  return false
end

function filesystem.isDirectory(path)
  local real, reason = filesystem.realPath(path)
  if not real then return nil, reason end
  local node, rest, vnode, vrest = findNode(real)
  if not vnode.fs and not vrest then
	return true -- virtual directory (mount point)
  end
  if node.fs then
	return not rest or node.fs.isDirectory(rest)
  end
  return false
end

function filesystem.list(path)
	local node = findNode(path)
	local result = {}
	if node then
		result = {}
		local segs = filesystem.segments(path)
		table.remove(segs, 1)
		local localPath = table.concat(segs, "/")
		result = node.list(localPath)
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

function filesystem.remove(path)
	--return require("tools/fsmod").remove(path, findNode)
end

function filesystem.rename(oldPath, newPath)
	--return require("tools/fsmod").rename(oldPath, newPath, findNode)
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
