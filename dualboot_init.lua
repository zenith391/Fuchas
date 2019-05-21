computer.supportsOEFI = function()
	return false
end
local loadfile = load([[return function(file)
	local pc,cp = computer, component
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
local cp = component
if cp.list("gpu")() == nil or cp.list("screen")() == nil then
	error("Graphics Card and Screen required.")
end
local gpua = cp.list("gpu")()
local screena = cp.list("screen")()
local gpu = cp.proxy(gpua)
gpu.bind(screena)
gpu.setResolution(40, 16)
gpu.set(1, 1, "Press 1 for Fuchas")
gpu.set(1, 2, "Press 2 for OpenOS")

while true do
	local id, _, ch = computer.pullEvent()
	if id == "key_down" then
		if ch == '1' then
			_G.loadfile = loadfile
			loadfile("Fuchas/NT/boot.lua")
		elseif ch == '2' then
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