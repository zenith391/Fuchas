local shell = require("shell")
local filesystem = require("filesystem")
local args, options = shell.parse(...)

if #args < 1 then
	print("Usage: delete [-r] [-v] src")
	print("-v: Verbose")
	print("-r: Recursive")
	return
end

local function del(src)
	if options.v then
		print("Deleting " .. src)
	end
	filesystem.remove(src)
end

local function delDir(src)
	if not filesystem.isDirectory(src) then
		print("Source isn't directory")
		return
	end
	if options.v then
		print("Deleting " .. src)
	end
	local name = filesystem.name(src)
	for k, v in filesystem.list(src) do
		local path = src .. "/" .. k
		if filesystem.isDirectory(path) then
			delDir(path)
			filesystem.remove(path)
		else
			del(path)
		end
	end
end

local src = shell.resolve(args[1]) or args[1]

if options.r then
	if not filesystem.exists(src) then
		print("No source directory")
		return
	end
	delDir(src)
	filesystem.remove(src)
else
	del(src)
end

print("Deleted.")