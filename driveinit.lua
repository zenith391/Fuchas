local pc = computer or package.loaded.computer
local cp = component or package.loaded.component
local bootAddr = pc.getBootAddress()
local drive = cp.proxy(bootAddr)
driveRead = function(addr, offset, size)
	local i = offset
	local proxy = cp.proxy(addr)
	local out = ""
	if size < proxy.getSectorSize() then
		while i < offset + size do
			out = out .. proxy.readByte(i)
			i = i + 1
		end
	else
		local sects = size % proxy.getSectorSize()
		while i < offset + size do
			out = out .. proxy.readSector(i / proxy.getSectorSize())
			i = i + proxy.getSectorSize()
		end
		while i < offset + size do
			out = out .. proxy.readByte(i)
			i = i + 1
		end
	end
end
local bootCode = driveRead(bootAddr, drive.getCapacity() - 2048, 2048)