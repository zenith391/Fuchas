local drv = {}
local pos = 0
local cp, tape = ...
tape = cp.proxy(tape)

function drv.isCompatible()
	return tape.type == "tape_drive"
end

local function sync(off)
	if tape.getPosition then pos = tape.getPosition() end
	if pos ~= offset then
		tape.seek(offset - pos)
		pos = offset
	end
end

local function checkInsert()
	if not tape.isReady() then
		error("tape not inserted")
	end
end

function drv.getLabel()
	checkInsert()
	return tape.getLabel()
end

function drv.setLabel(label)
	checkInsert()
	tape.setLabel(label)
	return tape.getLabel()
end

function drv.readBytes(off, len)
	checkInsert()
	sync(off)
	return tape.read(len)
end

-- Should be used instdead of drv.writeByte when possible, as it *can be* optimized
function drv.writeBytes(offset, data, len)
	checkInsert()
	if type(data) == "string" then
		local d = {}
		for i=1, #data do
			table.insert(d, data:sub(i, i))
		end
		data = d
	end
	sync(off)
	tape.write(data)
end

function drv.readByte(off)
	checkInsert()
	sync(off)
	return tape.read()
end

function drv.writeByte(off, val)
	checkInsert()
	sync(off)
	tape.write(val)
end

function drv.getRank()
	return 1
end

function drv.getName()
	return "Vexatos Computronics Inc. Tape Driver"
end

return drv