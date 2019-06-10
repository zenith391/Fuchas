-- PIPBOYS (Package Installation & Packeter for Beautiful and Ordered Young Software)
-- OPPM-compatible!

local liblon = require("liblon")
local fs = require("filesystem")
local shared = shin32.getSharedUserPath()
local githubGet = "https://raw.githubusercontent.com/"
local shell = require("shell")
local args, options = shell.parse(...)

-- File checks
local packages, repoList
if not fs.exists(shared .. "/pipboy-packages.lon") then
	packages = {}
	local s = fs.open(shared .. "/pipboy-packages.lon", "w")
	s:write("{}")
	s:close()
else
	local s = io.open(shared .. "/pipboy-packages.lon", "r")
	packages = liblon.loadlon(s:read("a"))
	s:close()
end
if not fs.exists(shared .. "/pipboy-sources.lon") then
	repoList = {
		repos = {
			"zenith391/zenith391-Pipboys"
		}
	}
	local s = fs.open(shared .. "/pipboy-sources.lon", "w")
	s:write(liblon.sertable(repoList))
	s:close()
else
	local s = io.open(shared .. "/pipboy-sources.lon", "r")
	packages = liblon.loadlon(s:read("a"))
	s:close()
end

if args[1] == "help" then
	print("PIPBOYS Help:")
	print("\thelp: Shows this help message")
	print("\tinstall [package name]: Install the following package. Throws an error if non-existent")
	print("\tupdate [package name]: Update the following package. Throws an error if non-existent")
	print("\tupgrade: Updates all outdated packages")
	print("\tlist: Lists installed packages")
	print("\trecalc: (use only if necessary) Clears the package list, then iterates through all")
	print("\t        the root directory (A:/) and add to the list any found package.")
	return
end

if args[1] == "install" then
	if not component.isAvailable("internet") then
		io.stderr:write("Internet card required!")
		return
	end
	print("Searching package '" .. args[2] .. "'")
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