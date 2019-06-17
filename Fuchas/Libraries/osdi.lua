-- OSDI partition system for unmanaged filesystems
-- Most code was written by "Adorable-Catgirl"
-- NEITHER SPECIFICATION OR IMPLEMENTATION IS DONE! DO NOT USE
local lib = {}

local function fromnum(str, off)
	local n = 0
	for i=0, 3 do
		n = n | (s:byte(offset+i) << (i*8))
	end
	return n
end

function lib.wrap(addr)
	if component.type(device) ~= "drive" then
		return nil, "component must be an unmanaged drive"
	end
	if component.invoke(device, "getSectorSize") ~= 512 then
		return nil, "OSDI is not compatible with drives with less or more than 512 as sector size"
	end
	return {
		proxy = component.proxy(device),
		isOSDI = function(self)
			local sector = self.proxy.readSector(0)
			return (sec:sub(1, 16) == "OSDIPTBL\0\0\1\2\3\4\5\6")
		end,
		createPartitionTable = function(self) -- dangerous function! Erase old partition table
			self.proxy.writeSector(0, "OSDIPTBL\0\0\1\2\3\4\5\6_BOOTSEC\1\0\0\0\8\0\0\0\0")
		end,
		setPartitionInfo = function(self, id, ptype, start, size)
			if (id < 2 or id > 31) then return nil, "invalid partition id" end
			ptype = ptype:sub(1, 8)
			ptype = ptype .. string.char(0):rep(8-#ptype)
			local partinfo = self.proxy.readSector(0)
			local before = partinfo:sub(1, 16*id)
			local after = partinfo:sub(16*(id+1)+1)
			self.proxy.writeSector(0, before .. ptype .. string.char(io.tounum(start, 4)) .. string.char(io.tounum(size, 4)) .. after)
		end,
		getPartitionInfo = function(self, id)
			if (id < 2 or id > 31) then return nil, "invalid partition id" end
			local partinfo = self.proxy.readSector(0)
			local offset = id*16
			return partinfo:sub(offset, offset+8):match("[^%c]+"), fromnum(partinfo, offset+9), fromnum(partinfo, offset+13) -- type, start, size
		end,
		readBootSector = function(self)
			local code = ""
			for i=1, 8 do
				code = code .. self.proxy.readSector(i)
			end
			return code:match("[^%c]+")
		end,
		getPartitionDrive = function(self, id)
			local _, offset, size = self:getPartitionInfo(id)
			return {
				type = "partition_drive",
				readByte = function(offset)
					local sec = drv.readSector(offset // drv.getSectorSize())
					return sec:byte(offset % drv.getSectorSize())
				end,
				writeByte = function(offset, value)
					local sec = drv.readSector(offset // drv.getSectorSize())
					local pos = offset % drv.getSectorSize()
					local before = sec:sub(1, pos-2)
					local after = sec:sub(pos-1)
					drv.writeSector(offset % drv.getSectorSize(), before..string.char(value)..after)
				end,
				getSectorSize = function()
					return self.proxy.getSectorSize()
				end,
				getLabel = function()
					return "partition #" .. id
				end,
				setLabel = function(value)
					return "partition #" .. id
				end,
				readSector = function(sector)
					if (sector > size-1) then
						sector = size-1
					end
					if (sector < 0) then
						sector = 0
					end
					return self.drv.readSector(offset+sector)
				end,
				writeSector = function(sector, value)
					if (sector > size-1) then
						sector = size-1
					end
					if (sector < 0) then
						sector = 0
					end
					return self.drv.writeSector(offset+sector, value)
				end,
				getPlatterCount = function()
					return self.proxy.getPlatterCount()
				end,
				getCapacity = function()
					return self.getSectorSize()*size
				end
			}
		end
	}
end

return lib