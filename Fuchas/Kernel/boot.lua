_G.OSDATA = {
	NAME = "Fuchas",
	VERSION = "0.6.0",
	DEBUG = false,
	CONFIG = {
		NO_52_COMPAT = false, -- mode that disable unsecure Lua 5.2 compatibility like bit32 on Lua 5.3 for security.
		DEFAULT_INTERFACE = "Fushell"
	}
}

if os_arguments then -- arguments passed by a boot loader
	-- Max security arguments: --no-debug --no-lua52-compat
	for k, v in pairs(os_arguments) do
		if v == "--no-lua52-compat" then
			if _VERSION == "Lua 5.2" then
				error("Cannot set '--no-lua52-compat' on a Lua 5.2 computer")
			end
			OSDATA.CONFIG["NO_52_COMPAT"] = true
		end
		
		if v == "--no-debug" then
			OSDATA.DEBUG = false
		end

		if v == "--debug" then
			OSDATA.DEBUG = true
		end

		if v == "--boot-address" then
			local bootAddr = os_arguments[k+1]
			if not bootAddr then
				error("missing argument to '--boot-address'")
			end
			if computer.supportsOEFI() then
				local oefiLib = oefi or ...
				if oefiLib.getAPIVersion() > 1 and oefiLib.getBootAddress then
					oefiLib.getBootAddress = function()
						return bootAddr
					end
					oefi = oefiLib
				end
			end
			computer.getBootAddress = function()
				return bootAddr
			end
		end

		if v == "--interface" then
			local itf = os_arguments[k+1]
			if not itf then
				error("missing argument to '--interface'")
			end
			OSDATA.CONFIG.DEFAULT_INTERFACE = itf
		end
	end
	os_arguments = nil
end

_G._OSVERSION = _G.OSDATA.NAME .. " " .. _G.OSDATA.VERSION
if OSDATA.DEBUG then
	_OSVERSION = _OSVERSION .. " (debug)"
end

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
	gpu.setBackground(0x000000)
	gpu.setForeground(0xFFFFFF)
	gpu.fill(1, 1, w, h, " ")
end

function dofile(file, ...)
	local program, reason = loadfile(file)
	if program then
		if OSDATA.DEBUG then
			return program(...)
		end
		local result = table.pack(pcall(program, ...))
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
local function write(msg, fore)
	if not screen or not gpu then
		return
	end
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
_G.write = write

function print(msg, fore)
	write(tostring(msg) .. "\n", fore)
end

function os.sleep(n)
	local t0 = computer.uptime()
	while computer.uptime() - t0 <= n do
		coroutine.yield()
	end
end

print("(1/5) Loading 'package' library..")
_G.package = dofile("/Fuchas/Libraries/package.lua")
_G.package.loaded.component = component
_G.package.loaded.computer = computer
print("(2/5) Checking OEFI compatibility..")
if computer.supportsOEFI() then
	local oefiLib = oefi or ...
	if oefiLib.getAPIVersion() > 1 and oefiLib.getBootAddress then
		oefi = nil
		function computer.getBootAddress()
			return oefiLib.getBootAddress()
		end
	end
	if not oefiLib.vendor then
		oefiLib.vendor = {}
	end
	package.loaded.oefi = oefiLib
	if oefiLib.getImplementationName() == "Zorya BIOS" then
		package.loaded.oefi.vendor = zorya
		zorya = nil
	end
end
print("(3/5) Loading filesystems")
_G.package.loaded.filesystem = assert(loadfile("/Fuchas/Libraries/filesystem.lua"))()
_G.io = {} -- software-defined by shin32
print("(4/5) Mounting A: drive..")
local g, h = require("filesystem").mountDrive(component.proxy(computer.getBootAddress()), "A")
if not g then
	print("Error while mounting A drive: " .. h)
end
_G.package.loaded.event = assert(loadfile("/Fuchas/Libraries/event.lua"))()
_G.package.loaded.tasks = assert(loadfile("/Fuchas/Libraries/tasks.lua"))()
_G.package.loaded.security = assert(loadfile("/Fuchas/Libraries/security.lua"))()

print("(4/5) Mounting all drives..")
local letter = string.byte('A')
for k, v in component.list() do -- TODO: check if letter is over Z
	if k ~= computer.getBootAddress() and k ~= computer.tmpAddress() then -- drive are initialized later
		if v == "filesystem" then
			letter = letter + 1
			print("    Mouting " .. string.char(letter) .. " (managed)")
			if string.char(letter) == "T" then
				print("    Cannot continue mounting! Too much drives")
				break
			end
			require("filesystem").mountDrive(component.proxy(k), string.char(letter))
		end
	end
end

print("(4/5) Mounting T: drive..")
require("filesystem").mountDrive(component.proxy(computer.tmpAddress()), "T")

loadfile = function(path)
	local file, reason = require("filesystem").open(path, "r")
	if not file then
		if OSDATA.DEBUG then
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

local ok, err = xpcall(function()
	for k, v in require("filesystem").list("A:/Fuchas/Kernel/Startup/") do
		print("(5/5) Loading " .. k .. "..")
		dofile("A:/Fuchas/Kernel/Startup/" .. k)
	end
	dofile("A:/Fuchas/bootmgr.lua")
end, function(err)
		local computer = (computer or package.loaded.computer)
		if io and package and package.loaded and package.loaded.shell and false then
			pcall(function()
				require("shell").setCursor(1, 1)
			end) -- in case shell is the erroring library
		else
			x = 1
			y = 1
		end
		gpu.setBackground(0x0000FF)
		gpu.fill(1, 1, 160, 50, " ")
		write([[A problem has been detected and Fuchas
has shutdown to prevent damage
to your computer.

]] .. err .. " \n \n " .. [[
If this is the first time you've seen
this BSOD screen, restart your
computer.
 If the problem persists,
ask for help on the OC forum
(https://oc.cil.li), search for
Fuchas topic and speak about your
computer problem as a reply.]])
		local traceback = debug.traceback()
		write(traceback)
		if io then
			pcall(function()
				y = require("shell").getY()
			end)
		end
		return traceback
end)

local computer = (computer or package.loaded.computer)
local t0 = computer.uptime() + 30
--gpu.set(1, y+3, "Error: " .. err)
gpu.set(1, y+4, "Press any key to reboot now.")
while computer.uptime() <= t0 do
	gpu.fill(1, y+2, 160, 1, " ")
	gpu.set(1, y+2, "Auto-reboot in " .. math.ceil(t0 - computer.uptime()))
	if computer.pullSignal(1) == "key_down" then
		break
	end
end

computer.shutdown(true)
