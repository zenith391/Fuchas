local shell = require("shell")
local cpio = require("cpio")
local filesystem = require("filesystem")
local args, ops = shell.parse(...)

if ops.o or ops.create and args[1] then
	local output = shell.resolve(args[1], true)
	local archive = {}
	while not io.stdin.closed or io.stdin:remaining() do
		local line = io.stdin:read("l")
		if line then
			local path = shell.resolve(line)
			print(line)
			local entry = {
				data = "",
				name = line
			}
			if filesystem.isDirectory(path) then
				entry.isDirectory = true
			else
				entry.isFile = true
				local s = io.open(path)
				entry.data = s:read("a")
				s:close()
			end
			if line ~= ".dir" or ops["include-attributes"] then
				table.insert(archive, entry)
			end
		end
	end

	local stream = io.open(output, "w")
	cpio.write(archive, stream)
	stream:close()
elseif ops.i or ops.extract then
	io.stderr:write("Extract not yet supported.\n")
else
	local doc = io.open("A:/Fuchas/Documentation/commands/cpio.od", "r")
	if doc then
		print(doc:read("*a"))
		doc:close()
	else
		print("Example: find . | cpio -o myCpio.cpio")
	end
end
