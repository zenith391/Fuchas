local fs = {}
local tfs = require("filesystem") -- true FS

function fs.isAutorunEnabled()
	return false
end

function fs.setAutorunEnabled(value) end

local function fixPath(path)
	if path:sub(1,1) == "/" then
		path = "A:/Users/Shared/StardustData" .. path
	end
	return path
end

function fs.canonical(path)
	return tfs.canonical(fixPath(path))
end

function fs.segments(path)
	return tfs.segments(fixPath(path))
end

function fs.concat(pathA, pathB, ...)
	local set = table.pack(set)
	for k, v in ipairs(set) do
		set[k] = fixPath(v)
	end
end

function fs.path(path)
	return tfs.path(fixPath(path))
end

function fs.name(path)
	return tfs.name(fixPath(path))
end

function fs.proxy(filter)
	return tfs.proxy(filter) -- dangerous, TODO: change
end

function fs.mount(fs, path)
	return nil, "cannot mount from stardust: not yet supported"
end

function fs.mounts()
	return tfs.mounts()
end

function fs.umount(fs)
	return false
end

function fs.isLink(path)
	return false
end

function fs.link(target, linkPath)
	return false
end

function fs.get(path)
	return tfs.get(fixPath(path))
end

function fs.makeDirectory(path)
	if fs.exists(path) then
		return false, "directory already exists"
	else
		return tfs.makeDirectory(fixPath(path))
	end
end

function fs.isDirectory(path)
	return tfs.isDirectory(fixPath(path))
end

function fs.exists(path)
	return tfs.exists(fixPath(path))
end

function fs.open(path, mode)
	return tfs.open(fixPath(path), mode)
end

return fs
