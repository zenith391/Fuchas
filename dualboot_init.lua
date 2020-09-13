local cp = component or package.loaded.component
local pc = computer or package.loaded.computer

pc.supportsOEFI = function()
	return false
end

local loadfile = load([[return function(file)
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

if component.list("gpu")() == nil or component.list("screen")() == nil then
	error("gpu and screen required")
end

if not cp.invoke(computer.getBootAddress(), "exists", "/lib/core/") then -- OpenOS doesn't exists, so always boot Fuchas
	_G.loadfile = loadfile
	loadfile("Fuchas/Kernel/boot.lua")()
	return
end

local gpua = cp.list("gpu")()
local screena = cp.list("screen")()
local gpu = cp.proxy(gpua)
gpu.bind(screena)
gpu.setResolution(22, 2)
gpu.setBackground(0x000000)
gpu.fill(1, 1, 22, 2, ' ')
gpu.set(1, 1, "Press ENTER for Fuchas")
gpu.set(1, 2, "Press O     for OpenOS")

while true do
	local id, _, _, ch = computer.pullSignal()
	if id == "key_down" then
		if ch == 28 then
			_G.loadfile = loadfile
			loadfile("Fuchas/Kernel/boot.lua")()
			break
		elseif ch == 24 then
			loadfile("/lib/core/boot.lua")(loadfile)
			-- OpenOS's shell behavior
			while true do
				local result, reason = xpcall(require("shell").getShell(), function(msg)
					return tostring(msg).."\n"..debug.traceback()
				end)
				if not result then
					io.stderr:write((reason ~= nil and tostring(reason) or "unknown error") .. "\n")
					io.write("Press any key to continue.\n")
					os.sleep(0.5)
					require("event").pull("key")
				end
			end
		end
	end
end