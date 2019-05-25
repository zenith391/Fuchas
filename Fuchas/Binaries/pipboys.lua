-- PIPBOYS (Package Installation & Packeter for Beautiful and Ordered Young Software)

local shell = require("shell")
local args, options = shell.parse(...)

if options.h then
	print("PIPBOYS Help:")
	print("\thelp: Shows this help message")
	print("\tinstall [package name]: Install the following package. Throws an error if non-existent")
	print("\tupdate: Updates any outdated installed packages")
	print("\tlist: Lists installed packages")
	print("\trecalc: (use only if necessary) Clears the package list, then iterates through all")
	print("\t        the root directory (A:/) and add to the list any found package.")
	return
end

if options.i then
	if not component.isAvailable("internet") then
		io.stderr:write("Internet card required!")
		return
	end
	print("Searching package '" .. args[1] .. "'")
	local master = [[
		{
			repos = {
				"zenith391/Pi-Repositories"
			}
		}
	]]
	return
end

print("No arguments. Type 'pipboys help' for help.")