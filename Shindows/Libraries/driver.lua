local driver = {}

driver.path = "/Shindows/Drivers/?.lua;/Users/Shared/Drivers/?.lua;./?.lua;/?.lua"

local loading = {}

local loaded = {}

function driver.searchpath(name, path, sep, rep)
  checkArg(1, name, "string")
  checkArg(2, path, "string")
  sep = sep or '.'
  rep = rep or '/'
  sep, rep = '%' .. sep, rep
  name = string.gsub(name, sep, rep)
  local fs = require("filesystem")
  local errorFiles = {}
  for subPath in string.gmatch(path, "([^;]+)") do
    subPath = string.gsub(subPath, "?", name)
    if subPath:sub(1, 1) ~= "/" and os.getenv then
      subPath = fs.concat(os.getenv("PWD") or "/", subPath)
    end
    if fs.exists(subPath) then -- fs.exists(subPath)
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

function driver.changeDriver(type, path)
    checkArg(1, type, "string")
    checkArg(2, path, "string")
    local ok, driver = loadDriver(path)
    loaded[type] = driver
end

function driver.getDriver(type)
	y = 1
	for k, v in pairs(loaded) do
		print(k, 0xFFFFFF)
		print(v, 0xFFFFFF)
	end
    return loaded[type];
end

function driver.isDriverAvailable(path)
	local ok, drv = loadDriver(path)
	return not not ok
end

function loadDriver(path)
  checkArg(1, path, "string")
  if not loading[path] then
    local available, library, status, step

    step, library, status = "not found", driver.searchpath(path, driver.path)

    if library then
      step, library, status = "loadfile failed", loadfile(library)
    end

    if library then
      loading[path] = true
      step, status, available, library = "load failed", pcall(library, path)
      loading[path] = false
    end

	--if available == false then
	--	error("Component not available")
	--end
	
    --assert(library, string.format("driver '%s' %s:\n%s", path, step, status))
    return available, library
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

loaded["mouse"] = loadDriver("smouse")
loaded["audio"] = loadDriver("pcspeaker")

-------------------------------------------------------------------------------

return driver
