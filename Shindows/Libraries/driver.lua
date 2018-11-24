local driver = {}

driver.path = "/Shindows/Libraries/?.lua;/Users/Shared/Libraries/?.lua;./?.lua;/?.lua"

local loading = {}

local loaded = {
  ["mouse"] = loadDriver("/Shindows/Drivers/smouse.lua"),
  ["keyboard"] = loadDriver("/Shindows/Drivers/skeyboard.lua"),
  ["filesystem"] = nil, -- FileSystem driver is to do
  ["audio"] = loadDriver("/Shindows/Drivers/pcspeaker.lua")
}
driver.loaded = loaded

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
    local driver = getDriver(path)
    loaded[type] = driver
end

function driver.getDriver(type)
    return loaded[type];
end

local function loadDriver(path)
  checkArg(1, module, "string")
  if not loading[module] then
    local available, library, status, step

    step, library, status = "not found", package.searchpath(module, package.path)

    if library then
      step, library, status = "loadfile failed", loadfile(library)
    end

    if library then
      loading[module] = true
      step, available, library, status = "load failed", pcall(library, module)
      loading[module] = false
    end

	if available == false then
		error("Component not available")
	end
	
    assert(library, string.format("module '%s' %s:\n%s", module, step, status))
    return status
  else
    error("already loading: " .. module .. "\n" .. debug.traceback(), 2)
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

-------------------------------------------------------------------------------

return package
