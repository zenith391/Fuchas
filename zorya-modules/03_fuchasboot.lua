-- 03_fuchasboot.lua
-- Boots the Fuchas NT Kernel.
-- Note: Preferably use OEFI for booting.
local comp = component or require("component")
local args = {...}
local envs = args[1]
local function scan()
	for fs in comp.list("filesystem") do
		if (comp.invoke(fs, "exists", "Fuchas/NT/boot.lua")) then
			envs.boot[#envs.boot+1] = {"Fuchas on "..fs:sub(1, 3), "fuchas", fs, {}}
		end
	end
end

if (_ZVER > 0.2) then
	envs.scan[#envs.scan+1] = scan
else
	scan()
end

envs.hand["fuchas"] = function(fs, args)
	computer.supportsOEFI = function()
		return _ZVER >= 1.0
	end
	-- it will autodetect if zorya is enabled
	computer.getBootAddress = function() return fs end
	loadfile = function(path)
		return envs.loadfile(fs, path)
	end
	envs.loadfile(fs, "Fuchas/NT/boot.lua")(oefi, table.unpack(args))
end
