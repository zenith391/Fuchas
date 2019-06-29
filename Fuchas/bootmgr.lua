-- Bootstrap for Fuchas interface.
local fs = require("filesystem")
--require("OCX/ConsoleUI").clear(0x000000)

-- Bootstrap routine
dofile("A:/Fuchas/autorun.lua") -- system variables autorun

local drv = require("driver")

-- Is 2nd installation step?
if fs.exists("A:/installing") then
	dofile("A:/Fuchas/Binaries/installer.lua") -- Run 2nd step installer
	computer.shutdown(true)
end
-- Initialization
-- Unmanaged drives
for k, v in pairs(fs.unmanagedFilesystems()) do
	for addr, _ in component.list("drive") do
		if fs.isValid(addr) then
			fs.mountDrive(fs.asFilesystem(addr), "U")
		end
	end
end
-- User
if not fs.exists("A:/Users/Shared") then
	fs.makeDirectory("A:/Users/Shared")
end
shin32.setenv("USER", "Guest")
--error("test")
require("shell").setCursor(1, 1)
shin32.newProcess("System Interface", function()
	local f, err = xpcall(function()
		local l, err = loadfile("A:/Fuchas/Interfaces/login.lua")
		if l == nil then
			error(err)
		end
		return l()
	end, function(err)
		print(err)
		print(debug.traceback(" ", 1))
		error(err)
	end)
	if f == true then
        computer.pushSignal("shutdown", computer.uptime())
        require("event").exechandlers({"shutdown", computer.uptime()})
		computer.shutdown() -- main interface exit
	end
end)

while true do
	shin32.scheduler()
end
