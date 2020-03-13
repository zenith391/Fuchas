-- Library used to buffer I/O streams 
local lib = {}

function lib.from(handle)
	local stream = {}
	stream.stream = handle
	stream.close = function(self)
		self.stream:close()
	end
	stream.write = function (self, val)
		return self.stream.write(self.h, val)
	end
	stream.read = function(self, f)
		if not f then
			f = "a"
		end
		if f == "a" or f == "*a" then -- the * before a or l and others is deprecated in Lua 5.3
			local s = ""
			repeat
				local r = self.stream:read(math.huge)
				coroutine.yield() -- to release the CPU atleast some time
				s = s .. (r or "")
			until not r
			return s
		end
		
		if f == "l" or f == "*l" then
			local s = ""
			repeat
				local r = (self.stream:read(1) or "")
				if r:find("\n") ~= nil or r:find("\r") ~= nil then -- support for unix, mac and windows EOL
					return s
				end
				s = s .. r
			until not r
			return (s == "" and nil) or s
		end
		return nil, "invalid mode"
	end
	stream.lines = function(self, f)
		local tab = {}
		repeat
			local line = self.read(self, "l")
			if line then
				table.insert(tab, line)
			end
		until not line
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
