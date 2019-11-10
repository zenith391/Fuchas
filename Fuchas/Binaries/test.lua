local drv = require("driver")
local driver = drv.sound

for k, v in pairs(component.list()) do
	print(k .. " " .. v)
end

print("Driver Name: " .. driver.getName())
print("Capabilitites:")
for k, v in pairs(driver.getCapabilities()) do
	print("\t" .. k .. ": " .. tostring(v))
end
