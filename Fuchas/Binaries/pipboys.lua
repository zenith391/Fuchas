-- PIPBOYS (Package Installation & Packeter for Beautiful and Ordered Young Software)

local args = ...

local parseArgs = {}

local i = 1
while i < #args+1 do
	local v = args[i]
	if v == "h" or v == "help" then
		parseArgs.h = true
	end
	if v == "i" or v == "install" then
		i = i + 1
		if not args[i] then
			io.stderr:write("missing package name after 'install'\n")
			return
		end
		parseArgs.i = args[i]
	end
	i = i + 1
end

if parseArgs.h then
	print("PIPBOYS Help:")
	print("\thelp: Shows this help message")
	print("\tinstall [package name]: Install the following package. Throws an error if non-existent")
	print("\tupdate: Updates any outdated installed packages")
	print("\tlist: Lists installed packages")
	print("\trecalc: (use only if necessary) Clears the package list, then iterates through all")
	print("\t        the root directory (A:/) and add to the list any found package.")
	return
end

if parseArgs.i then
	if not component.isAvailable("internet") then
		io.stderr:write("Internet card required!")
		return
	end
	print("Searching package '" .. parseArgs.i .. "'")
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