local driver = require("driver")
local shell = require("shell")
local filesystem = require("filesystem")
local args, ops = shell.parse(...)

if #args < 1 then
	io.stderr:write("Usage: print <file>\n")
	return
end

local path = shell.resolve(args[1])
if path == nil then
	io.stderr:write("Cannot resolve " .. args[1] .. "\n")
	return
end

if filesystem.isDirectory(path) then
	io.stderr:write(path .. " is not a file\n")
	return
end

local file = io.open(path, "r")
if file == nil then
	io.stderr:write("Cannot open " .. path .. "\n")
	return
end

local printer = driver.getDriver("printer")
if printer == nil then
	file:close()
	io.stderr:write("No printer available\n")
	return
end

local txt = file:read("a")
local out = printer.out()
out:write(txt)
out:print()

file:close()