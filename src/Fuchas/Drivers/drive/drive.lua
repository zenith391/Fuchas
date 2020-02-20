local spec = {}
local SECTOR_IO_TRESHOLD = 5
local cp = ...

function spec.getRank()
	return -1
end

function spec.getName()
	return "MightyPirates GmbH. Drive"
end

function spec.isCompatible(address)
	return cp.proxy(address).type == "drive"
end

function spec.new(address)
	drive = cp.proxy(address)

	local drv = {}
	local sectorCache = { -- sectors are cached for faster properties/content reading.
		id = -1,
		addr = "",
		text = ""
	}

	function drv.getLabel()
		return drive.getLabel()
	end

	function drv.setLabel(label)
		return drive.setLabel(label)
	end

	-- Should be used instdead of drv.readByte when possible, as it *can be* optimized
	function drv.readBytes(off, len, asString)
		local sectorId = math.ceil(off/512)
		if sectorCache.id ~= sectorId or sectorCache.addr ~= addr then
			sectorCache.id = sectorId
			sectorCache.addr = addr
			sectorCache.text = drive.readSector(sectorId)
		end
		local bytes = table.pack(string.byte(sectorCache.text:sub(off%512, off%512+len)))
		if asString then
			return string.char(table.unpack(bytes))
		else
			return bytes
		end
	end

	-- Should be used instdead of drv.writeByte when possible, as it *can be* optimized
	function drv.writeBytes(off, data, len)
		if type(data) == "string" then
			data = table.pack(string.byte(data, 1, string.len(data)))
		end
		if #data > SECTOR_IO_TRESHOLD then -- if it became more efficient to use sector i/o
			local sector = math.ceil(off/512)
			local offset = off%512
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

	return drv
end

return spec