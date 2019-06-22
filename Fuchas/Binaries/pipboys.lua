-- PIPBOYS (Package Installation & Packeter for Beautiful and Ordered Young Software)
-- OPPM-compatible!

local liblon = require("liblon")
local fs = require("filesystem")
local driver = require("driver")
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
	packages = liblon.loadlon(s)
	s:close()
end
if not fs.exists(shared .. "/pipboy-sources.lon") then
	repoList = {
		"zenith391/zenith391-Pipboys"
	}
	local s = fs.open(shared .. "/pipboy-sources.lon", "w")
	s:write(liblon.sertable(repoList))
	s:close()
else
	local s = io.open(shared .. "/pipboy-sources.lon", "r")
	repoList = liblon.loadlon(s)
	s:close()
end

local function downloadPackage(pkg)
	
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
	print("Searching package: " .. args[2])
	local packageList = {}
	for k, v in pairs(repoList) do
		print("  Source: " .. v)
		local ok, err = pcall(table.insert, packageList, liblon.loadlon(driver.internet.readFully(githubGet .. v .. "/master/programs.lon")))
		if not ok then
			print("    " .. err)
		end
	end
	for k, v in pairs(packageList) do
		if k == args[2] then
			local ok, err = pcall(downloadPackage, v)
			if not ok then
				print("Error downloading package: " .. err)
			end
			return
		end
	end
	print("Package not found: " .. args[2])
	return
end

print("No arguments. Type 'pipboys help' for help.")