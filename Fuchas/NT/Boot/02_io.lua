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
			--val = val:gsub("\t", "    ")
			return true
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
		gpu.setForeground(0xFF0000)
		io.stdout.write(io.stdout, val)
		gpu.setForeground(0xFFFFFF)
	end
	stream.write = io.stdout.write
	stream.read = io.stdout.read
	stream.close = io.stdout.close
	return stream
end

io.stdout = createStdOut()
io.stderr = createStdErr()
--print("Stdout inited!")

-- Redefine NT's stdio functions
function write(msg)
	io.stdout:write(msg)
end

function print(msg)
	write(msg .. "\n")
end

function io.open(filename, mode)
	if not mode then
		mode = "r"
	end
	if fs.exists(filename) and not fs.isDirectory(filename) then
		local file = {}
		file.h = fs.open(filename, mode)
		file.close = file.h.close
		file.write = file.h.write
		file.read = function(f)
			return coroutine.yield(function(val)
				if not f then
					f = "a"
				end
				
				if f == "a" then
					local s = ""
					while true do
						local r = file.h:read()
						if r == nil then
							break
						end
						s = s .. r
					end
					return false, s
				end
				
				if f == "l" then
					local s = ""
					while true do
						local r = file.h:read()
						if r == nil then
							return false, nil
						elseif r:find("\n") ~= nil or r:find("\r") ~= nil then -- support for unix, mac and windows EOL
							return false,s
						end
						s = s .. r
					end
					return false, s
				end
				return false, nil
			end)
		end
	end
	return nil
end