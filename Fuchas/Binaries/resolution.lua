local shell = require("shell")
local gpu = require("driver").gpu
local args, opts = shell.parse(...)

if #args < 2 then
	io.stderr:write("Usage: resolution [width] [height]\n")
	return
end

local width = tonumber(args[1])
local height = tonumber(args[2])

if not width or not height then
	io.stderr:write("Invalid resolution\n")
	return
end

gpu.setResolution(width, height)
