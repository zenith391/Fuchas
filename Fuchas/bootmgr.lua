-- Bootstrap for Fuchas interface.
local fs = require("filesystem")

-- Bootstrap routine

local drv = require("driver")
local tasks = require("tasks")

-- Initialization
-- Unmanaged drives
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

require("shell").setCursor(1, 1)
tasks.newProcess("System Interface", function()
	local f, err = xpcall(function()
		dofile("A:/Fuchas/autorun.lua") -- system variables autorun
		require("users").login("guest") -- no password required
		local l, err = loadfile("A:/Fuchas/Interfaces/Fushell/main.lua")
		if l == nil then
			error(err)
		end
		return l()
	end, function(err)
		io.stderr:write(err)
		io.stderr:write(debug.traceback(" ", 1))
		error(err)
	end)
	if f == true then
		computer.shutdown() -- main interface exit
	end
end)

while true do
	tasks.scheduler()
end
