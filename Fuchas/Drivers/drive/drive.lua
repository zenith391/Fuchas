local spec = {}
local SECTOR_IO_TRESHOLD = 10 -- read sector + write sector only costs around 4 times as a byte write
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

-- TODO: disk buffer that only writes at each coroutine.yield()
function spec.new(address)
	drive = cp.proxy(address)

	local sectorSize = drive.getSectorSize()

	local drv = {}
	local diskBuffer = {}
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

	-- Should be used instead of drv.readByte when possible, as it *can be* optimized
	-- off is zero-based!
	function drv.readBytes(off, len, asString)
		local sectorId = math.floor(off/512) + 1
		if len > sectorSize then
			local a = drv.readBytes(off, sectorSize, asString)
			local b = drv.readBytes(off+sectorSize, len-sectorSize, asString)
			if asString then
				local result = a .. b
				return result
			else
				local result = {}
				for _, v in ipairs(a) do table.insert(result, v) end
				for _, v in ipairs(b) do table.insert(result, v) end
				return result
			end
		end

		if diskBuffer[sectorId] then
			sectorCache.id = sectorId
			sectorCache.text = diskBuffer[sectorId]
		end
		if sectorCache.id ~= sectorId then
			sectorCache.id = sectorId
			sectorCache.text = drive.readSector(sectorId)
		end
		local bytes = { string.byte(sectorCache.text:sub(off%512+1, off%512+len-1+1), 1, len) }
		if asString then
			return sectorCache.text:sub(off%512+1, off%512+len-1+1)
		else
			return bytes
		end
	end

	-- Should be used instdead of drv.writeByte when possible, as it *can be* optimized
	-- off is zero-based!
	function drv.writeBytes(off, data)
		if type(data) == "string" then
			data = string.toByteArray(data)
		end
		local sectorId = math.floor(off/512) + 1
		if sectorCache.id == sectorId then
			sectorCache.id = -1 -- invalidate cache because we're going to write it
		end

		if #data > SECTOR_IO_TRESHOLD or diskBuffer[sectorId] then -- if it became more efficient to use sector i/o
			local offset = off%512
			if offset == 0 and #data == sectorSize then
				local sec = string.char(table.unpack(data))
				diskBuffer[sectorId] = sec
			else
				if #data > 512 - offset then
					drv.writeBytes(off, table.pack(table.unpack(data, 1, 512 - offset)))
					drv.writeBytes(off + 512 - offset, table.pack(table.unpack(data, 512 - offset)))
					return
				end
				local sec = diskBuffer[sectorId] or drive.readSector(sectorId)
				sec = sec:sub(1, offset) .. string.char(table.unpack(data)) .. sec:sub(offset+#data+1)
				diskBuffer[sectorId] = sec
			end
		else
			for i=1, #data do
				drive.writeByte(off+i-1+1, data[i])
			end
			-- we don't have to update the disk buffer as it is handled by the other if case
		end
		-- coroutine.yield()
	end

	-- off is zero-based!
	function drv.readByte(off)
		local sectorId = math.floor(off/512) + 1
		if diskBuffer[sectorId] then
			local offset = off%512
			return diskBuffer[sectorId]:sub(offset+1,offset+1):byte()
		end
		return drive.readByte(off+1)
	end

	-- off is zero-based!
	function drv.writeByte(off, val)
		local sectorId = math.floor(off/512) + 1
		if not diskBuffer[sectorId] then
			-- writeByte calls tend to happen randomly on few sectors, which is perfect for disk buffer
			diskBuffer[sectorId] = drive.readSector(sectorId)
		end

		if diskBuffer[sectorId] then
			local offset = off%512 + 1
			local sec = diskBuffer[sectorId]
			val = bit32.band(val, 0xFF) -- convert to unsigned
			sec = sec:sub(1, offset-1) .. string.char(val) .. sec:sub(offset+1)
			diskBuffer[sectorId] = sec
		else
			drive.writeByte(off+1, val)
		end
	end

	function drv.getCapacity()
		return drive.getCapacity()
	end

	-- Flush the disk buffer
	function drv.flushBuffer(max)
		max = max or math.huge

		local wrote = 0
		for sector, text in pairs(diskBuffer) do
			drive.writeSector(sector, text)
			diskBuffer[sector] = nil
			wrote = wrote + 1
			if wrote >= max then
				break
			end
		end
		if wrote == 0 then diskBuffer = {} end
		return wrote
	end

	require("event").listen("shutdown", function()
		drv.flushBuffer()
	end)

	return drv
end

return spec
