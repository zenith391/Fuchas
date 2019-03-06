-- Made by zenith391
-- It relies on the installer to place a proper boot init at the last 4096 bytes
-- However, it makes the copy hard, and and if drive is somehow, in the future, converted entirely to a managed mode drive,
-- then it would be unable to boot. However, due to the 512 bytes restriction imposed by advancedLoader (and 1K restriction by my future OCFS), it's the only possible way
local cp=component
local b=computer.getBootAddress()
local d=cp.proxy(b)
r = function(addr,offset,size)
	local i=offset
	local out=""
	if size < d.getSectorSize() then
		while i < offset+size do
			out = out..d.readByte(i)
			i = i + 1
		end
	else
		local sects = size % d.getSectorSize()
		while i < offset+size do
			out=out..d.readSector(i/d.getSectorSize())
			i=i+d.getSectorSize()
		end
		while i < offset + size do
			out=out..d.readByte(i)
			i=i+1
		end
	end
end
load(driveRead(b,d.getCapacity()-4096,4096), "=c", "bt", _G)()()