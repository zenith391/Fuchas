-- Library used to buffer I/O streams 
local lib = {}

function lib.from(handle)
	local stream = {}
	stream.stream = handle
	stream.buf = ""
	stream.size = 128
	stream.close = function(self)
		self.stream:close()
	end
	stream.write = function (self, val)
		return self.stream:write(val)
	end
	stream.fillBuffer = function(self)
		if self.buf:len() == 0 then
			self.buf = self.stream:read(self.size)
		end
	end
	stream.readBuffer = function(self, len)
		local steps = len/self.size
		local str = ""
		for i=1, steps do
			self.fillBuffer()
			local part = self.buf:sub(1, len%self.size)
			self.buf = self.buf:sub(len+1, self.buf:len()) -- cut the readed part
			str = str .. part
			len = len - len%self.size
		end
		return str
	end
	stream.read = function(self, f)
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
				local r = self.stream:read(1)
				if r == nil then
					if s == "" then
						return nil
					else
						break
					end
				end
				if r:find("\n") ~= nil or r:find("\r") ~= nil then -- support for unix, mac and windows EOL
					return s
				end
				s = s .. r
			end
			return s
		elseif type(f) == "number" then
			self.fillBuffer()
			local out = ""
			if f > self.size then

			else

			end
		end
		return nil, "invalid mode"
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
	return stream
end

return lib
