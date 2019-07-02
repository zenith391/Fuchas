-- Sources are PIPBOYS (Package Installation & Packeter for Beautiful and Ordered Young Software)
-- Installer is FPM (Fuchas Package Manager)

local liblon = require("liblon")
local fs = require("filesystem")
local driver = require("driver")
local shared = shin32.getSharedUserPath()
local githubGet = "https://raw.githubusercontent.com/"
local shell = require("shell")
local args, options = shell.parse(...)

-- File checks
local packages, repoList
if not fs.exists(shared .. "/fpm-packages.lon") then
	packages = {}
	local s = fs.open(shared .. "/fpm-packages.lon", "w")
	s:write("{}")
	s:close()
else
	local s = io.open(shared .. "/fpm-packages.lon", "r")
	packages = liblon.loadlon(s)
	s:close()
end
if not fs.exists(shared .. "/fpm-sources.lon") then
	repoList = { -- Default sources
		"zenith391/zenith391-Pipboys"
	}
	local s = fs.open(shared .. "/fpm-sources.lon", "w")
	s:write(liblon.sertable(repoList))
	s:close()
else
	local s = io.open(shared .. "/fpm-sources.lon", "r")
	repoList = liblon.loadlon(s)
	s:close()
end

local function save()
	local s = fs.open(shared .. "/fpm-packages.lon", "w")
	s:write(liblon.sertable(packages))
	s:close()
	s = fs.open(shared .. "/fpm-sources.lon", "w")
	s:write(liblon.sertable(repoList))
	s:close()
end

local function downloadPackage(src, name, pkg)
	print("Installing " .. pkg.name)
	for k, v in pairs(pkg.files) do
		local dest = fs.canonical(v) .. "/" .. k
		local s = fs.open(dest, "w")
		io.stdout:write("Downloading " .. k .. "..  ")
		s:write(driver.internet.readFully(githubGet .. src .. "/master/" .. k))
		s:close()
		print("OK!")
	end
	print("Saving package list..")
	packages[name] = pkg.revision
	save()
	print(pkg.name .. " installed!")
end

if args[1] == "help" then
	print("FPM Help:")
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
	for k, _ in pairs(packages) do
		if k == args[2] then
			print(k .. " is already installed")
			return
		end
	end
	print("Searching package: " .. args[2])
	local packageList = {}
	for k, v in pairs(repoList) do
		print("  Source: " .. v)
		local txt = driver.internet.readFully(githubGet .. v .. "/master/programs.lon")
		local ok, err = pcall(liblon.loadlon, txt)
		if ok then
			packageList[v] = err
		else
			print("    " .. err)
		end
	end
	for src, v in pairs(packageList) do
		for k, e in pairs(v) do
			if k == args[2] then
				local ok, err = pcall(downloadPackage, src, k, e)
				if not ok then
					print("Error downloading package: " .. err)
				end
				return
			end
		end
	end
	print("Package not found: " .. args[2])
	return
end

print("No arguments. Type 'fpm help' for help.")