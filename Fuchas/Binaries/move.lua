-- Copy program
local shell = require("shell")
local filesystem = require("filesystem")
local args, options = shell.parse(...)

if #args < 2 then
	print("Usage: move [-r] [-v] src dest")
	print("-v: Verbose")
	print("-r: Recursive")
	return
end

local function move(src, dst)
	if options.v then
		print(src .. " -> " .. dst)
	end
	filesystem.rename(src, dst)
end

local function moveDir(src, dst)
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
			moveDir(path, dst .. "/" .. k)
		else
			move(path, dst .. "/" .. k)
		end
	end
end

local src = shell.resolveToPwd(args[1])
local dst = shell.resolveToPwd(args[2])

if options.r then
	if not filesystem.exists(dst) then
		if options.v then
			print("Creating " .. dst)
		end
		filesystem.makeDirectory(dst)
	end
	moveDir(src, dst)
else
	move(src, dst)
end

print("Moved.")
