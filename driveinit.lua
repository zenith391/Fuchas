--atr:zenith391
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
load(driveRead(b,d.getCapacity()-4096,4096),"=c","bt",_G)()()