local tasks = require("tasks")
local event = require("event")
local filesystem = require("filesystem")
local proc  = tasks.getCurrentProcess()

while true do
	local name, address, componentType = event.pull()

	if name == "component_added" then
		if componentType == "filesystem" then
			local letter = fs.freeDriveLetter()
			if letter ~= nil then
				filesystem.mountDrive(component.proxy(address), letter)
			else
				io.stderr:write("Cannot mount drive " .. address .. ": no drive letter free\n")
			end
		end
	end
end
