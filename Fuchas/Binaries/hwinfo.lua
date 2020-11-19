print("Software Info:")
print("\tUsed Memory: " .. math.floor((computer.totalMemory()-computer.freeMemory())/1024) .. "/" .. math.floor(computer.totalMemory()/1024) .. " KiB")
print("\tUsing OEFI? " .. ((computer.supportsOEFI() and "Yes") or "No"))
if computer.supportsOEFI() then
	local oefi = require("oefi")
	print("\tOEFI Version: " .. oefi.getAPIVersion())
	print("\tImplementation: " .. oefi.getImplementationName())
end
if not computer.getDeviceInfo then
	print("\tThis computer doesn't support extended hardware information.")
	return
end
local ok, infos = pcall(computer.getDeviceInfo)
print("Hardware Info:")
if not ok or infos == nil then
	print("\tThis computer doesn't support extended hardware information. (ok = " .. tostring(ok) .. ", infos = " .. tostring(infos) .. ")")
	return
end

for addr, info in pairs(infos) do
	print("\t" .. (info.product or "Unknown") .. " (" .. addr:sub(1, 3) .. "):")
	for k, v in pairs(info) do
		local fmtKey = k:sub(1,1):upper() .. k:sub(2)
		print("\t  " .. fmtKey .. ": " .. v)
	end
end
