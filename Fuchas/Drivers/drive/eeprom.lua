-- Placeholder
local drv = {}
local cp, drive = ...
drive = cp.proxy(drive)

function drv.isCompatible()
	return false
end

function drv.getRank()
	return 1
end

return drv