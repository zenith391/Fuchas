-- 03_fuchasboot.lua
-- Boots the Fuchas NT Kernel.
local comp = component or require("component")
local args = {...}
local envs = args[1]
for fs in comp.list("filesystem") do
	if (comp.invoke(fs, "exists", "Fuchas/NT/boot.lua")) then
		envs.boot[#envs.boot+1] = {"Fuchas NT on "..fs:sub(1, 3), "fuchas", fs, {}}
	end
end

envs.hand["fuchas"] = function(fs, args)
	computer.supportsOEFI = function()
		return false
	end
	computer.supportsZorya = function()
		return true
	end
	computer.getBootAddress = function() return fs end
	loadfile = function(path)
		return envs.loadfile(fs, path)
	end
	envs.loadfile(fs, "Fuchas/NT/boot.lua")(nil, table.unpack(args))
end
