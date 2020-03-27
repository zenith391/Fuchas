local lib = {}

lib.clock = os.clock
lib.date = os.date
lib.time = os.time

lib.getenv = os.getenv
lib.setenv = os.setenv
lib.sleep = os.sleep

lib.remove = require("filesystem").remove
lib.rename = require("filesystem").rename

function lib.exit()
	error("terminate")
end

function lib.tmpname()
	return "/tmp/" .. math.ceil(math.random()*99999999)
end

return lib
