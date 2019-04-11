-- Bootstrap for Fuchas interface.
local fs = require("filesystem")
require("OCX/ConsoleUI").clear(0x000000)

-- Bootstrap routine
dofile("A:/Fuchas/autorun.lua") -- system variables autorun

local drv = require("driver")

-- Is 2nd installation step?
if fs.exists("A:/installing") then
	dofile("A:/Fuchas/Binaries/installer.lua") -- Run 2nd step installer
	computer.shutdown(true)
end

require("shell").setCursor(1, 1)
shin32.newProcess("System", function()
	local f, err = xpcall(function()
		local l, err = loadfile("A:/Fuchas/DOE/sh.lua")
		if l == nil then
			error(err)
		end
		return l()
	end, function(err)
		print(err)
		print(debug.traceback(" ", 1))
	end)
	if f == false then
		print("Error:", 0xFF0000)
		print(err, 0xFF0000)
	else
		computer.shutdown() -- main interface exit
	end
end)

while true do
	shin32.scheduler()
end