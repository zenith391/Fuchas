local shell = require("shell")
local args, opts = shell.parse(...)

local str = ""

local out = {}

if opts.a then
	opts.s = true; opts.r = true; opts.v = true; opts.p = true; opts.o = true;
end

if opts.s then
	table.insert(out, "Fuchas Kernel")
end

if opts.r then
	table.insert(out, OSDATA.VERSION)
end

if opts.v then
	table.insert(out, OSDATA.BUILD_DATE)
end

if opts.p then
	table.insert(out, _VERSION)
end

if opts.o then
	table.insert(out, "Fuchas")
end

print(table.concat(out, " "))
