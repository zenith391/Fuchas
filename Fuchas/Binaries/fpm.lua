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
	for k, v in pairs(pkg.files) do
		local dest = fs.canonical(v) .. "/" .. k
		local s = fs.open(dest, "w")
		io.stdout:write("Downloading " .. k .. "..  ")
		s:write(driver.internet.readFully(githubGet .. src .. "/master/" .. k))
		s:close()
		local fg = component.gpu.getForeground()
		component.gpu.setForeground(0x00FF00)
		print("OK!")
		component.gpu.setForeground(fg)
	end
	print("Saving package list..")
	packages[name] = pkg
	save()
end

if args[1] == "help" then
	print("FPM Help:")
	print("\thelp                  : Shows this help message")
	print("\tinstall [package name]: Install the following package.")
	print("\tremove  [package name]: Removes the following package.")
	print("\tupdate  [package name]: Update the following package.")
	print("\tupgrade               : Updates all outdated packages")
	print("\tlist                  : Lists installed packages")
	--print("\trecalc: (use only if necessary) Clears the package list, then iterates through all")
	--print("\t        the root directory (A:/) and add to the list any found package.")
	return
end

if args[1] == "list" then
	print("Package list:")
	for k, v in pairs(packages) do
		print("\t- " .. k .. " v" .. v.version .. " (rev " .. v.revision ..")")
	end
	return
end

if args[1] == "remove" then
	for k, v in pairs(packages) do
		if k == args[2] then
			 for f, dir in pairs(v.files) do
				local dest = fs.canonical(dir) .. "/" .. f
				io.stdout:write("Removing " .. f .. "..  ")
				fs.remove(dest)
				local fg = component.gpu.getForeground()
				component.gpu.setForeground(0xFF0000)
				print("REMOVED!")
				component.gpu.setForeground(fg)
			end
			packages[k] = nil
			return
		end
	end
	print(args[2] .. " is not installed")
	return
end

if args[1] == "update" then
	if not component.isAvailable("internet") then
		io.stderr:write("Internet card required!")
		return
	end
	local installed = false
	for k, _ in pairs(packages) do
		if k == args[2] then
			installed = true
			break
		end
	end
	if not installed then
		print(args[2] .. " is not installed")
		return
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
				if e.revision == packages[args[2]].revision then
					print(e.name .. " is up-to-date")
					return
				end
				print("Updating " .. e.name)
				local ok, err = pcall(downloadPackage, src, k, e)
				if not ok then
					print("Error downloading package: " .. err)
				end
				print(e.name .. " updated")
				return
			end
		end
	end
	return
end

if args[1] == "recalc" then
	print("Feature not yet available!")
	return
end

if args[1] == "install" then
	if not component.isAvailable("internet") then
		io.stderr:write("Internet card required!")
		return
	end
	for k, _ in pairs(packages) do
		if k == args[2] then
			print(k .. " is installed")
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
				print("Installing " .. e.name)
				local ok, err = pcall(downloadPackage, src, k, e)
				if not ok then
					print("Error downloading package: " .. err)
				end
				print(e.name .. " installed")
				return
			end
		end
	end
	print("Package not found: " .. args[2])
	return
end

print("No arguments. Type 'fpm help' for help.")