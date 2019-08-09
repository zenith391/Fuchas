-- executes command as "admin" (* permission)
local security = require("security")
local shell = require("shell")
local args = ...

if #args < 1 then
	io.stderr:write("Usage: sudo <command>\n")
	return
end

local cmd = args[1]
table.remove(args, 1)

local res = shell.resolve(cmd)
if res == nil then
	io.stderr:write(cmd .. " not found.\n")
	return
end

security.requestPermission("*")

loadfile(res)(table.unpack(args))