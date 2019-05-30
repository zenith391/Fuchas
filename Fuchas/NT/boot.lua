_G.OSDATA = {}
_G.OSDATA.NAME = "Fuchas"
_G.OSDATA.VERSION = "0.3.0"
_G.OSDATA.DEBUG = false

local screen = nil
for address in component.list("screen", true) do
	if #component.invoke(address, "getKeyboards") > 0 then
		screen = address
		break
	end
end
if screen == nil then
	screen = component.list("screen", true)()
end

local gpu = component.list("gpu", true)()
local w, h
if screen and gpu then
	gpu = component.proxy(gpu)
	gpu.bind(screen)
	w, h = gpu.maxResolution()
	gpu.setResolution(w, h)
	gpu.setBackground(0x2D2D2D)
	gpu.setForeground(0xEFEFEF)
	gpu.fill(1, 1, w, h, " ")
end
function dofile(file)
	local program, reason = loadfile(file)
	if program then
		local result = table.pack(pcall(program))
		if result[1] then
			return table.unpack(result, 2, result.n)
		else
			error(result[2])
		end
	else
		error(reason)
	end
end

local y = 1
local x = 1

function gy() -- temporary cursor Y accessor
	return y
end
function write(msg, fore)
	msg = tostring(msg)
	if fore == nil then fore = 0xFFFFFF end
	if gpu and screen then
		if type(fore) == "number" then
			gpu.setForeground(fore)
		end
		if msg:find("\n") then
			for line in msg:gmatch("([^\n]+)") do
				if y == h then
					gpu.copy(1, 2, w, h - 1, 0, -1)
					gpu.fill(1, h, w, 1, " ")
					y = y - 1
				end
				gpu.set(x, y, line)
				x = 1
				y = y + 1
			end
		else
			if y == h then
				gpu.copy(1, 2, w, h - 1, 0, -1)
				gpu.fill(1, h, w, 1, " ")
				y = y - 1
			end
			gpu.set(x, y, msg)
			x = x + msg:len()
		end
	end
end

function print(msg, fore)
	write(msg .. "\n", fore)
end

function os.sleep(n)  -- seconds
  local t0 = computer.uptime()
  while computer.uptime() - t0 <= n do
	coroutine.yield()
  end
end
print("(1/5) Loading 'package' library..")
local package = dofile("/Fuchas/Libraries/package.lua")
_G.package = package
_G.package.loaded.component = component
_G.package.loaded.computer = computer
print("(2/5) Checking OEFI compatibility..")
if computer.supportsOEFI() then
	_G.package.loaded.oefi = ...
end
print("(3/5) Loading 'filesystem' library..")
_G.package.loaded.filesystem = assert(loadfile("/Fuchas/Libraries/filesystem.lua"))()
_G.io = {} -- software-defined by shin32
print("(4/5) Mounting A: filesystem.")
local g, h = require("filesystem").mountDrive(component.proxy(computer.getBootAddress()), "A")
if not g then
	print("Error while mounting A drive: " .. h)
end

print("(4/5) Mounting all drives..")
local letter = string.byte('A')
for k, v in component.list() do -- TODO: check if letter is over Z
	if k ~= computer.getBootAddress() then -- drive are initialized later
		if v == "filesystem" then
			letter = letter + 1
			print("    Mouting " .. string.char(letter) .. " (managed)")
			require("filesystem").mountDrive(component.proxy(k), string.char(letter))
		end
	end
end

_G.loadfile = function(path)
	local file, reason = require("filesystem").open(path, "r")
	if not file then
		if _G.OSDATA.DEBUG then
			error(reason)
		else
			return nil, reason
		end
	end
	local buffer = ""
	local data, reason = "", ""
	while data do
		data, reason = file:read(math.huge)
		buffer = buffer .. (data or "")
	end
	file:close()
	return load(buffer, "=" .. path, "bt", _G)
end

xpcall(function()
	_G.shin32 = require("shin32")
	for k, v in require("filesystem").list("A:/Fuchas/NT/Boot/") do
		print("(5/5) Loading " .. k .. "..")
		dofile("A:/Fuchas/NT/Boot/" .. k)
	end
	dofile("A:/Fuchas/bootmgr.lua")
end, function(err)
		if io.stderr then
			require("shell").setCursor(1, 1)
			require("OCX/ConsoleUI").clear(0x0000FF)
		end
		gpu.setBackground(0x0000FF)
		write("SYSTEM ERROR: " .. err .. "\n")
		local traceback = debug.traceback()
		write(traceback)
		coroutine.yield() -- let the user see the error
end)
coroutine.yield()