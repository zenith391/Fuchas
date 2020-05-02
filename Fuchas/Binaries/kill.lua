local shell = require("shell")
local tasks = require("tasks")
local args, options = shell.parse(...)

if #args < 1 then
	print("Usage: kill (-f) [pid]")
	return
end

local pid = tonumber(args[1])
local pids = tasks.getPIDs()
local hasPid = false
for _, v in pairs(pids) do
	if v == pid then hasPid = true end
end

if not hasPid then
	print("No process with PID " .. pid)
	return
end

if options.f or options.force then
	tasks.unsafeKill(tasks.getProcess(pid))
else
	tasks.kill(tasks.getProcess(pid))
end