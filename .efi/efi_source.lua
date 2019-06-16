-- Fuchas EFI2 source code
local pc = computer or package.loaded.computer
local cp = component or package.loaded.component
local bootAddr = pc.getBootAddress()
cp.supportsOEFI = function()
	return true
end
loadfile = oefi.loadfile
loadfile("Fuchas/NT/boot.lua")()