local args = ...

local filesystem = require("filesystem")
local drive = shin32.getSystemVar("PWD_DRIVE")
local pwd = shin32.getSystemVar("PWD")
local fullPath = drive .. ":/" .. pwd

local current = filesystem.canonical(fullPath)

if #args < 1 then
	print(current .. "/")
	return
end

if args[1]:sub(1, 1) == '/' then
	pwd = ""
	args[1] = args[1]:sub(2, args[1]:len())
end
local canon = filesystem.canonical(pwd) .. "/"
if canon:sub(1, 1) == '/' then
	canon = canon:sub(2, canon:len())
	print(canon)
end
local newPath = canon .. args[1]
if filesystem.exists(drive .. ":" .. filesystem.canonical(newPath)) then
	shin32.setSystemVar("PWD", filesystem.canonical(newPath))
else
	print(drive .. ":" .. newPath .. " doesn't exists.")
end