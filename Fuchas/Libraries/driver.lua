local driver = {}
local loading = {}
local loaded = {}

local fs = require("filesystem")

function driver.searchpath(name, path, sep, rep)
	checkArg(1, name, "string")
	checkArg(2, path, "string")
	sep = sep or '.'
	rep = rep or '/'
	sep, rep = '%' .. sep, rep
	name = string.gsub(name, sep, rep)
	local errorFiles = {}
	for subPath in string.gmatch(path, "([^;]+)") do
		subPath = string.gsub(subPath, "?", name)
		if fs.exists(subPath) then
			local file = fs.open(subPath, "r")
			if file then
				file:close()
				return subPath
			end
		end
		table.insert(errorFiles, "\tno file '" .. subPath .. "'")
	end
	return nil, table.concat(errorFiles, "\n")
end

function driver.changeDriver(type, addr, path)
	checkArg(1, type, "string")
	checkArg(2, path, "string")
	local ok, driver = loadDriver(path)
	if not loaded[type] then
		loaded[type] = {}
		loaded[type]["default"] = getDefaultDriver(type)
	end
	loaded[type] = driver
end

local function findBestDriver(type, addr)
	local sel = nil
	for _, v in pairs(string.split(shin32.getSystemVar("DRV_PATH"), ";")) do
		local dir = v .. type .. "/"
		if fs.exists(dir) then
			for path, _ in fs.list(dir) do
				if not fs.isDirectory(dir .. path) then
					local drv = dofile(dir .. path, addr)
					if drv.isCompatible() then
						if sel == nil then
							sel = drv
						else
							if drv.getRank() > sel.getRank() then
								sel = drv -- choose the highest rank
							end
						end
					end
				end
			end
		end
	end
	return sel
end

local function getDefaultDriver(type)
	for addr, _ in pairs(component.list()) do
		local d = findBestDriver(type, addr)
		if d ~= nil then
			return d
		end
	end
end

function driver.getDriver(type, addr)
	if not addr then
		addr = "default"
	end
	if not loaded[type] then
		loaded[type] = {}
		loaded[type]["default"] = getDefaultDriver(type)
	end
	if not loaded[type][addr] then
		loaded[type][addr] = findBestDriver(type, addr)
	end
	return loaded[type][addr]
end

function driver.getDrivers(type)
end

function driver.isDriverAvailable(path)
	local ok, drv = loadDriver(path)
	return (ok ~= nil)
end

function loadDriver(path)
	checkArg(1, path, "string")
	if not loading[path] then
		local available, driver, status, step
		step, driver, status = "not found", driver.searchpath(path, shin32.getSystemVar("DRV_PATH"))
		if driver then
			step, driver, status = "loadfile failed", loadfile(driver)
		end
		if driver then
			loading[path] = true
			step, status, available, driver = "load failed", pcall(driver, path)
			loading[path] = false
		end

		if available == false then
			error("Component not available")
		end
		assert(driver, string.format("driver '%s' %s:\n%s", path, step, status))
		return available, driver
	else
		error("already loading: " .. path .. "\n" .. debug.traceback(), 2)
	end
end

function driver.delay(lib, file)
	local mt = {
		__index = function(tbl, key)
			setmetatable(lib, nil)
			setmetatable(lib.internal or {}, nil)
			dofile(file)
			return tbl[key]
		end
	}
	if lib.internal then
		setmetatable(lib.internal, mt)
	end
	setmetatable(lib, mt)
end

setmetatable(driver, {
	__index = function(self, key)
		if (key) ~= nil then
			return self.getDriver(key)
		else
			return self[key]
		end
	end
})

return driver
