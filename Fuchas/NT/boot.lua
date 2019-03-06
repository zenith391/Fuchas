_G.OSDATA = {}
_G.OSDATA.NAME = "Fuchas"
_G.OSDATA.VERSION = "ALPHA 0.2"
if _VERSION == "Lua 5.3" then -- lua 5.3 haves higher number precision
	_G.OSDATA.ARCH = "x86_64"
else
	_G.OSDATA.ARCH = "x86"
end

local screen = nil
for address in component.list("screen", true) do
	if #component.invoke(address, "getKeyboards") > 0 then
		screen = address
		break
	end
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

y = 1
x = 1
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

local c = coroutine.create(function()
	print("Loading packages..")
	local package = dofile("/Fuchas/Libraries/package.lua")
	_G.package = package
	_G.package.loaded.component = component
	_G.package.loaded.computer = computer
	_G.package.loaded.filesystem = assert(loadfile("/Fuchas/Libraries/filesystem.lua"))()
	_G.io = {} -- software-defined by shin32
	print("Done!")
	--require("filesystem").mount(computer.getBootAddress(), "/")    -- TODO: Remove
	local g, h = require("filesystem").mountDrive(computer.getBootAddress(), "A")
	if not g then
		print("error: " .. h)
	end
	print(OSDATA.NAME .. " " .. OSDATA.VERSION .. " running on " .. _VERSION)
	print(math.ceil(computer.freeMemory() / 1024) .. "KiB FREE")
	print("OS Architecture: " .. OSDATA.ARCH)
	print("Made by zenith391 (Zen1th on OC forum)")
	print("Credits:")
	print("3D powered by OCGL made by MineOS") -- not yet implemented
	print("2D (GUI + Console) powered by OCX.")
	print("GERT api layer 2, 3, 4 and 5 made by GlobalEmpire")	-- not yet implemented
	os.sleep(0.25)
	
	-- loadfile
	_G.loadfile = function(path)
		local file, reason = require("filesystem").open(path, "r")
		if not file then
			error(reason)
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
	
	local f, err = xpcall(function()
		-- number in names is for execution order
		print("Loading shin32..")
		_G.shin32 = require("shin32")
		for k, v in require("filesystem").list("A:/Fuchas/NT/Boot/") do
			print("Loading " .. k .. "..")
			dofile("A:/Fuchas/NT/Boot/" .. k)
		end
		dofile("A:/Fuchas/load.lua")
	end, function(err)
			gpu.setBackground(0x4444DD)
			print("Error while loading: " .. err, 0x00FF00)
			print(debug.traceback(), 0x00FF00)
	end)
	if err ~= nil then
		gpu.setBackground(0x4444DD)
		--gpu.setForeground(0x00FF00)
		--gpu.fill(1, 1, w, h, " ")
		y = 20
		print("Error while loading:", 0x00FF00)
		print(err, 0x00FF00)
	end
end)
while true do
	coroutine.resume(c)
	coroutine.yield(1)
end