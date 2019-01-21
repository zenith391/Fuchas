-- Shindows Boot Manager

local pc = computer or package.loaded.computer
local cp = component or package.loaded.component
local bootAddr = pc.getBootAddress()
  loadfile = load([[return function(file)
    local pc,cp = computer or package.loaded.computer, component or package.loaded.component
    local addr, invoke = pc.getBootAddress(), cp.invoke
    local handle, reason = invoke(addr, "open", file)
    assert(handle, reason)
    local buffer = ""
    repeat
      local data, reason = invoke(addr, "read", handle, math.huge)
      assert(data or not reason, reason)
      buffer = buffer .. (data or "")
    until not data
    invoke(addr, "close", handle)
    return load(buffer, "=" .. file, "bt", _G)
  end]], "=loadfile", "bt", _G)()
  
if component.type(bootAddr) == "drive" then -- should never happen, unless loaded by a compatible BIOS
	driveRead = function(addr, offset, size)
		-- Optimized drive read method
		local i = offset
		local proxy = component.proxy(addr)
		local out = ""
		if size < proxy.getSectorSize() then
			while i < offset + size do
				out = out .. proxy.readByte(i)
				i = i + 1
			end
		else
			local sects = size % proxy.getSectorSize()
			while i < offset + size do
				out = out .. proxy.readSector(i / proxy.getSectorSize())
				i = i + proxy.getSectorSize()
			end
			while i < offset + size do
				out = out .. proxy.readByte(i)
				i = i + 1
			end
		end
	end
	local bootCode = driveRead(bootAddr, proxy.getCapacity() - 8192, 4096)
else
	loadfile("Fuchas/NT/boot.lua")(loadfile)
end

while true do
  computer.pullSignal()
end
