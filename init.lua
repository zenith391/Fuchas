-- Fuchas Boot Manager
computer.supportsOEFI = function()
	return false
end
loadfile = load([[return function(file)
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
loadfile("Fuchas/Boot/boot.lua")()