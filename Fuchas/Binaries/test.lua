local drv = require("driver")
local driver = drv.sound

print("Driver Name: " .. driver.getName())
print("Capabilitites:")
for k, v in pairs(driver.getCapabilities()) do
	print("\t" .. k .. ": " .. tostring(v))
end
