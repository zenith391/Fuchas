-- APM (Application Package Manager)

local fs = require("filesystem")
local theOS = "Fuchas"
if _OSVERSION and _OSVERSION:sub(1, 6) == "OpenOS" then
	theOS = "OpenOS"
end
local shared = (theOS == "OpenOS" and "/usr") or require("users").getSharedUserPath()
local userPath = (theOS == "OpenOS" and "/usr/local") or require("users").getUserPath()
local githubGet = "https://raw.githubusercontent.com/"
local args, options = require("shell").parse(...)
local tmpPath = (theOS == "OpenOS" and "/tmp") or "T:"
local global = options["g"] or options["global"]
local hasInternet = false

if theOS == "OpenOS" then -- OpenOS
	hasInternet = require("component").isAvailable("internet")
else
	if require("driver").internet then
		hasInternet = true
	end
end

local function readFully(url)
	if theOS == "OpenOS" then -- OpenOS
		local h = require("component").internet.request(url)
		h.finishConnect()
		local buf = ""
		local data = ""
		while data ~= nil do
			buf = buf .. data
			data = h.read()
		end
		h.close()
		return buf
	else
		return require("driver").internet.readFully(url)
	end
end

local function serialize(t)
	if theOS == "OpenOS" then -- OpenOS
		return require("serialization").serialize(t)
	else
		return require("liblon").sertable(t)
	end
end

local function unserialize(s)
	if theOS == "OpenOS" then -- OpenOS
		return require("serialization").unserialize(s)
	else
		return require("liblon").loadlon(s)
	end
end

-- File checks
local packages, repoList
if not fs.exists(shared .. "/apm") then
	fs.makeDirectory(shared .. "/apm")
end

if not fs.exists(shared .. "/apm/packages.lon") then
	packages = {
		["apm"] = {
			files = {
				["Fuchas/Binaries/apm.lua"] = "A:/Fuchas/Binaries/apm.lua"
			},
			os = {
				["OpenOS"] = {
					files = {
						["Fuchas/Binaries/apm.lua"] = "/bin/apm.lua"
					}
				}
			},
			dependencies = {},
			name = "Application Package Manager",
			description = "Nice application manager.",
			authors = "zenith391",
			version = "1.2",
			revision = 5
		}
	}
	local s = io.open(shared .. "/apm/packages.lon", "w")
	print(serialize(packages))
	s:write(serialize(packages))
	s:close()
else
	local s = io.open(shared .. "/apm/packages.lon", "r")
	packages = unserialize(s:read("*a"))
	s:close()
end
if not fs.exists(shared .. "/apm/sources.lon") then
	repoList = { -- Default sources
		"zenith391/Fuchas",
		"zenith391/OpenComputers-Packages"
	}
	local s = fs.open(shared .. "/apm/sources.lon", "w")
	s:write(serialize(repoList))
	s:close()
else
	local s = io.open(shared .. "/apm/sources.lon", "r")
	repoList = unserialize(s:read("*a"))
	s:close()
end

local function save()
	local s = fs.open(shared .. "/apm/packages.lon", "w")
	s:write(serialize(packages))
	s:close()
	s = fs.open(shared .. "/apm/sources.lon", "w")
	s:write(serialize(repoList))
	s:close()
end

local function loadLonSec(txt)
	local ok, out = pcall(unserialize, txt)
	if not ok then
		io.stderr:write("    " .. out)
	end
	return ok, out
end

local function searchSource(source)
	if not fs.exists(tmpPath .. "/apm") then
		fs.makeDirectory(tmpPath .. "/apm")
	end
	local txt
	if not fs.exists(tmpPath .. "/apm/" .. source .. ".lon") then
		if not fs.exists(fs.path(tmpPath .. "/apm/" .. source)) then
			fs.makeDirectory(fs.path(tmpPath .. "/apm/" .. source))
		end
		txt = readFully(githubGet .. source .. "/master/programs.lon")
		local stream = io.open(tmpPath .. "/apm/" .. source .. ".lon", "w")
		local _, lon = loadLonSec(txt)
		lon["expiresOn"] = os.time() + 60
		stream:write(serialize(lon))
		stream:close()
	else
		local stream = io.open(tmpPath .. "/apm/" .. source .. ".lon")
		txt = stream:read("a")
		stream:close()
	end
	local ok, out = loadLonSec(txt)
	if out and out["expiresOn"] then
		if os.time() >= out["expiresOn"] then
			fs.remove(tmpPath .. "/apm/" .. source .. ".lon")
			return searchSource(source)
		end
	end
	return out
end

local function transformPath(path)
	path = path:gsub("{userpath}", (global and shared) or userPath)
	if theOS == "Fuchas"  then
		path = path:gsub("{lib}", "A:/Users/Shared/Libraries")
		path = path:gsub("{bin}", "A:/Users/Shared/Binaries")
	else
		path = path:gsub("{lib}", "/usr/lib")
		path = path:gsub("{bin}", "/usr/bin")
	end
	return path
end

local function downloadPackage(src, name, pkg, ver)
	local arch = (computer or package.loaded.computer).getArchitecture()
	local files = pkg.files
	if pkg.archFiles then -- if have architecture-dependent files
		if pkg.archFiles[arch] then
			print("Selected package architecture: " .. arch)
			for k, v in pairs(pkg.archFiles[arch]) do
				for l, w in pairs(pkg.files) do
					if v == w then -- same target
						pkg.files[l] = nil
						pkg.files[k] = v
					end
				end
			end
		end
	end
	if pkg.os then -- if have os-dependent files
		if pkg.os[theOS] then
			print("Selected package OS: " .. theOS)
			files = pkg.os[theOS].files
		end
	end
	for k, v in pairs(files) do
		v = transformPath(v)
		local dest = fs.canonical(v)
		if ver == 1 then
			dest = fs.canonical(v) .. "/" .. k
		end
		if not fs.exists(fs.path(v)) then
			fs.makeDirectory(fs.path(v))
		end
		io.stdout:write("\tDownloading " .. k .. "..  ")
		local txt = readFully(githubGet .. src .. "/master/" .. k)
		if txt == "" then
			print("\x1b[31mNot Found!")
			print("\tDownload aborted.\x1b[97m")
			if theOS == "OpenOS" then -- OpenOS's ANSI doesn't support bright color for some reasons
				io.stdout:write("\x1b[37m")
			end
			return
		end
		local s = fs.open(dest, "w")
		s:write(txt)
		s:close()
		print("\x1b[32mOK!\x1b[97m")
		if theOS == "OpenOS" then -- OpenOS's ANSI doesn't support bright color for some reasons
			io.stdout:write("\x1b[37m")
		end
	end
	packages[name] = pkg
	save()
end

if args[1] == "list" then
	print("Package list:")
	for k, v in pairs(packages) do
		print("    - " .. k .. " " .. v.version .. " (rev. " .. v.revision ..")")
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
					dir = transformPath(dir)
					local dest = fs.canonical(dir)
					io.stdout:write("Removing " .. f .. "..  ")
					fs.remove(dest)
					print("\x1b[31mREMOVED!\x1b[97m")
				end
				packages[k] = nil
				save()
			end
		end
	end
	return
end

if args[1] == "update" then
	if not hasInternet then
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
	for src, v in pairs(packageList) do
		for k, e in pairs(v) do
			for _, i in pairs(toInstall) do
				if k == i then
					local ver = v["_version"] or 1
					if e.revision >= packages[args[2]].revision then
						print(e.name .. " is up-to-date")
					else
						print("Updating " .. e.name)
						local ok, err = pcall(downloadPackage, src, k, e, ver)
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

if args[1] == "info" then
	if not hasInternet then
		io.stderr:write("Internet card required!")
		return
	end
	if #args < 2 then
		args[1] = "help"
	else
		local pkg = args[2]
		print("Searching package..")
		local packageList = {}
		for k, v in pairs(repoList) do
			packageList[v] = searchSource(v)
		end
		local isFound = false
		for src, v in pairs(packageList) do
			for k, e in pairs(v) do
				if k == pkg then
					print(k .. ":")
					print("    Name: " .. e.name)
					print("    Description: " .. e.description)
					print("    Authors: " .. e.authors)
					isFound = true
					break
				end
			end
		end
		if not isFound then
			print("Package not found: " .. pkg)
		end
		return
	end
end

if args[1] == "install" then
	local toInstall = {}
	if not hasInternet then
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
				if k == i then -- if it's one of the package we want to install
					local ver = v["_version"] or 1
					for k, v in pairs(e.dependencies) do
						if k == "fuchas" and theOS == "Fuchas" then
							local fmajor = tonumber(OSDATA.VERSION:sub(1,1))
							local fminor = tonumber(OSDATA.VERSION:sub(3,3))
							local fpatch = OSDATA.VERSION:sub(5,5)

							local major,minor,patch = tonumber(v:sub(1,1)),tonumber(v:sub(3,3)),'*'
							if v:len() > 3 then patch = v:sub(5,5) end
							if fmajor >= major or fminor >= minor or (patch ~= '*' and patch ~= fpatch) then
								print("Package " .. e.name .. " doesn't work with the current version of Fuchas.")
								print("It is made for version " .. v .. ", but the current version is " .. OSDATA.VERSION)
								return
							end
						else
							table.insert(toInstall, v)
						end
					end
					print("Installing " .. e.name)
					local ok, err = pcall(downloadPackage, src, k, e, ver)
					if not ok then
						print("Error downloading package: " .. err)
					end
					print(e.name .. " installed")
					isnt = true
				end
			end
		end
	end
	if isnt then -- not present
		return
	end
	print("Package not found: " .. args[2])
	return
end

if args[1] == "help" then
	print("Usage:")
	print("  apm [-g] <help|install|remove|update|upgrade|list>")
	print("Commands:")
	print("  help                 : show this help message")
	print("  install [packages...]: install the following packages.")
	print("  remove  [packages...]: remove the following packages.")
	print("  update  [packages...]: update the following packages.")
	print("  info    [package]    : display info about the following package")
	print("  upgrade              : update all outdated packages")
	print("  list                 : list installed packages")
	print("Flags:")
	print("  -g      : shortcut for --global")
	print("  --global: this flag change install user path (" .. userPath .. ") to global user path (" .. shared .. ")")
	return
end

print("No arguments. Type 'apm help' for help.")