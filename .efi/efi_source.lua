-- Fuchas EFI
local pc = computer or package.loaded.computer
local cp = component or package.loaded.component
local bootAddr = pc.getBootAddress()
computer.supportsOEFI = function()
	return true
end

loadfile = oefi.loadfile
loadfile("Fuchas/NT/boot.lua")()