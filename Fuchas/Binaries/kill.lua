local shell = require("shell")
local tasks = require("tasks")
local args, options = shell.parse(...)

if #args < 1 then
	print("Usage: kill (-f) [pid]")
	return
end

local pid = tonumber(args[1])
if tasks.getProcess(pid) == nil then
	print("No process with PID " .. pid)
	return
end

if options.f or options.force then
	tasks.unsafeKill(tasks.getProcess(pid), true)
else
	tasks.kill(tasks.getProcess(pid))
end