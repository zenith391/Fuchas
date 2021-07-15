-- executes command as "admin" (* permission)
local security = require("security")
local shell = require("shell")
local users = require("users")
local args, opts = shell.parse(...)

if #args < 1 and not opts.s then
	io.stderr:write("Usage: sudo <command>\n")
	return
end

local cmd = args[1]
if not opts.s then
	table.remove(args, 1)
end

local name = opts["user"] or opts["u"] or "admin"
local doLogin = true
if users.getUser() then
	if users.getUser().username == name then
		doLogin = false
	end
end

if doLogin then
	io.write("[sudo] Password of " .. name .. ": ")
	local pass = shell.read({
		history = {},
		pwchar = '*'
	})
	io.write(" \n")

	local ok, reason = users.login(name, pass)
	if not ok then
		io.stderr:write("Could not login because " .. reason .. "\n")
		return
	end
end

if opts.s then
	cmd = "A:/Fuchas/Interfaces/" .. os.getenv("INTERFACE") .. "/main.lua"
end

local res = shell.resolve(cmd)
if res == nil then
	io.stderr:write(cmd .. " not found.\n")
	return
end

security.requestPermission("*")
require("tasks").getCurrentProcess().name = cmd
local f, err = loadfile(res)
if f then
	f(args)
else
	error(err)
end
require("users").logout()
