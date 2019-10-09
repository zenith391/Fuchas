local _, nitro = dofile("A:/Fuchas/Filesystems/nitrofs.lua")
local addr = "cd1e106a-8a84-4004-883c-4b993203fab7"

xpcall(function()
	print("Formatting..")
	nitro.format(addr)
	print("Done!")
	nitro.makeDirectory(addr, "bin")
	nitro.makeDirectory(addr, "lib")
	nitro.makeDirectory(addr, "lib/ntrfs")
end, function(err)
	print(err)
	print(debug.traceback())
end)