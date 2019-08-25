local level = 0
-- 0: Kernel (kernel library, event, component, etc.)
-- 1: Driver (printers, GPUs, keyboards)
-- 2: Security (permissions)
-- 3: Interface (Fushell, Concert, etc.)
-- 3: Application (dir, etc.)

local mod = {}

function mod.runlevel(lvl)
	if lvl then
		level = lvl
	end
	return level
end 

return mod