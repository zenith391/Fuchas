local filesystem = require("filesystem")
local shell = require("shell")
local gpu = require("driver").getDriver("gpu")
local drive = os.getenv("PWD_DRIVE")
local pwd = os.getenv("PWD")
local fullPath = drive .. ":/" .. pwd
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
for k, v in list do
	local fp = filesystem.concat(filesystem.canonical(fullPath), k)
	local isdir = filesystem.isDirectory(fp)
	if isdir then
		gpu.setForeground(0x33FF33)
	else
		gpu.setForeground(0x4444FF)
	end
	if x + k:len() > vw then
		io.write(" \n")
		x = 0
	end
	io.write(k .. " ")
	x = x + k:len() + 1
	if not ops.i then x = math.huge end
end
print(" ")
gpu.setForeground(0xFFFFFF)
