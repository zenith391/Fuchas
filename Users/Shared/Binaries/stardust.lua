local fs = require("filesystem")
local shell = require("shell")
local sec = require("security")

-- Free some memory
if package.loaded["OCX/OCDraw"] then
	require("OCX/OCDraw").requestMemory()
end

if not sec.requestPermission("component.unrestricted") then
	io.stderr:write("Stardust programs requires unrestricted access to components (admin access).\n")
	return
end

local args, flags = shell.parse(...)

if #args < 1 then
	io.stderr:write("Usage: stardust <path to OpenOS program>\n")
	return
end

local path = shell.resolve(args[1])
if path == nil then
	io.stderr:write(args[1] .. " doesn't exists\n")
	return
end

--[[for k, v in pairs(package.loaded) do
	if k:sub(1, 8) == "stardust" then
		package.loaded[k] = nil
	end
end]]

local libs = {
	component = require("component").unrestricted,
	computer = require("stardust/computer"),
	filesystem = require("stardust/filesystem"), -- no porting necessary.. yet
	colors = require("stardust/colors"),
	unicode = _G.unicode,
	io = require("stardust/io"),
	rc = require("stardust/rc"),
	sides = require("stardust/sides"),
	os = require("stardust/os"),
	term = require("stardust/term"),
	serialization = require("stardust/serialization"),
	text = require("stardust/text"),
	event = require("event"), -- TODO: re-implement
	buffer = require("buffer") -- TODO: re-implement
}

local function req(name)
	if libs[name] then
		return libs[name]
	else
		return require(name)
	end
end

local function loadfile(path)
	local file, reason = require("stardust/filesystem").open(path, "r")
	if not file then
		return nil, reason
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

local function dofile(file, ...)
	local program, reason = loadfile(file)
	if program then
		return program(...)
	else
		error(reason)
	end
end

local env = {
	require = req,
	_OSVERSION = "OpenOS 1.7.5",
	io = require("stardust/io"),
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
	xpcall = _G.xpcall,
	print = _G.print,
	loadfile = loadfile,
	dofile = dofile
}

local handle = io.open(path)
local code = handle:read("a")
handle:close()
local f, err = load(code, args[1], "bt", env)
table.remove(args, 1)

if f then
	xpcall(f, debug.traceback, args)
else
	error(err)
end

-- Cleanup: the OpenOS program might have messed up with GPU which in turns mess up with driver optimizations
component.gpu.setForeground(0xFFFFFF)
component.gpu.setBackground(0)
