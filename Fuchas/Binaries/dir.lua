local filesystem = require("filesystem")
local shell = require("shell")
local gpu = component.getPrimary("gpu")
local drive = shin32.getSystemVar("PWD_DRIVE")
local pwd = shin32.getSystemVar("PWD")
local fullPath = drive .. ":/" .. pwd
local x = 1
local vw, vh = gpu.getViewport()

local args, ops = shell.parse(...)

local list = filesystem.list(fullPath)

print("List of " .. fullPath)
for k, v in list do
	local fp = filesystem.concat(filesystem.canonical(fullPath), k)
	--print(fp)
	local isdir = filesystem.isDirectory(fp)
	if isdir then
		gpu.setForeground(0x00FF00)
	else
		gpu.setForeground(0x0000FF)
	end
	if x + k:len() > vw then
		require("shell").setCursor(1, require("shell").getY()+1)
		x = 0
	end
	io.write(k .. " ")
	x = x + k:len() + 1
	if not ops.i then x = math.huge end
end
print(" ")
gpu.setForeground(0xFFFFFF)