local shell = require("shell")
local args, opts = shell.parse(...)

local str = ""

local out = {}

if opts.a or opts.all then
	for _, k in pairs({"s","r","v","m","p","i","o"}) do
		opts[k] = true
	end
end

if not opts.s and not opts.r and not opts.v and not opts.m and not opts.p and
	not opts.i and not opts.o then
	opts.s = true
end

if opts.s or opts["kernel-name"] then
	table.insert(out, "Fuchas Kernel")
end

if opts.r or opts["kernel-release"] then
	table.insert(out, OSDATA.VERSION)
end

if opts.v or opts["kernel-version"] then
	table.insert(out, OSDATA.BUILD_DATE)
end

if opts.m or opts.machine then
	table.insert(out, _VERSION)
end

if opts.p or opts.processor then
	table.insert(out, _VERSION)
end

if opts.i or opts["hardware-platform"] then
	table.insert(out, _VERSION)
end

if opts.o or opts["operating-system"] then
	table.insert(out, "Fuchas")
end

print(table.concat(out, " "))
