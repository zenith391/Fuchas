local fs = require("filesystem")

local unit = "KB"
local unitDivider = (unit == "KiB" and 1024) or 1000
for drv, v in pairs(fs.mounts()) do
	print(drv .. ":/ (" .. math.floor(v.fs.spaceUsed()/unitDivider) .. unit .. "/" .. math.floor(v.fs.spaceTotal()/unitDivider) .. unit .. " used)" .. " - Address: " .. v.fs.address)
end
