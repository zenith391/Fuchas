--- System logging library
-- @module log
-- @alias lib

local filesystem = require("filesystem")

local lib = {}
lib.logHandlers = {}
lib.DEBUG_LEVEL = 0
lib.INFO_LEVEL  = 1
lib.WARN_LEVEL  = 2
lib.ERROR_LEVEL = 3

function lib.levelName(level)
	if level == 0 then
		return "debug"
	elseif level == 1 then
		return "info"
	elseif level == 2 then
		return "warn"
	elseif level == 3 then
		return "error"
	end
end

function lib.fileLogger(path)
	local file = filesystem.open(path, "w")
	return function(msg, name, level)
		local strLevel = lib.levelName(level):upper()
		local str = "[" .. name .. " | " .. strLevel .. "] " .. tostring(msg) .. "\n"
		file:write(str)
	end
end

setmetatable(lib, {__call = function(_, name)
	local logger = {}
	local logs = {}

	local logLevel = (OSDATA.DEBUG and lib.DEBUG_LEVEL) or lib.INFO_LEVEL

	function logger.log(msg, level)
		if level >= logLevel then
			for k, handler in pairs(lib.logHandlers) do
				handler(tostring(msg), tostring(name), level)
			end
		end
	end

	function logger.debug(msg)
		logger.log(msg, lib.DEBUG_LEVEL)
	end

	function logger.info(msg)
		logger.log(msg, lib.INFO_LEVEL)
	end

	function logger.warn(msg)
		logger.log(msg, lib.WARN_LEVEL)
	end

	function logger.error(msg)
		logger.log(msg, lib.ERROR_LEVEL)
	end

	return logger
end})

if OSDATA.DEBUG then
	table.insert(lib.logHandlers, lib.fileLogger("A:/fuchas.log"))
end

return lib
