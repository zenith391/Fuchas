local lib = {}
local tasks = require("tasks")
local event = require("event")

lib.clock = os.clock
lib.date = os.date
lib.time = os.time

lib.exit = os.exit

lib.getenv = os.getenv
lib.setenv = os.setenv
lib.sleep = os.sleep

function lib.sleep(t)
	os.sleep(t)
	-- ignore all events like OpenOS does
	while #tasks.getCurrentProcess().events > 0 do
		require("event").pull(0)
	end
end

lib.remove = require("filesystem").remove
lib.rename = require("filesystem").rename

function lib.exit()
	error("terminate")
end

function lib.tmpname()
	return "/tmp/" .. math.ceil(math.random()*99999999)
end

return lib
