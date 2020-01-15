print("Software Info:")
print("\tUsed Memory: " .. math.floor((computer.totalMemory()-computer.freeMemory())/1024) .. "/" .. math.floor(computer.totalMemory()/1024) .. " KiB")
print("\tHas OEFI? " .. tostring(ifOr(computer.supportsOEFI(), "Yes", "No")))
if computer.supportsOEFI() then
	local oefi = require("oefi")
	print("\tOEFI Version: " .. oefi.getAPIVersion())
	print("\tImplementation: " .. oefi.getImplementationName())
end

if not computer.getDeviceInfo then
	print("\tYour computer doesn't support extended hardware information.")
	return
end
local info = computer.getDeviceInfo()
print("Hardware Info:")
if info == nil then
	print("\tYour computer doesn't support extended hardware information.")
	return
end

for k, v in pairs(info) do
	print("\t" .. v.product .. " (" .. k:sub(1, 3) .. "):")
	print("\t  Vendor: " .. v.vendor)
	print("\t  Class: " .. v.class)
end
