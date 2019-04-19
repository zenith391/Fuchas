local args = ...

local filesystem = require("filesystem")
local gpu = component.getPrimary("gpu")
local drive = shin32.getSystemVar("PWD_DRIVE")
local pwd = shin32.getSystemVar("PWD")
local fullPath = drive .. ":/" .. pwd

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
	print(k)
end
gpu.setForeground(0xFFFFFF)