local drv = require("driver")
local args, ops = require("shell").parse(...)
local t = args[1]

if not t then
	print("Usage: driverinfo [driver type]")
	return
end

local driver = drv[t]

if driver == nil then
	io.stderr:write("No driver recognized with type \"" .. tostring(t) .. "\"\n")
	return
end

print("Driver Name: " .. driver.spec.getName())
print("Component Address: " .. driver.address)
if driver.getCapabilities then
	print("Capabilitites:")
	for k, v in pairs(driver.getCapabilities()) do
		local b = v
		if type(v) == "boolean" then
			b = (v and "yes") or "no"
		end
		if type(v) == "table" then
			b = require("liblon").sertable(v, 2, false)
		end
		print("\t" .. k .. ": " .. tostring(b))
	end
end
