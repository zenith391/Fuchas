local lon = require("liblon")
local shell = require("shell")
local security = require("security")
local filesystem = require("filesystem")

local stream = io.open("A:/Fuchas/services.lon")
local services = lon.loadlon(stream)
local enabled = services.enabled
stream:close()

local args, ops = shell.parse(...)

if not security.hasPermission("file.protected") then
	io.stderr:write("This program requires the \"file.protected\" permission.\n")
	return
end

if #args < 1 then
	io.stderr:write("Not enough arguments! Usage: service <enable|disable|list>\n")
	return
end

if args[1] == "enable" then
	if #args < 2 then
		io.stderr:write("Not enough arguments! Usage: service <enable|disable|list> <service name>\n")
		return
	end

	local name = args[2]
	for k, v in pairs(services.enabled) do
		if v == name then
			io.stderr:write("Service \"" .. name .. "\" is already enabled.\n")
			return
		end
	end
	table.insert(services.enabled, name)
	local stream = io.open("A:/Fuchas/services.lon", "w")
	if not stream then
		io.stderr:write("Could not write services.lon: " .. err .. "\n")
		return
	end
	stream:write(lon.sertable(services))
	stream:close()
	print("Service \"" .. name .. "\" has been enabled, it will be launched next boot.")
elseif args[1] == "disable" then
	if #args < 2 then
		io.stderr:write("Not enough arguments! Usage: service <enable|disable|list> <service name>\n")
		return
	end

	local name = args[2]
	for k, v in pairs(services.enabled) do
		if v == name then
			table.remove(services.enabled, k)
			local stream, err = io.open("A:/Fuchas/services.lon", "w")
			if not stream then
				io.stderr:write("Could not write services.lon: " .. err .. "\n")
				return
			end
			stream:write(lon.sertable(services))
			stream:close()
			print("Service \"" .. name .. "\" has been disabled, it will not be launched next boot.")
			return
		end
	end
	io.stderr:write("Service \"" .. name .. "\" is not enabled.\n")
elseif args[1] == "list" then
	print("Enabled Services:")
	for k, v in pairs(services.enabled) do
		print("- " .. v)
	end

	print("All Services:")
	for path in filesystem.list("A:/Fuchas/Services/") do
		print("- " .. path:sub(1, -5))
	end
else
	io.stderr:write("Invalid operation! Usage: service <enable|disable|list>\n")
end
