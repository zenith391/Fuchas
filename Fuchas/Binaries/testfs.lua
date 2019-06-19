local _, nitro = dofile("A:/Fuchas/Filesystems/nitrofs.lua")
local addr = "be4799dd-48f9-461c-bd83-d582c50b9705"

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