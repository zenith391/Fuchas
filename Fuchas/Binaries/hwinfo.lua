local info = computer.getDeviceInfo()

print("Software Info:")
print("\tHas OEFI? " .. tostring(ifOr(computer.supportsOEFI(), "Yes", "No")))
if computer.supportsOEFI() then
	local oefi = require("oefi")
	print("\tOEFI Version: " .. oefi.getAPIVersion())
	print("\tImplementation: " .. oefi.getImplementationName())
end

print("Hardware Info:")
if info == nil then
	print("\tYour computer doesn't support extended hardware information.")
	return
end

for k, v in pairs(info) do
	print("\t" .. v.product .. "(" .. k:sub(1, 3) .. "):")
	print("\t  Vendor: " .. v.vendor)
	print("\t  Class: " .. v.class)
end
