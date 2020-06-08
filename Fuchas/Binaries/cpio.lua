local shell = require("shell")
local cpio = require("cpio")
local filesystem = require("filesystem")
local args, ops = shell.parse(...)

if ops.o or ops.output and args[1] then
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
			table.insert(archive, entry)
		end
	end

	local stream = io.open(output, "w")
	cpio.write(archive, stream)
	stream:close()
elseif ops.e or ops.extract then
	io.stderr:write("Extract not yet supported.\n")
else
	print("Usage:")
	print("cpio [-o|-e] <file>")
	print("-e|--extract: Extract a CPIO archive to PWD")
	print("-o|--output: Write a CPIO archive")
	print("Can be used like so: 'find . | cpio -o myCpio.cpio'")
end
