local args, ops = require("shell").parse(...)

if #args < 1 then
	io.stderr:write("Usage: power [off|reboot]\n")
	return
end

if args[1] == "off" then
	print("Powering off..")
	computer.shutdown()
end

if args[1] == "reboot" then
	print("Rebooting..")
	computer.shutdown(true)
end
