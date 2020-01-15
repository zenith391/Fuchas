local lib = {}

lib.clock = os.clock
lib.date = os.date
lib.time = os.time

lib.getenv = os.getenv
lib.setenv = os.setenv
lib.sleep = os.sleep

function os.exit()
	error("terminate")
end

function os.tmpname()
	return "/tmp/" .. math.ceil(math.random()*99999999)
end

return lib
