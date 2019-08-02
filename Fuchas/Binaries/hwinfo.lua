local info = computer.getDeviceInfo()

print("Hardware Info:")
print("\tHas OEFI? " .. tostring(ifOr(computer.supportsOEFI(), true, false)))

print("Extended Info:")
if info == nil then
	print("\t  Your computer doesn't support extended hardware information.")
	return
end

for k, v in pairs(info) do
	print("\t" .. v.product .. "(" .. k:sub(1, 3) .. "):")
	print("\t  Vendor: " .. v.vendor)
	print("\t  Class: " .. v.class)
end
