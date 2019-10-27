local tasks = require("tasks")
local _shutdown = computer.shutdown

function os.getenvs()
	local curr = tasks.getCurrentProcess()
	return curr.env
end

function os.getenv(name)
	local curr = tasks.getCurrentProcess()
	if curr then
		return curr.env[name]
	end
end

function os.setenv(name, value)
	local curr = tasks.getCurrentProcess()
	if curr then
		curr.env[name] = value
	end
end

function computer.shutdown(reboot)
	computer.pushSignal("shutdown", computer.uptime())
	if tasks.getCurrentProcess() ~= nil then
		coroutine.yield()
	else
		require("event").exechandlers({"shutdown", computer.uptime()})
	end
	_shutdown(reboot)
end