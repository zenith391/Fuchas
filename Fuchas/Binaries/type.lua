local shell = require("shell")
local filesystem = require("filesystem")

local args, opts = shell.parse(...)

if #args < 1 then
	io.stderr:write("Usage: type <file>")
	return
end

local file = shell.resolve(file)
if not file then
	io.stderr:write("No such file: " .. file)
	return
end

local stream = io.open(file, "r")
io.stdout:write(stream:read("a"))
stream:close()
