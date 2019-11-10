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
	local comp = _G.computer
	comp.getBootAddress = function()
		return bootAddress
	end
	return comp
end

local function setupEnvironment()
	local env = {
		computer = computerAPI(),
		component = _G.component.unrestricted,
		math = _G.math,
		coroutine = _G.coroutine,
		bit32 = _G.bit32,
		string = _G.string,
		table = _G.table,
		unicode = _G.unicode,
		debug = _G.debug,

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
	if _VERSION == "Lua 5.3" then
		env.utf8 = _G.utf8
	end
	return env
end

local function startMachine(env)
	print("Loading init.lua..")
	local initFile = io.open(path .. "/init.lua")
	local init = initFile:read("a")
	initFile:close()

	print("Loading function")
	local start = load(init, "openos_init", "bt", env)
	print("Starting..")
	--xpcall(start, function(err)
	--	io.stderr:write("Error with OpenOS: " .. err .. "\n")
	--	io.stderr:write(debug.traceback())
	--end)
	start()
end

print("Process: " .. shin32.getCurrentProcess().pid)
print("Process coroutine: " .. tostring(coroutine.running()))
print("Exiting coroutine..") -- used to avoid OpenOS finding itself in a coroutine that isn't an OpenOS process
-- also make longer stacktraces (due to having all of it since computer start)
local ret = nil
local ret = coroutine.yield(function()
	print("Main coroutine: " .. tostring(coroutine.running()))
	os.sleep(1)
	local env = setupEnvironment()
	local ok, err = xpcall(startMachine, function(err)
		print(err)
		print(debug.traceback())
		return err
	end, env)
	print(err)
	while true do
		require("event").pull()
	end
	return false, "ok"
end)

if ret ~= "ok" then
	print("Execution failed: " .. ret)
else
	print("Execution finished")
end