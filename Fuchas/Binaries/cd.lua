local args = ...

local filesystem = require("filesystem")
local pwd = os.getenv("PWD")
local drive = pwd:sub(1, 3)

local current = filesystem.canonical(pwd)

if #args < 1 then
	print(current .. "/")
	return
end

if args[1]:sub(1, 1) == '/' then
	pwd = drive
	args[1] = args[1]:sub(2)
end
local canon = filesystem.canonical(pwd:sub(4)) .. "/"
if canon:sub(1, 1) == '/' then
	canon = canon:sub(2, canon:len())
end
local newPath = canon .. args[1]
local effectivePath = drive .. filesystem.canonical(newPath)
if filesystem.exists(effectivePath) and filesystem.isDirectory(effectivePath) then
	os.setenv("PWD", effectivePath)
else
	if not filesystem.exists(effectivePath) then
		print(newPath .. " doesn't exists.")
	else
		print(newPath .. " isn't a directory.")
	end
end
