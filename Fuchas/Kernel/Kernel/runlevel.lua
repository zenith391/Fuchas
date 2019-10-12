local level = 0
-- 0: Kernel (kernel library, event, component, etc.)
-- 1: Driver (printers, GPUs, keyboards)
-- 2: Security (permissions)
-- 3: Interface (Fushell, Concert, etc.)
-- 3: Application (dir, etc.)

local mod = {}
local restricted = {
	kernel = kernel,
	component = component,
	computer = computer,
}

function mod.value(lvl)
	if lvl then
		local ser = require("security")
		if ser.hasPermission("critical.runlevel.down") then
			-- TODO
		end
		level = lvl
	end
	return level
end

function mod.loadRestrict(chunk, source)
	local env = _ENV
	if level > 0 then
		env.kernel = nil
	end
	if level > 1 then
		--env._G = nil
		env.component = nil
		env.computer = nil
	end
	return load(chunk, source, "bt", env)
end

return mod
