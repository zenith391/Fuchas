--- Library used to buffer I/O streams and for some I/O stream utilities
-- @module buffer
-- @alias buffer

local buffer = {}

--- Create a buffered stream from the given unbuffered stream
-- @tparam stream handle unbuffered stream
-- @treturn stream Buffered stream
function buffer.from(handle)
	local stream = {}
	stream.stream = handle
	stream.buf = ""
	stream.wbuf = ""
	stream.size = require("config").buffer.readBufferSize
	stream.wsize = require("config").buffer.defaultWriteBufferSize
	stream.wmode = "full"
	stream.off = 0
	-- if a stream is greedy, it will not call coroutine.yield
	stream.greedy = false

	function stream:close()
		self:flush()
		self.stream:close()
		self.closed = true
	end
	
	function stream:write(val)
		checkArg(1, val, "string")
		if self.wmode == "no" then
			return self.stream:write(val)
		elseif self.wmode == "full" then
			local remaining = self.wsize - self.wbuf:len()
			local firstPart = val:sub(1, remaining)
			self.wbuf = self.wbuf .. firstPart
			self.off = self.off + firstPart:len()
			if val:len() > remaining then
				local secondPart = val:sub(remaining+1)
				self:flush()
				self:write(secondPart)
			end
		end
	end

	function stream:flush()
		if self.wbuf:len() > 0 then
			self.stream:write(self.wbuf)
		end
		self.wbuf = ""
	end

	function stream:fillBuffer()
		if self.buf and self.buf:len() == 0 then
			self.buf = self.stream:read(self.size)
		end
	end

	function stream:remaining()
		if not self:hasRemaining() then
			error("the underlying stream doesn't have remaining()")
		end
		return self.stream:remaining()
	end

	function stream:hasRemaining()
		return self.stream.remaining
	end

	function stream:readBuffer(len)
		local str = ""
		while str:len() < len do
			self:fillBuffer()
			if self.buf == nil then
				self.buf = ""
				if str:len() > 0 then
					return str
				else
					return nil
				end
			end
			
			local partLen = math.min(len - str:len(), self.buf:len())
			if len == math.huge then
				partLen = self.size-1
			end
			local part = self.buf:sub(1, partLen)
			self.buf = self.buf:sub(partLen+1, self.buf:len()) -- cut the read part
			str = str .. part
			self.off = self.off + part:len()
		end
		return str
	end

	function stream:read(f)
		if not f then
			f = "l"
		end
		if f == "a" or f == "*a" then -- the * before a or l and others is deprecated in Lua 5.3
			local s = ""
			while true do
				local r = self.stream:read(math.huge)
				self.off = self.stream:seek("cur", 0)
				if not stream.greedy and s ~= " " then
					coroutine.yield()
				end
				if r == nil then
					break
				end
				s = s .. r
			end
			return s
		elseif f == "l" or f == "*l" or f == "L" or f == "*L" then
			local s = ""
			while true do
				local r = self:read(1)
				if not r then
					if s == "" then
						return nil
					else
						break
					end
				end
				if r:find("\n") ~= nil or r:find("\r") ~= nil then -- support for unix and windows EOL
					if r:find("\r") then
						self:read(1) -- skip \n
					end
					if f == "L" or f == "*L" then
						if r:find("\r") then
							s = s .. "\r\n"
						else
							s = s .. "\n"
						end
					end
					return s
				end
				s = s .. r
			end
			return s
		elseif type(f) == "number" then
			return self:readBuffer(f)
		end
		return nil, "invalid mode"
	end

	function stream:seekable()
		if self.stream.seekable then
			return self.stream:seekable()
		else
			if self.stream.seek then
				return true
			else
				return false
			end
		end
	end

	function stream:setvbuf(mode, size)
		checkArg(1, mode, "string")
		if not size then
			size = self.wsize
		end
		size = math.max(math.min(size, require("config").buffer.maxWriteBufferSize), 1)
		if mode ~= "full" and mode ~= "line" then
			error("invalid vbuf mode " .. mode)
		end
		self.wmode = mode
		self.wsize = size
	end

	function stream:lines()
		local tab = {}
		while true do
			local line = self:read("l")
			if line == nil then
				break
			end
			table.insert(tab, line)
		end
		local i = 0
		setmetatable(tab, {
			__call = function()
				i = i + 1
				if i <= #tab then return tab[i] end
			end
		})
		return tab
	end

	function stream:seek(whence, offset)
		self:flush()
		if not whence then whence = "cur" end
		if not offset then offset = 0     end
		if whence == "cur" then
			local ok, err = self.stream:seek("set", self.off + offset)
			if offset < 0 and false then
				local prepend = self.stream:read(-offset)
				self.buf = prepend .. self.buf
				--ok, err = self.stream:seek("set", self.off + offset)
			else
				self.buf = "" -- TODO: optimize
			end
			self.off = self.off + offset
			return self.off, err
		else
			self.buf = ""
			return self.stream:seek(whence, offset)
		end
	end
	return stream
end

--- Returns an unbuffered stream that is backed by a string (in variable stream.data)
-- @string str The string from which to read or write
-- @treturn stream String stream
function buffer.fromString(str)
	local stream = {}
	stream.data = str
	stream.off = 1

	function stream:write(val)
		self.data = self.data:sub(1, self.off - 1) .. val .. self.data:sub(self.off)
		self.off = self.off + val:len()
	end

	function stream:read(len)
		local part = self.data:sub(self.off, self.off + len - 1)
		self.off = self.off + len
		return part
	end

	function stream:seek(whence, offset)
		if whence == "cur" then
			self.off = self.off + offset
			return self.off
		elseif whence == "beg" then
			self.off = 1 + offset
			return self.off
		else
			error("unsupported whence: " .. tostring(whence))
		end
	end

	function stream:close() end

	return stream
end

--- Return a set of stream that are piped to each other.
-- This is the equivalent of a `pipe` library on other operating systems.
-- @bool[opt=false] unbuffered Whether the streams should be unbuffered or buffered
-- @treturn {stream,stream} The piped input and output stream
function buffer.pipedStreams(unbuffered)
	local data = {}
	local closed = false
	local inputStream = {}
	local outputStream = {
		write = function(self, v)
			for _, char in ipairs(string.toCharArray(v)) do
				table.insert(data, 1, char)
			end
		end,
		seek = function() end,
		close = function(self)
			closed = true
			self.closed = true
		end,
		seekable = function()
			return false
		end,
		closed = false
	}
	inputStream = {
		read = function(self, t)
			if not t then t = 1 end
			local str = ""
			for i=1, t do
				if #data == 0 then break end
				local d = table.remove(data)
				str = str .. d
			end
			if str:len() == 0 then
				--while #data == 0 and not closed do
				if #data == 0 and not closed then
					coroutine.yield() -- the program shouldn't have to take in account cooperative multitasking's quirks
					-- the yield is necessary for the process to be able to put in data
				end
				if #data == 0 and closed then
					return nil
				end
			end
			return str
		end,
		remaining = function()
			return #data > 0
		end,
		seek = function() end,
		close = function(self)
			closed = true
			self.closed = true
		end,
		seekable = function()
			return false
		end,
		closed = false
	}
	if not unbuffered then
		inputStream = buffer.from(inputStream)
		outputStream = buffer.from(outputStream)
	end
	return inputStream, outputStream
end

return buffer
