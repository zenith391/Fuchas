local filesystem = require("filesystem")
local shell = require("shell")
local gpu = require("driver").getDriver("gpu")
local pwd = os.getenv("PWD")
local fullPath = pwd
local x = 1
local vw, vh = gpu.getResolution()

local args, ops = shell.parse(...)
if args[1] then
	fullPath = shell.resolve(args[1])
	if not fullPath then
		error("dir: could not access '" .. fullPath .. "': No such file or directory.")
	end
end

if not filesystem.isDirectory(fullPath) then
	error("dir: could not access '" .. fullPath .. "': Path is not directory.")
end

local list = filesystem.list(fullPath)
print("Listing of " .. fullPath)
local CSI = string.char(0x1B) .. "["
for k, v in list do
	local fp = filesystem.concat(filesystem.canonical(fullPath), k)
	local isdir = filesystem.isDirectory(fp)
	if x + k:len() > vw then
		io.write("\n")
		x = 0
	end
	if isdir then
		io.write(CSI .. "38;2;68;68;255m")
	else
		io.write(CSI .. "38;2;51;255;51m")
	end
	io.write(k .. " ")
	x = x + k:len() + 1
	if not ops.i then x = math.huge end
end
print(" ")
gpu.setForeground(0xFFFFFF)
