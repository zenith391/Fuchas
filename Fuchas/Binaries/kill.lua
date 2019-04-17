-- Kills process
local args = ...
if #args < 1 then
	print("Usage: kill [pid]")
	return
end

local pid = tonumber(args[1])

if shin32.getProcess(pid) == nil then
	print("No process with PID " .. pid)
	return
end
write("Use safe method? Y/N ")
local safe = (require("shell").read():upper() == "Y")
print(" ")

if not safe then
	shin32.kill(shin32.getProcess(pid), true)
else
	shin32.safeKill(shin32.getProcess(pid))
end