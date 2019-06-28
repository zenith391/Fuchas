-- Fuchas EFI2 source code
-- efi_source.lon is app.lon
local pc = computer or package.loaded.computer
local cp = component or package.loaded.component
local bootAddr = pc.getBootAddress()
cp.supportsOEFI = function()
	return true
end
loadfile = oefi.loadfile
loadfile("Fuchas/NT/boot.lua")()