local spec = {}
local SECTOR_IO_TRESHOLD = 10
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
		if off < 1 then error("addresses are 1-based") end
		local sectorId = math.ceil((off-1)/512)
		if sectorId == 0 then sectorId = 1 end
		if sectorCache.id ~= sectorId then
			sectorCache.id = sectorId
			sectorCache.text = drive.readSector(sectorId)
		end
		local bytes = table.pack(string.byte(sectorCache.text:sub((off-1)%512, (off-1)%512+1+len), 1, len))
		if asString then
			return sectorCache.text:sub(off%512, off%512+1+len)
		else
			return bytes
		end
	end

	-- Should be used instdead of drv.writeByte when possible, as it *can be* optimized
	function drv.writeBytes(off, data, len)
		if type(data) == "string" then
			data = string.toCharArray(data)
			for i=1, #data do
				data[i] = string.byte(data[i])
			end
		end
		local sectorId = math.ceil((off-1)/512)
		if sectorId == 0 then sectorId = 1 end
		if sectorCache.id == sectorId then
			sectorCache.id = -1 -- invalidate cache because we're going to write it
		end
		if #data > SECTOR_IO_TRESHOLD then -- if it became more efficient to use sector i/o
			local offset = (off-1)%512
			local sec = drive.readSector(sectorId)
			sec = sec:sub(1, offset) .. string.char(table.unpack(data)) .. sec:sub(offset+#data+1)
			drive.writeSector(sectorId, sec)
		else
			for i=1, #data do
				drive.writeByte(off+i-1-1, data[i])
			end
		end
		coroutine.yield()
	end

	function drv.readByte(off)
		return drive.readByte(off)
	end

	function drv.writeByte(off, val)
		drive.writeByte(off-1, val)
	end

	function drv.getCapacity()
		return drive.getCapacity()
	end

	return drv
end

return spec