local filesystem = require("filesystem")
local shell = require("shell")
local args, ops = shell.parse(...)

if #args < 1 then
	io.stderr:write("Usage: attr <file/directory>\n")
	return
end

local path = shell.resolve(args[1])
if path == nil or not filesystem.exists(path) then
	io.stderr:write(path .. " doesn't exists\n")
	return
end

local tab = filesystem.getAttributes(path)

for k, v in pairs(tab) do
	print(k .. ": " .. tostring(v))
end