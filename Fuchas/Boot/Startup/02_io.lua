local fs = require("filesystem")
local comp = require("component")

local function createStdOut()
	local stream = {}
	local sh = require("shell")
	local gpu = comp.proxy(comp.list("gpu")())
	local w, h = gpu.getViewport()
	stream.close = function(self)
		return false -- unclosable stream
	end
	stream.write = function(self, val)
		if val:find("\t") then
			val = val:gsub("\t", "    ")
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
			sh.setX(sh.getX() + val:len())
		end
		return true
	end
	stream.read = function(self, len)
		return nil -- cannot read stdOUT
	end
	return stream
end

local function createStdErr()
	local stream = {}
	stream.write = function(self, val)
		local fg = component.gpu.getForeground()
		component.gpu.setForeground(0xFF0000)
		local b = io.stdout:write(val)
		component.gpu.setForeground(fg)
		return b
	end
	--stream.write = io.stdout.write
	stream.read = io.stdout.read
	stream.close = io.stdout.close
	return stream
end

io.stdout = createStdOut()
io.stderr = createStdErr()

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
		local file = {}
		local h, err = fs.open(filename, mode)
		if not h then
			return nil, err
		else
			file.h = h
		end
		file.close = function(self)
			self.h.close(self.h)
		end
		file.write = function (self, val)
			return self.h.write(self.h, val)
		end
		file.read = function(self, f)
			--return coroutine.yield(function(val) -- task for later
				if not f then
					f = "a"
				end
				
				if f == "a" or f == "*a" then -- the * before a or l and others is deprecated in Lua 5.3
					local s = ""
					while true do
						local r = file.h:read(math.huge)
						if r == nil then
							break
						end
						s = s .. r
					end
					return s
				end
				
				if f == "l" or f == "*l" then
					local s = ""
					while true do
						local r = file.h:read(1)
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
				end
				return nil, "invalid mode"
			--end)
		end
		file.lines = function(self, f)
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
		return file
	end
	return nil
end