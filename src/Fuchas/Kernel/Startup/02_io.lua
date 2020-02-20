local fs = require("filesystem")
local comp = require("component")
local gpu = comp.proxy(comp.list("gpu")())

-- Obsolete I/O methods
function io.fromu16(x)
	local b1=string.char(x%256) x=(x-x%256)/256
	local b2=string.char(x%256)
	return {b1, b2}
end

function io.fromu32(x)
	local b1=string.char(x%256) x=(x-x%256)/256
	local b2=string.char(x%256) x=(x-x%256)/256
	local b3=string.char(x%256) x=(x-x%256)/256
	local b4=string.char(x%256)
	return {b1, b2, b3, b4}
end

function io.tou16(arr, off)
	local v1 = arr[off + 1]
	local v2 = arr[off]
	return v1 + (v2*256)
end

function io.tou32(arr, off)
	local v1 = io.tou16(arr, off + 2)
	local v2 = io.tou16(arr, off)
	return v1 + (v2*65536)
end

-- New I/O methods

-- To unsigned number (max 32-bit)
function io.tounum(number, count, littleEndian)
	local data = {}
	
	if count > 4 then
		error("lua bit32 only supports 32-bit numbers")
	end
	
	if littleEndian then
		local i = count
		while i > 0 do
			data[i] = bit32.band(number, 0x000000FF)
			number = bit32.rshift(number, 8)
			i = i - 1
		end
	else
		local i = 1
		while i < count+1 do
			data[i] = bit32.band(number, 0x000000FF)
			number = bit32.rshift(number, 8)
			i = i + 1
		end
	end
	return data
end

-- From unsigned number (max 32-bit)
function io.fromunum(data, littleEndian, count)
	count = count or 0
	if count == 0 then
		if type(data) == "string" then
			count = data:len()
		else
			count = #data
		end
	end
	if type(data) ~= "string" then
		data = string.char(table.unpack(data))
	end
	
	if count > 4 then
		error("lua bit32 only supports 32-bit numbers")
	end
	
	if count == 1 then
		if data then
			return string.byte(data)
		else
			return nil
		end
	else
		-- use 4 bytes max as Lua's bit32 scale the number between [0, 2^32-1] which makes the number impossible to
		-- go beyond ‭4,294,967,295‬
		local bytes, result = {string.byte(data or "\x00", 1, 4)}, 0
		if littleEndian then
			local i = #bytes -- just do it in reverse order
			while i > 0 do
				result = bit32.bor(bit32.lshift(result, 8), bytes[i])
				i = i - 1
			end
		else
			local i = 1
			while i <= #bytes do
				result = bit32.bor(bit32.lshift(result, 8), bytes[i])
				i = i + 1
			end
		end
		return result
	end
end

function io.createStdOut()
	local stream = {}
	local sh = require("shell")
	local w, h = gpu.getViewport()
	stream.close = function(self)
		return false -- unclosable stream
	end
	stream.write = function(self, val)
		if val:find("\t") then
			val = val:gsub("\t", "    ")
		end
		if sh.getX() >= 160 then
			sh.setX(0)
			sh.setY(sh.getY() + 1)
		end
		if val:find("\n") then
			for line in val:gmatch("([^\n]+)") do
				if sh.getY() == h then
					gpu.copy(1, 2, w, h - 1, 0, -1)
					gpu.fill(1, h, w, 1, " ")
					sh.setY(sh.getY() - 1)
				end
				gpu.set(sh.getX(), sh.getY(), line)
				sh.setX(1)
				sh.setY(sh.getY() + 1)
			end
		else
			if sh.getY() == h then
				gpu.copy(1, 2, w, h - 1, 0, -1)
				gpu.fill(1, h, w, 1, " ")
				sh.setY(sh.getY() - 1)
			end
			gpu.set(sh.getX(), sh.getY(), val)
			sh.setX(sh.getX() + string.len(val))
		end
		return true
	end
	stream.read = function(self, len)
		return nil -- cannot read stdOUT
	end
	return stream
end

function io.createStdErr()
	local stream = {}
	stream.write = function(self, val)
		local fg = gpu.getForeground()
		gpu.setForeground(0xFF0000)
		local b = io.stdout:write(val)
		gpu.setForeground(fg)
		return b
	end
	--stream.write = io.stdout.write
	stream.read = io.stdout.read
	stream.close = io.stdout.close
	return stream
end

io.stdout = io.createStdOut()
io.stderr = io.createStdErr()

require("shell").setCursor(1, gy())
_G.gy = nil

-- Redefine NT's stdio functions

function print(msg)
	write(tostring(msg) .. "\n")
end

function io.write(msg)
	io.stdout:write(tostring(msg))
end
write = io.write

function io.open(filename, mode)
	if not fs.isDirectory(filename) then
		local h, err = fs.open(filename, mode)
		if not h then
			return nil, err
		end
		return require("buffer").from(h)
	end
	return nil, "is directory"
end
