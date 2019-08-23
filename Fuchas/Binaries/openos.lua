-- The purpose of this program is NOT isolating programs from the computer.
-- Use a Virtual Machine for this.
-- Its purpose is to run OpenOS on Fuchas so we can use it to run OpenOS program.
-- A soon to come option would be to directly emulate OpenOS APIs

local shell = require("shell")
local filesystem = require("filesystem")
local sec = require("security")

local args, ops = shell.parse(...)

if #args < 1 then
	io.stderr:write("Usage: openos <path to OpenOS installation/floppy>\n")
	return
end

local path = shell.resolve(args[1])

if path == nil then
	io.stderr:write(args[1] .. " doesn't exists\n")
	return
end

local function verifyInstallation(path)
	if filesystem.exists(path .. "/boot") and filesystem.exists(path .. "/init.lua") then
		return true
	end
	return true
end

if not verifyInstallation(path) then
	io.stderr:write("Invalid OpenOS installation!\n")
	return
end

print("Valid OpenOS installation")
print("Setting up virtual environment, expect high memory usage")

local bootAddress = "5c6c151a-59af-4a0b-be4f-1d639c2b9014"

local function computerAPI()
	local comp = computer
	comp.getBootAddress = function()
		return bootAddress
	end
	return comp
end

local function setupEnvironment()
	local env = {
		computer = computerAPI(),
		component = _G.component,
		math = _G.math,
		coroutine = _G.coroutine,
		bit32 = _G.bit32,
		string = _G.string,
		table = _G.table,
		unicode = _G.unicode,
		debug = _G.debug,
		io = {},

		assert = _G.assert,
		error = _G.error,
		getmetatable = _G.getmetatable,
		ipairs = _G.ipairs,
		load = _G.load,
		next = _G.next,
		pairs = _G.pairs,
		pcall = _G.pcall,
		rawequal = _G.rawequal,
		rawget = _G.rawget,
		rawlen = _G.rawlen,
		rawset = _G.rawset,
		select = _G.select,
		setmetatable = _G.setmetatable,
		tonumber = _G.tonumber,
		tostring = _G.tostring,
		type = _G.type,
		xpcall = _G.xpcall
	}
	return env
end

local function startMachine(env)
	print("Loading init.lua..")
	local initFile = io.open(path .. "/init.lua")
	local init = initFile:read("a")
	initFile:close()

	print("Loading function..")
	env.oldg = _G
	_G = env
	_ENV._OSVERSION = "Fuchas OpenOS"
	local start = load(init, "openos_init", "bt", _G)
	--local start = load(init)
	print("Starting")
	xpcall(start, function(err)
		io.stderr:write("Error with OpenOS: " .. err .. "\n")
		io.stderr:write(debug.traceback())

		print(_G._OSVERSION)
	end)
	_G = env.oldg
end

local env = setupEnvironment()

print("Current process: " .. shin32.getCurrentProcess().pid)
print("Current coroutine: " .. tostring(coroutine.running()))
print("Exiting coroutine..") -- used to avoid OpenOS finding itself in a coroutine that isn't an OpenOS process
-- also make longer stacktraces (due to having all of it since computer start)
local ret = coroutine.yield(function()
	print("Current process: " .. ifOr(shin32.getCurrentProcess() ~= nil, shin32.getCurrentProcess().pid, "none"))
	print("Current coroutine: " .. tostring(coroutine.running()))
	startMachine(env)
	return false, "ok"
end)

print("Returned " .. ret)