local shell = require("shell")
local args, options = shell.parse(...)

if #args < 1 then
	print("Usage: kill (-f) [pid]")
	return
end

local pid = tonumber(args[1])
if shin32.getProcess(pid) == nil then
	print("No process with PID " .. pid)
	return
end

if options.f or options.force then
	shin32.kill(shin32.getProcess(pid), true)
else
	shin32.safeKill(shin32.getProcess(pid))
end