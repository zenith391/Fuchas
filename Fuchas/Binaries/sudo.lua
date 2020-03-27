-- executes command as "admin" (* permission)
local security = require("security")
local shell = require("shell")
local args, opts = shell.parse(...)

if #args < 1 then
	io.stderr:write("Usage: sudo <command>\n")
	return
end

local cmd = args[1]
table.remove(args, 1)

local name = opts["user"] or opts["u"] or "admin"
io.write("[sudo] Password of " .. name .. ": ")
local pass = shell.read({
	history = {},
	pwchar = '*'
})
io.write(" \n")

local ok, reason = require("users").login(name, pass)
if not ok then
	io.stderr:write("Could not login because " .. reason .. "\n")
	return
end

local res = shell.resolve(cmd)
if res == nil then
	io.stderr:write(cmd .. " not found.\n")
	return
end

security.requestPermission("*")
local f, err = loadfile(res)
if f then
	f(args)
else
	error(err)
end
require("users").logout()
