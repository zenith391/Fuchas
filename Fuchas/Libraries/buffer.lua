-- Library used to buffer I/O streams and for some I/O stream utilities
local buffer = {}

function buffer.pipedStreams(unbuffered)
	local data = {}
	local closed = false
	local inputStream = {}
	local outputStream = {
		write = function(self, v)
			table.insert(data, 1, v)
		end,
		seek = function() end,
		close = function(self)
			closed = true
			self.closed = true
			inputStream.closed = true
		end,
		seekable = function()
			return false
		end
	}
	inputStream = {
		read = function(self, t)
			if not t then t = 1 end
			local str = ""
			for i=1, t do
				local d = table.remove(data)
				if not d then
					break
				end
				str = str .. d
				if #data == 0 then break end
			end
			if str:len() == 0 then
				return nil
			end
			return str
		end,
		seek = function() end,
		close = function(self)
			closed = true
			self.closed = true
			outputStream.closed = true
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

function buffer.from(handle)
	local stream = {}
	stream.stream = handle
	stream.buf = ""
	stream.size = 128
	stream.close = function(self)
		self.stream:close()
		stream.closed = true
	end
	stream.write = function(self, val)
		return self.stream:write(val)
	end
	function stream:fillBuffer()
		if self.buf and self.buf:len() == 0 then
			self.buf = self.stream:read(self.size)
		end
	end
	function stream:readBuffer(len)
		local steps = math.ceil(len/self.size)
		local str = ""
		for i=1, steps do
			self:fillBuffer()
			if self.buf == nil then
				if str:len() > 0 then
					return str
				else
					return nil
				end
			end
			local part = self.buf:sub(1, len%self.size)
			self.buf = self.buf:sub(len%self.size+1, self.buf:len()) -- cut the read part
			str = str .. part
			len = len - len%self.size
		end
		return str
	end
	function stream:read(f)
		if not f then
			f = "a"
		end
		if f == "a" or f == "*a" then -- the * before a or l and others is deprecated in Lua 5.3
			local s = ""
			while true do
				local r = self.stream:read(math.huge)
				coroutine.yield() -- to release the CPU atleast some time
				if r == nil then
					break
				end
				s = s .. r
			end
			return s
		elseif f == "l" or f == "*l" then
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
				if r:find("\n") ~= nil or r:find("\r") ~= nil then -- support for unix, mac and windows EOL
					if r:find("\r") then
						self:read(1) -- skip \n
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
	stream.setvbuf = function(mode, size)
		-- TODO
	end
	stream.lines = function(self, f)
		local tab = {}
		while true do
			local line = self.read(self, "l")
			if line == nil then
				break
			end
			table.insert(tab, line)
		end
		local i = 0
		setmetatable(tab, {
			__call = function()
				i = i + 1
			if i <= n then return tab[i] end
			end
		})
		return tab
	end
	stream.seek = function(self, whence, offset)
		self.buf = ""
		return self.stream:seek(whence, offset)
	end
	return stream
end

return buffer
