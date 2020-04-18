-- Bootstrap for Fuchas interface.
local fs = require("filesystem")
local tasks = require("tasks")

-- Unmanaged drives: TO-REDO
for k, v in pairs(fs.unmanagedFilesystems()) do
	for addr, _ in component.list("drive") do
		if fs.isValid(addr) then
			fs.mountDrive(fs.asFilesystem(addr), fs.freeDriveLetter())
		end
	end
end

-- User
if not fs.exists("A:/Users/Shared") then
	fs.makeDirectory("A:/Users/Shared")
end

tasks.newProcess("System Interface", function()
	dofile("A:/Fuchas/autorun.lua") -- system variables autorun
	local f, err = xpcall(function()
		require("users").login("guest") -- no password required
		print("(5/5) Loading " .. OSDATA.CONFIG["DEFAULT_INTERFACE"])
		local path = "A:/Fuchas/Interfaces/" .. OSDATA.CONFIG["DEFAULT_INTERFACE"] .. "/main.lua"
		if not fs.exists(path) then
			error("No such interface: " .. path)
		end
		local l, err = loadfile(path)
		if l == nil then
			error(err)
		end
		return l()
	end, function(err)
		io.stderr:write("\nThe interface crashed \\:\n")
		io.stderr:write(err .. "\n")
		io.stderr:write(debug.traceback(nil, 2) .. "\n")
		io.stderr:write("Restarting ..\n")
		computer.shutdown(true)
		return err
	end)
	if f == true then
		computer.shutdown() -- main interface exit
	else
		error(err)
	end
end)

while true do
	tasks.scheduler()
end
