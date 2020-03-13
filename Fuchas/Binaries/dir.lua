local filesystem = require("filesystem")
local shell = require("shell")
local gpu = require("driver").getDriver("gpu")
local drive = os.getenv("PWD_DRIVE")
local pwd = os.getenv("PWD")
local x = 1
local vw, vh = gpu.getResolution()

local args, ops = shell.parse(...)

local fullPath = drive .. ":/" .. pwd .. (args[1] and "/" .. args[1]) or ""

local list = filesystem.list(fullPath)
print("List of " .. fullPath)
for k, v in list do
	local fp = filesystem.concat(filesystem.canonical(fullPath), k)
	local isdir = filesystem.isDirectory(fp)
	if isdir then
		gpu.setForeground(0x00FF00)
	else
		gpu.setForeground(0x0000FF)
	end
	if x + k:len() > vw then
		shell.setCursor(1, shell.getY()+1)
		x = 0
	end
	io.write(k .. " ")
	x = x + k:len() + 1
	if not ops.i then x = math.huge end
end
print(" ")
gpu.setForeground(0xFFFFFF)
