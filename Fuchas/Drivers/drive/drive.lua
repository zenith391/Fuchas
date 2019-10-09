local drv = {}
local drive = component.proxy(...)

local SECTOR_IO_TRESHOLD = 5
local sectorCache = { -- sectors are cached for faster properties/content reading.
	id = -1,
	addr = "",
	text = ""
}

function drv.isCompatible()
	return drive.type == "drive"
end

function drv.getLabel()
	return drive.getLabel()
end

function drv.setLabel(label)
	return drive.setLabel(label)
end

-- Should be used instdead of drv.readByte when possible, as it *can be* optimized
function drv.readBytes(off, len)
	local sectorId = math.ceil((off+1)/512)
	if sectorCache.id ~= sectorId or sectorCache.addr ~= addr then
		sectorCache.id = sectorId
		sectorCache.addr = addr
		sectorCache.text = drive.readSector(sectorId)
	end
	local bytes = table.pack(string.byte(sectorCache.text:sub(off%512+1, off%512+len)))
	if asString then
		return table.pack(string.char(bytes))
	else
		return table.unpack(bytes)
	end
end

-- Should be used instdead of drv.writeByte when possible, as it *can be* optimized
function drv.writeBytes(offset, data, len)
	if type(data) == "string" then
		data = table.pack(string.byte(data, 1, string.len(data)))
	end
	if #data > SECTOR_IO_TRESHOLD and false then -- if it became more efficient to use sector i/o
		local sector = math.ceil((off+1)/512)
		local offset = (off+1)%512
		local sec = drive.readSector(sector)
		sec = sec:sub(1, offset-1) .. string.char(table.unpack(data)) .. sec:sub(offset+#data+1)
		drive.writeSector(sector, sec)
	else
		for i=1, #data do
			drive.writeByte(off+i-1, data[i])
		end
	end
end

function drv.readByte(off)
	return drive.readByte(off)
end

function drv.writeByte(off, val)
	drive.writeByte(off, val)
end

function drv.getRank()
	return -1
end

function drv.getName()
	return "MightyPirates GmbH. Drive"
end

return drv