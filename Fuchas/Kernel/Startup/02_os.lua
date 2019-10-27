local tasks = require("tasks")
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