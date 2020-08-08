local fs = require("filesystem")
local comp = require("component")
local gpu = comp.proxy(comp.list("gpu")())

-- These functions are to be used for programs to be compatible between Lua 5.2 and 5.3
-- Serialize unsigned number (max 32-bit)
function io.tounum(number, count, littleEndian, toString)
	local data = {}

	if _VERSION == "Lua 5.3" then -- use string.pack on Lua 5.3
		local endianess = (littleEndian and "<") or ">"
		return load([[
			local number, count, endianess, toString = ...
			local str = string.pack(endianess .. "I" .. count, number)
			if toString then
				return str
			else
				return table.pack(str:byte(1, #str))
			end
		]])(number, count, endianess, toString)
	end
	
	if count > 4 then
		error("only 32-bit numbers are supported")
	end
	
	if littleEndian then
		for i=1, count do
			data[i] = bit32.band(number, 0xFF)
			number = bit32.rshift(number, 8)
		end
	else
		for i=1, count do
			data[count-i+1] = bit32.band(number, 0xFF)
			number = bit32.rshift(number, 8)
		end
	end
	if toString then
		local s = ""
		for k, v in ipairs(data) do
			s = s .. string.char(v)
		end
		return s
	end
	return data
end

-- Unserialize unsigned number (max 32-bit)
function io.fromunum(data, littleEndian, count)
	count = count or #data
	if type(data) ~= "string" then
		data = string.char(table.unpack(data))
	end

	if _VERSION == "Lua 5.3" then -- use string.unpack on Lua 5.3
		local endianess = (littleEndian and "<") or ">"
		return load([[
			local data, count, endianess = ...
			return string.unpack(endianess .. "I" .. count, data)
		]])(data, count, endianess)
	end
	
	if count > 4 then
		error("only 32-bit numbers are supported")
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

function io.createStdErr(stdout)
	local stream = {}
	stdout = stdout or io.stdout
	stream.write = function(self, val)
		local fg = gpu.getForeground()
		gpu.setForeground(0xFF0000)
		local b = (io.stdout or stdout):write(val)
		gpu.setForeground(fg)
		return true
	end
	stream.read = stdout.read
	stream.close = stdout.close
	return stream
end

function io.createStdIn()
	local stream = {}

	stream.read = function(self)
		return require("shell").read()
	end

	stream.write = function(self)
		return false
	end
	stream.close = function(self)
		return false
	end

	return stream
end

local termStdOut = require("shell").createStdOut(require("driver").gpu)
local termStdErr = io.createStdErr(termStdOut)
local termStdIn = io.createStdIn()

require("shell").setCursor(1, gy())
_G.gy = nil

function io.open(filename, mode)
	if not fs.isDirectory(filename) then
		local h, err = fs.open(filename, mode or "r")
		if not h then
			return nil, err
		end
		return require("buffer").from(h)
	end
	return nil, "is directory"
end

function io.input(file)
	if type(file) == "string" then
		file = io.open(file, "r")
	end
	local proc = require("tasks").getCurrentProcess()
	if file then
		proc.io.stdin = file
	end
	return proc.io.stdin
end

function io.output(file)
	if type(file) == "string" then
		file = io.open(file, "w")
	end
	local proc = require("tasks").getCurrentProcess()
	if file then
		proc.io.stdout = file
		proc.io.stderr = io.createStdErr()
	end
	return proc.io.stdout
end

function io.flush()
	if io.stdout.flush then -- if the stream is buffered
		io.stdout:flush()
	end
end

function io.read()
	return io.stdin:read()
end

function io.close(file)
	if file then
		file:close()
	else
		io.stdout:close()
	end
end

function io.popen(prog, mode)
	if not mode then mode = "r" end
	local resolved = require("shell").resolve(prog)
	if not resolved then
		error("could not resolve the program")
	end
	local func = loadfile(resolved)
	return io.pipedProc(func, mode)
end

function io.pipedProc(func, name, mode)
	if not mode then mode = "r" end
	local proc = require("tasks").newProcess(name, func)
	if mode == "r" then
		local inp, out = require("buffer").pipedStreams(false)
		proc.io.stdout = out
		return inp, proc
	elseif mode == "w" then
		local inp, out = require("buffer").pipedStreams(false)
		proc.io.stdin = inp
		return out, proc
	end
end

function io.type(obj)
	if type(obj) == "table" then
		if obj.closed then
			return "closed file"
		elseif (obj.read or obj.write) and obj.close then
			return "file"
		end
	end
	return nil
end

function io.write(msg)
	io.stdout:write(tostring(msg))
end

-- Redefine kernel basic stdio functions

function print(...)
	local parts = table.pack(...)
	local str = ""
	for k, v in ipairs(parts) do
		str = str .. tostring(v)
		if k ~= #parts then
			str = str .. "\t"
		end
	end
	str = str .. "\n"
	io.write(str)
end

setmetatable(io, {
	__index = function(self, k)
		local proc = require("tasks").getCurrentProcess()
		if proc == nil then
			if k == "stdout" then
				return termStdOut
			elseif k == "stderr" then
				return termStdErr
			elseif k == "stdin" then
				return termStdIn
			end
		else
			if k == "stdout" then
				return proc.io.stdout
			elseif k == "stderr" then
				return proc.io.stderr
			elseif k == "stdin" then
				return proc.io.stdin
			end
		end
	end,
	__newindex = function()
		error("cannot set io")
	end
})

write = nil
