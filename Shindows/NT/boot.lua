_G.OSDATA = {}
_G.OSDATA.NAME = "Shindows"
_G.OSDATA.VERSION = "1.01"
if _VERSION == "Lua 5.3" then
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
	gpu.setBackground(0x4444DD)
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
function print(msg)
	local x = 1
  if gpu and screen then
  		for i = 1, #msg do
  			local c = msg:sub(i,i)
		    if y == h then
		      gpu.copy(1, 2, w, h - 1, 0, -1)
		      gpu.fill(1, h, w, 1, " ")
	    	else
	      	if c == '\n' then
	      		y = y + 1
	      		x = 1
	      	else
	      		gpu.set(x, y, c)
	      		x = x + 1
	      	end
	    	end
	    end
	    y = y + 1
  end
end

function os.sleep(n)  -- seconds
  local t0 = computer.uptime()
  while computer.uptime() - t0 <= n do
	coroutine.yield()
  end
end

print("Loading packages..")
local package = dofile("/Shindows/Libraries/package.lua")
_G.package = package
_G.package.loaded.component = component
_G.package.loaded.computer = computer
_G.package.loaded.filesystem = assert(loadfile("/Shindows/Libraries/filesystem.lua"))()
_G.package.loaded.io = io
_G.io = {}
print("Done!")
print("Mounting filesytem..")
require("filesystem").mount(computer.getBootAddress(), "/")
require("filesystem").mount(computer.getBootAddress(), "/drv/c")
print("Done!")
print(OSDATA.NAME .. " " .. OSDATA.VERSION .. " running on " .. _VERSION)
print((computer.totalMemory() / 1024) .. "K RAM SYSTEM " .. math.ceil(computer.freeMemory() / 1024) .. "K FREE")
print("OS Architecture: " .. OSDATA.ARCH)
y = 45
print("Made by zenith391")
print("Credits:")
print("3D powered by OCGL made by MineOS team") -- not yet implemented
print("2D (GUI + Console) powered by OCX made by me.")
print("Universal Networking (unet) made by \"LetDevDev\"")                        -- not yet implemented
os.sleep(1)
local f, err = pcall(function()
	dofile("/Shindows/NT/Boot/component.lua")
	dofile("/Shindows/load.lua")
end)
if err ~= nil then
	--gpu.setBackground(0x4444DD)
	gpu.setForeground(0x00FF00)
	gpu.setBackground(0xFFFFFF)
	gpu.fill(1, 1, w, h, " ")
	y = 1
	print("Error while loading:")
	print(err)
end