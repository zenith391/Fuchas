local filesystem = require("filesystem")
local shell = require("shell")
local args, opts = shell.parse(...)

if #args < 1 then
	print("Usage: mkdir [-v] <paths..>")
	print("-v: Verbose")
end

for _, path in pairs(args) do
	local resolved = shell.resolveToPwd(path)
	if filesystem.exists(resolved) then
		io.stderr:write("Folder " .. path .. " already exists.")
	else
		filesystem.makeDirectory(resolved)
		if opts.v then
			print("Created folder " .. path)
		end
	end
end