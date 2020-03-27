local fs = require("filesystem")

for drv, v in pairs(fs.mounts()) do
	print(drv .. ":/ (" .. math.floor(v.fs.spaceUsed()/1024) .. "KiB/" .. math.floor(v.fs.spaceTotal()/1024) .. "KiB used)")
end
