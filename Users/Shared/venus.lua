package.loaded["libvenus"] = nil
local venus = require("libvenus")
local shell = require("shell")
local filesystem = require("filesystem")
local args, ops = shell.parse(...)

if #args < 1 then
	io.stderr:write("Usage: venus <init|push>\n")
	return
end

local cmd = args[1]

if cmd == "init" then
	local dir = args[2] or shin32.getenv("PWD_DRIVE") .. ":/" .. shin32.getenv("PWD")
	if args[2] then dir = shell.resolve(dir) end
	if dir == nil then
		io.stderr:write("Invalid directory or could not retrieve PWD\n")
		return
	end
	filesystem.makeDirectory(dir .. "/.venus")

	local master = venus.branch(venus.newKey(), "master")
	local readme = venus.file(venus.newKey(), "README.md", master, "# New Project")
	local s = io.open(dir .. "/README.md", "w") -- manually sync with directory
	s:write("# New Project")
	s:close()
	local commit = venus.commit(venus.newKey(), "Initial commit", {master, readme})
	venus.writeObjects(dir .. "/.venus", {master, readme, commit})
end