-- executes command as "admin" (* permission)
local security = require("security")
local shell = require("shell")
local args = ...

if #args < 3 then
	io.stderr:write("Usage: as <username> <password> <command>\n")
	return
end

local name = args[1]
local pass = args[2]
local cmd = args[3]
table.remove(args, 1)
table.remove(args, 1)
table.remove(args, 1)

local ok, reason = require("users").login(name, pass)
if not ok then
	io.stderr:write("Could not login] " .. reason .. "\n")
	return
end

local res = shell.resolve(cmd)
if res == nil then
	io.stderr:write(cmd .. " not found.\n")
	return
end

security.requestPermission("*")
loadfile(res)(args)