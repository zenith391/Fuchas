-- Fuchas implementation of OpenUPT 1
local lib = {}

function lib.openupt1()
	local upt = {}
	-- Fuchas code for boot sector on newly formated drives
	local defaultBootCode = [[local cp = component
	local gpu, screen = cp.list("gpu")(), cp.list("screen")()
	if not gpu or not screen then
		error("Non-System disk or drive inserted.")
	end
	gpu = cp.proxy(gpu)
	gpu.bind(screen)
	gpu.setResolution(gpu.maxResolution())
	gpu.fill(1, 1, gpu.getResolution())
	gpu.set(1, 1, "Non-System disk or drive inserted.")
	gpu.set(1, 2, "Press any key to reboot.")
	while true do
		if computer.pullSignal() == "key_down" then
			computer.shutdown(true)
		end
	end]]

	local function toTextGUID(guid)
		local result = ""
		for k, v in pairs(guid) do
			local hex = string.format("%x", v)
			if hex:len() == 1 then
				hex = "0" .. hex
			end
			result = result .. hex
		end
		return result
	end

	local function fromTextGUID(guid)
		local arr = {}
		for i=0, 7 do
			local sub = guid:sub(1+i*2, 2+i*2)
			table.insert(arr, tonumber(sub, 16))
		end
		return arr
	end

	function upt.readPartitionList(driver)
		local partitions = {}
		local off = 25*512
		for i=0, 7 do
			local partition = {
				id = i,
				start = io.fromunum(driver.readBytes(off+0, 4), true),
				["end"] = io.fromunum(driver.readBytes(off+4, 4), true),
				type = driver.readBytes(off+8, 8, true),
				flags = io.fromunum(driver.readBytes(off+16, 4), true),
				guid = toTextGUID(driver.readBytes(off+20, 8)),
				label = driver.readBytes(off+28, 36, true)
			}
			if partition.type ~= ("\x00"):rep(8) and partition.start ~= 0 then -- non-null FS type
				table.insert(partitions, partition)
			end
			off = off + 64
		end
		return partitions
	end

	function upt.partitionDriver(driver, partition)
		local driver = {
			getLabel = function()
				local labelEnd = partition.label:find("\x00") or partition.label:len()+1
				return partition.label:sub(1, labelEnd-1)
			end,
			setLabel = function(label)
				partition.label = label:sub(1, 36)
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
			end,
			getCapacity = function()
				return (partition["end"] - partition.start) * 512
			end,
			address = partition.guid
		}
		return driver
	end

	local guidSeed = 1
	function upt.randomGUID()
		local guid = ""
		for i=1, 8 do
			local hex = string.format("%x", math.random(0, 0xFF))
			if hex:len() == 1 then
				hex = "0" .. hex
			end
			guid = guid .. hex
		end
		return guid
	end

	function upt.newPartition(id, start, pend, guid)
		return {
			id = id,
			start = start or 0,
			["end"] = pend or 0,
			type = ("\x00"):rep(8),
			flags = 0,
			guid = guid or upt.randomGUID(),
			label = ("\x00"):rep(36)
		}
	end

	local function addTables(dst, src)
		for k, v in ipairs(src) do
			table.insert(dst, v)
		end
	end

	-- partition number is ZERO-BASED
	function upt.writePartition(driver, partition, progressHandler)
		local off = 25*512+partition.id*64
		local data = {}
		addTables(data, io.tounum(partition.start, 4, true))
		addTables(data, io.tounum(partition["end"], 4, true))
		addTables(data, string.toByteArray(partition.type))
		addTables(data, io.tounum(partition.flags, 4, true))
		addTables(data, fromTextGUID(partition.guid))
		if partition.label:len() < 36 then
			partition.label = partition.label .. ("\x00"):rep(36 - partition.label:len())
		end
		addTables(data, string.toByteArray(partition.label:sub(1, 36)))
		if progressHandler then progressHandler("Writing partition #" .. (partition.id+1) .. "..") end
		driver.writeBytes(off, data)
		if progressHandler then progressHandler("Done writing partition.") end
	end

	function upt.format(driver, progressHandler)
		if progressHandler then progressHandler("Writing boot code..") end
		driver.writeBytes(1, defaultBootCode)
		for i=0, 7 do
			upt.writePartition(driver, upt.newPartition(i), progressHandler)
		end
		if progressHandler then progressHandler("Done formatting.") end
	end

	return upt
end

return lib