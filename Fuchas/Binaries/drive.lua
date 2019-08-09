local fs = require("filesystem")

for drv, v in pairs(fs.mounts()) do
	print(drv .. ":/ (" .. math.floor(v.fs.spaceUsed()/1000) .. "KB/" .. math.floor(v.fs.spaceTotal()/1000) .. "KB used)")
end