local drv = require("driver")
local args, ops = require("shell").parse(...)
local t = args[1] or "sound"
local driver = drv[t]

if driver == nil then
	io.stderr:write("No component recognized with type \"" .. tostring(t) .. "\"\n")
	return
end

print("Driver Name: " .. driver.spec.getName())
if driver.getCapabilities then
	print("Capabilitites:")
	for k, v in pairs(driver.getCapabilities()) do
		local b = v
		if type(v) == "boolean" then
			b = ifOr(v, "yes", "no")
		end
		print("\t" .. k .. ": " .. tostring(b))
	end
end
