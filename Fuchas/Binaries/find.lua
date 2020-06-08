local shell = require("shell")
local filesystem = require("filesystem")
local args, ops = shell.parse(...)

local function recursiveSearch(n, dir)
	for name in filesystem.list(dir) do
		local path = filesystem.concat(dir, name)
		local nName = filesystem.concat(n, name)
		print(nName)
		if filesystem.isDirectory(path) then
			recursiveSearch(nName, path)
		end
	end
end

for _, name in ipairs(args) do
	local dir = shell.resolve(name)
	if not dir then
		io.stderr:print("Invalid path: " .. name .. "\n")
		return
	end
	if name ~= "." then
		print(name)
	end
	recursiveSearch(name, dir)
end
