_G.OSDATA = {
	NAME = "Fuchas",
	VERSION = "0.6.2",
	DEBUG = true,
	CONFIG = {
		NO_52_COMPAT = false, -- mode that disable unsecure Lua 5.2 compatibility like bit32 on Lua 5.3 for security.
		DEFAULT_INTERFACE = "Fushell",
		SAFE_MODE = false -- restrict drivers
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

		if v == "--safe-mode" then
			OSDATA.CONFIG["SAFE_MODE"] = true
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
	--_OSVERSION = _OSVERSION .. " (debug)"
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
		return program(...)
	else
		error(reason)
	end
end

local y = 1
local x = 1

function gy() -- temporary cursor Y accessor
	return y
end

local lastFore = 0
local function write(msg, fore)
	if not screen or not gpu then
		return
	end
	msg = tostring(msg)
	if fore == nil then fore = 0xFFFFFF end
	if gpu and screen then
		if type(fore) == "number" and lastFore ~= fore then
			gpu.setForeground(fore)
			lastFore = fore
		end
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

print("(1/5) Pre-initialization..")
_G.package = dofile("/Fuchas/Libraries/package.lua")
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
	if oefiLib.getImplementationName() == "Zorya BIOS" then
		oefiLib.vendor = zorya
		zorya = nil
	end
	package.loadPreBoot("oefi", oefiLib)
end
print("(3/5) Loading filesystems")
package.loadPreBoot("filesystem", assert(loadfile("/Fuchas/Libraries/filesystem.lua"))())
_G.io = {}
print("(4/5) Mounting A: drive..")
local g, h = require("filesystem").mountDrive(component.proxy(computer.getBootAddress()), "A")
if not g then
	print("Error while mounting A drive: " .. h)
end
package.loadPreBoot("event", assert(loadfile("/Fuchas/Libraries/event.lua"))())
package.loadPreBoot("tasks", assert(loadfile("/Fuchas/Libraries/tasks.lua"))())
package.loadPreBoot("security", assert(loadfile("/Fuchas/Libraries/security.lua"))())

local nextLetter = string.byte('B')
for k, v in component.list() do -- TODO: check if letter is over Z
	if k ~= computer.getBootAddress() and k ~= computer.tmpAddress() then -- drive are initialized later
		if v == "filesystem" then
			if string.char(nextLetter) == "T" then
				print("    Cannot continue mounting! Too much drives")
				break
			end
			print("    Mouting " .. string.char(nextLetter) .. ": drive..")
			require("filesystem").mountDrive(component.proxy(k), string.char(nextLetter))
			nextLetter = nextLetter + 1
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

local function protectEnv()
	local toProtect = {"bit32"} -- "package" is auto-protected inside its code (see package.lua)
	local protected = {}
	for k, v in pairs(toProtect) do
		protected[v] = _ENV[v]
		_ENV[v] = nil
		local childs = {}
		for l, w in pairs(protected[v]) do
			childs[l] = w
			protected[v][l] = nil
		end
		local mt = {
			__metatable = {},
			__index = function(t, key)
				if childs[key] then
					return childs[key]
				end
				return rawget(t, key)
			end,
			__newindex = function(t, key, value)
				if childs[key] then
					error("cannot edit protected entry: " .. k .. "." .. key)
				end
				rawset(t, key, value)
			end
		}
		setmetatable(protected[v], mt)
	end
	local mt = {
		__metatable = {},
		__index = function(t, key)
			if protected[key] then
				return protected[key]
			end
			return rawget(t, key)
		end,
		__newindex = function(t, key, value)
			if protected[key] then
				error("cannot edit protected entry: " .. key)
			end
			rawset(t, key, value)
		end
	}
	setmetatable(_ENV, mt)
end

local ok, err = xpcall(function()
	for k, v in require("filesystem").list("A:/Fuchas/Kernel/Startup/") do
		print("(5/5) Loading " .. k .. "..")
		dofile("A:/Fuchas/Kernel/Startup/" .. k)
	end
	package.endBootPhase()
	protectEnv()
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
		if gpu.setActiveBuffer then
			gpu.setActiveBuffer(0)
		end
		gpu.setForeground(0xFFFFFF)
		gpu.setBackground(0x0000FF)
		gpu.fill(1, 1, 160, 50, " ")
		write([[A problem has been detected and Fuchas
has halted to prevent damage
to your computer.

Error trace:
]] .. err .. " \n \n " .. [[

If this is the first time you've seen
this BSOD, restart your
computer.
 If the problem persists,
ask for help on the OpenComputers forum
(https://oc.cil.li)]])
		local traceback = debug.traceback(nil, 2)
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
