-- Sources are PIPBOYS (Package Installs & Packets for Beautiful and Ordered Young Software)
-- Installer is FPM (Fuchas Package Manager)

local liblon = require("liblon")
local fs = require("filesystem")
local driver = require("driver")
local gpu = driver.gpu
local internet = driver.internet
local shared = require("users").getSharedUserPath()
local githubGet = "https://raw.githubusercontent.com/"
local shell = require("shell")
local args, options = shell.parse(...)

-- File checks
local packages, repoList
if not fs.exists(shared .. "/fpm-packages.lon") then
	packages = {
		["fpm"] = {
			files = {
				["Fuchas/Binaries/fpm.lua"] = "A:"
			},
			dependencies = {},
			name = "Fuchas Package Manager",
			description = "Download what you're using to download this. Downloadception",
			authors = "zenith391",
			version = "bundled",
			revision = 0
		}
	}
	local s = fs.open(shared .. "/fpm-packages.lon", "w")
	s:write(liblon.sertable(packages))
	s:close()
else
	local s = io.open(shared .. "/fpm-packages.lon", "r")
	packages = liblon.loadlon(s)
	s:close()
end
if not fs.exists(shared .. "/fpm-sources.lon") then
	repoList = { -- Default sources
		"zenith391/Fuchas",
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

local function searchSource(source)
	if not fs.exists("A:/Users/Shared/fpm-cache") then
		fs.makeDirectory("A:/Users/Shared/fpm-cache")
	end
	local txt
	if not fs.exists("A:/Users/Shared/fpm-cache/" .. source .. ".lon") or true then -- cache is disabled temporaly
		--if not fs.exists(fs.path("A:/Users/Shared/fpm-cache/" .. source)) then
		--	fs.makeDirectory(fs.path("A:/Users/Shared/fpm-cache/" .. source))
		--end
		txt = internet.readFully(githubGet .. source .. "/master/programs.lon")
		--local stream = io.open("A:/Users/Shared/fpm-cache/" .. source .. ".lon", "w")
		--stream:write(txt)
		--stream:close()
	else
		local stream = io.open("A:/Users/Shared/fpm-cache/" .. source .. ".lon")
		txt = stream:read("a")
		stream:close()
	end
	local ok, out = pcall(liblon.loadlon, txt)
	if not ok then
		print("    " .. out)
	end
	return out
end

local function downloadPackage(src, name, pkg)
	for k, v in pairs(pkg.files) do
		local dest = fs.canonical(v) .. "/" .. k
		io.stdout:write("\tDownloading " .. k .. "..  ")
		local txt = internet.readFully(githubGet .. src .. "/master/" .. k)
		if txt == "" then
			local _, fg = gpu.getColor()
			gpu.setForeground(0xFF0000)
			print("NOT FOUND!")
			print("\tDOWNLOAD ABORTED")
			gpu.setForeground(fg)
			return
		end
		local s = fs.open(dest, "w")
		s:write(txt)
		s:close()
		local _, fg = gpu.getColor()
		gpu.setForeground(0x00FF00)
		print("OK!")
		gpu.setForeground(fg)
	end
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
		print("\t- " .. k .. " " .. v.version .. " (rev " .. v.revision ..")")
	end
	return
end

if args[1] == "remove" then
	local toInstall = {}
	for i=2,#args do
		table.insert(toInstall, args[i])
	end
	for k, v in pairs(packages) do
		for _, i in pairs(toInstall) do
			if k == i then
				for f, dir in pairs(v.files) do
					local dest = fs.canonical(dir) .. "/" .. f
					io.stdout:write("Removing " .. f .. "..  ")
					fs.remove(dest)
					local _, fg = gpu.getColor()
					gpu.setForeground(0xFF0000)
					print("REMOVED!")
					gpu.setForeground(fg)
				end
				packages[k] = nil
				save()
			end
		end
	end
	return
end

if args[1] == "update" then
	if not internet then
		io.stderr:write("Internet card required!")
		return
	end
	local toInstall = {}
	for i=2,#args do
		table.insert(toInstall, args[i])
	end
	local installed = false
	for k, _ in pairs(packages) do
		for _, i in pairs(toInstall) do
			if k == i then
				installed = true
				break
			end
		end
	end
	if not installed then
		print(args[2] .. " is not installed")
		return
	end
	print("Searching packages..")
	local packageList = {}
	for k, v in pairs(repoList) do
		print("  Source: " .. v)
		packageList[v] = searchSource(v)
	end
	local isnt = false
	for src, v in pairs(packageList) do
		for k, e in pairs(v) do
			for _, i in pairs(toInstall) do
				if k == i then
					if e.revision == packages[args[2]].revision then
						print(e.name .. " is up-to-date")
					else
						print("Updating " .. e.name)
						local ok, err = pcall(downloadPackage, src, k, e)
						if not ok then
							print("Error downloading package: " .. err)
						end
						print(e.name .. " updated")
					end
				end
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
	local toInstall = {}
	if not internet then
		io.stderr:write("Internet card required!")
		return
	end
	for i=2,#args do
		table.insert(toInstall, args[i])
	end
	for k, _ in pairs(packages) do
		for _, i in pairs(toInstall) do
			if k == i then
				print(k .. " is installed")
				return
			end
		end
	end
	print("Searching packages..")
	local packageList = {}
	for k, v in pairs(repoList) do
		print("  Source: " .. v)
		packageList[v] = searchSource(v)
	end
	local isnt = false
	for src, v in pairs(packageList) do
		for k, e in pairs(v) do
			for _, i in pairs(toInstall) do
				if k == i then
					for k, v in pairs(e.dependencies) do
						if k == "fuchas" then
							local fmajor = OSDATA.VERSION:sub(1,1)
							local fminor = OSDATA.VERSION:sub(3,3)
							local fpatch = OSDATA.VERSION:sub(5,5)

							local major,minor,patch = v:sub(1,1),v:sub(3,3),'*'
							if v:len() > 3 then patch = v:sub(5,5) end
							if fmajor ~= major or fminor ~= minor or (patch ~= '*' and patch ~= fpatch) then
								print("Package " .. e.name .. " doesn't work with the current version of Fuchas.")
								print("It is made for version " .. v .. ", but the current version is " .. OSDATA.VERSION)
								return
							end
						else
							table.insert(toInstall, v)
						end
					end
					print("Installing " .. e.name)
					local ok, err = pcall(downloadPackage, src, k, e)
					if not ok then
						print("Error downloading package: " .. err)
					end
					print(e.name .. " installed")
					isnt = true
				end
			end
		end
	end
	if isnt then
		return
	end
	print("Package not found: " .. args[2])
	return
end

print("No arguments. Type 'fpm help' for help.")