-- Fuchas Boot Manager

local proxy = component.proxy(computer.getBootAddress())
local arc = ""
for i=1, 10 do
	arc = arc .. proxy.readSector(1 + i) -- start at sector 2 per OpenUPT
end

local bitOr, bitLShift
if _VERSION == "Lua 5.3" then
	bitOr = function(a, b)
		return a | b
	end
	bitLShift = function(operand, shift)
		return operand << shift
	end
else
	bitOr = bit32.bor
	bitLShift = bit32.lshift
end

local function getFilesystemDriver(pType)
	local i = 1
	while i < arc:len() do
		local name = ""
		while arc:sub(i, i) ~= "\0" do
			name = name .. arc:sub(i, i)
			i = i + 1
		end
		i = i + 1
		local data = ""
		while arc:sub(i, i) ~= "\0" do
			data = data .. arc:sub(i, i)
			i = i + 1
		end
		i = i + 1
		if name == tostring(pType) then
			return load(data)()
		end
	end
end

-- read little-endian number
local function readInt(pos, size)
	local num = 0
	for i=size, 1, -1 do
		local byte = proxy.readByte(pos + i)
		num = bitOr(bitLShift(num, 8), byte)
	end
end

for i=0, 7 do
	if readInt(20 + i * 64) == 0xCAFEBEEF then -- Fuchas' root partition GUID
		local pType = readInt(8 + i * 64) -- treat the type as a int as it's easier that way
		local driver = getFilesystemDriver(pType)
		os_arguments = ...
		load(driver.readAll(
			readInt(i * 64), -- start
			readInt(4 + i * 64), -- end
			"Fuchas/Kernel/boot.lua" -- path
		))()
	end
end
