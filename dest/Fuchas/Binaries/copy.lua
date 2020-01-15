-- Copy program
local shell = require("shell")
local filesystem = require("filesystem")
local args, options = shell.parse(...)

if #args < 2 then
	print("Usage: copy [-r] [-v] src dest")
	print("-v: Verbose")
	print("-r: Recursive")
	return
end

local function copy(src, dst)
	if options.v then
		print(src .. " -> " .. dst)
	end
	filesystem.copy(src, dst)
end

local function copyDir(src, dst)
	if not filesystem.isDirectory(src) or not filesystem.isDirectory(dst) then
		print("Source or destination isn't directory")
		return
	end
	if options.v then
		print(src .. " -> " .. dst)
	end
	local name = filesystem.name(src)
	for k, v in filesystem.list(src) do
		local path = src .. "/" .. k
		if filesystem.isDirectory(path) then
			if not filesystem.exists(dst .. "/" .. k) then
				filesystem.makeDirectory(dst .. "/" .. k)
			end
			copyDir(path, dst .. "/" .. k)
		else
			copy(path, dst .. "/" .. k)
		end
	end
end

local src = shell.resolve(args[1]) or args[1]
local dst = shell.resolve(args[2]) or args[2]

if options.r then
	if not filesystem.exists(dst) then
		if options.v then
			print("Creating " .. dst)
		end
		filesystem.makeDirectory(dst)
	end
	copyDir(src, dst)
else
	copy(src, dst)
end

print("Copied.")