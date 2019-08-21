local shell = require("shell")
local args, options = shell.parse(...)

if options.enable then
	if #args < 1 then io.stderr:write("Usage: term --enable <type>\n"); return end
	if args[1] == "ansi" then
		print("Enabling ANSI..")
		shell.enableANSI()
		print("ANSI enabled")
		return
	end
end

if options.disable then
	if #args < 1 then io.stderr:write("Usage: term --disable <type>\n"); return end
end

if options.reset then
	if #args < 1 then io.stderr:write("Usage: term --reset <type>\n"); return end
	if args[1] == "io" then
		shell.resetStdout(true)
		print("I/O reset")
		return
	end
end

print("Usage:")
print("  --enable <type> - Valid: ansi")
print("  --reset <type> - Valid: io")
return