local drv = require("driver")
local args, ops = require("shell").parse(...)
local t = args[1] or "sound"
local driver = drv[t]

if driver == nil then
	error("No component driver with type \"" + tostring(t) + "\"")
end

print("Driver Name: " .. driver.spec.getName())
if driver.getCapabilities then
	print("Capabilitites:")
	for k, v in pairs(driver.getCapabilities()) do
		print("\t" .. k .. ": " .. tostring(v))
	end
end
