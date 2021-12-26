--- System logging library
-- @usage
--  local log = require("log")("My Library")
--  log.debug("This is worthless to read except when debugging")
--  log.info("This is some general information")
--  log.warn("This should be noticed")
--  log.error("Critical situation!")
-- @module log
-- @alias lib

local filesystem = require("filesystem")

local lib = {}
--- List of loghandlers
lib.logHandlers = {}

--- Debug level
lib.DEBUG_LEVEL = 0
--- Info level
lib.INFO_LEVEL  = 1
--- Warning level
lib.WARN_LEVEL  = 2
--- Error level
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

--- Returns a logger that logs to the file specified by path
-- @tparam string path The path of the file to write to
-- @treturn loghandler
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

	--- Log a message with the given level, instead of doing that, specialized
	--- methods (logger.debug, logger.info, ...) should be privileged
	-- @usage
	--  local log = require("log")
	--  local logger = log("My Library")
	--  logger.log("Hello", log.INFO_LEVEL)
	-- @tparam string msg The message to log
	-- @tparam int level The level of the message
	function logger.log(msg, level)
		if level >= logLevel then
			for k, handler in pairs(lib.logHandlers) do
				handler(tostring(msg), tostring(name), level)
			end
		end
	end

	--- Log a message with a debug level
	-- @tparam string msg The message to log
	function logger.debug(msg)
		logger.log(msg, lib.DEBUG_LEVEL)
	end

	--- Log a message with an information level
	-- @tparam string msg The message to log
	function logger.info(msg)
		logger.log(msg, lib.INFO_LEVEL)
	end

	--- Log a message with a warning level
	-- @tparam string msg The message to log
	function logger.warn(msg)
		logger.log(msg, lib.WARN_LEVEL)
	end

	--- Log a message with a error level
	-- @tparam string msg The message to log
	function logger.error(msg)
		logger.log(msg, lib.ERROR_LEVEL)
	end

	return logger
end})

if OSDATA.DEBUG then
	table.insert(lib.logHandlers, lib.fileLogger("A:/fuchas.log"))
end

return lib
