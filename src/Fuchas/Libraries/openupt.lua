-- Fuchas implementation of OpenUPT 1
local lib = {}

function lib.readPartitionList(driver)
	local partitions = {}
	local off = 25*512
	for i=0, 7 do
		local partition = {
			id = i,
			start = io.fromunum(driver.readBytes(off+1, 4), true),
			["end"] = io.fromunum(driver.readBytes(off+5, 4), true),
			type = driver.readBytes(off+9, 8, true),
			flags = io.fromunum(driver.readBytes(off+17, 4), true),
			guid = driver.readBytes(off+21, 8, true),
			label = driver.readBytes(off+33, 32, true)
		}
		if partition.type ~= "\x00\x00\x00\x00\x00\x00\x00\x00" then -- non-null FS type
			table.insert(partitions, partition)
		end
		off = off + 64
	end
	return partitions
end

function lib.partitionDriver(driver, partition)
	local driver = {
		getLabel = function()
			return partition.label
		end,
		setLabel = function(label)
			partition.label = label:sub(1, 32)
			writePartition(driver, partition)
		end,
		readBytes = function(addr, len, asString)
			return driver.readBytes(addr+partition.start*512, len, asString)
		end,
		writeBytes = function(addr, data, len)
			driver.writeBytes(addr+partition.start*512, data, len)
		end,
		readByte = function(addr)
			return driver.readByte(addr+partition.start*512)
		end,
		writeByte = function(addr, value)
			driver.writeByte(addr+partition.start*512, value)
		end
	}
end

function lib.writePartition(driver, partition)
	local off = 25*512+partition.id*64
	driver.writeBytes(off+1, "\x00":rep(64))
	driver.writeBytes(off+1, io.tounum(partition.start, 4, true))
	driver.writeBytes(off+5, io.tounum(partition.end, 4, true))
	driver.writeBytes(off+9, partition.type)
	driver.writeBytes(off+17, io.tounum(partition.flags, 4, true))
	driver.writeBytes(off+21, partition.guid)
	driver.writeBytes(off+33, partition.label)
end

return lib
