local shell = require("shell")
local fs = require("filesystem")
package.loaded.partition = nil
local part = require("partition")

local args, options = shell.parse(...)

if not options.parttab and not options.fs then
	print("format [-e] <--parttab=openupt|osdi> [drive]:")
	print("  -e: Erase all the drive")
	print("  --parttab=...: Can be 'osdi' for OSDI partition table or 'openupt' for OpenUPT partition table or 'none' for no partition table (not recommended)")
	print("  --fs=...: Can be 'nitrofs+'")
	return
end

local drive = require("driver").drive
if options.e then
	print("Full formatting...\n0%")
	local dots = 0
	local oldpercent = 0
	for i=0, drive.getCapacity()/512-512 do
		if dots > 20 then
			dots = 0
			require("event").pull(0)
		end
		dots = dots + 1
		drive.writeBytes((i==0 and 1) or i*512, ("\x00"):rep(512))
		if dots % 5 == 0 then io.stdout:write(".") end
		local percent = math.floor(i/(drive.getCapacity()/512-512)*100)
		if percent ~= oldpercent then
			io.stdout:write("\n" .. percent .. "%")
			oldpercent = percent
		end
	end
	print("Done.")
end

if options.parttab == "osdi" then
	io.stderr:write("OSDI partition table is not yet supported.\n")
	return
elseif options.parttab == "openupt" then
	print("Formatting..")
	part.openupt1().format(drive, function(str)
		print(str)
	end)
elseif options.parttab == "none" then
	print("Formatting..")
	drive.writeBytes(1, ("\x00"):rep(512))
	print("Done.")
elseif options.parttab then
	io.stderr:write("Invalid partition table type: " .. tostring(options.parttab))
	return
end

if options.fs == "nitrofs+" then
	local pt = part.openupt1().newPartition(0, 33, math.floor(drive.getCapacity() / 512))
	pt.type = "NitroFS+"
	pt.label = "Root Partition"
	part.openupt1().writePartition(drive, pt)
	print("Partition written and filesystem formatted")

	local ptlist = part.openupt1().readPartitionList(drive)
	local ptDriver = part.openupt1().partitionDriver(drive, pt)
	local nfs = loadfile("A:/Fuchas/Filesystems/nitrofs+.lua")(ptDriver, pt.guid) -- TODO: expand GUID to give an UUID
	nfs.format()

	local driveLetter = fs.freeDriveLetter()
	print("The shell has " .. driveLetter .. ": mounted for NitroFS filesystem")
	os.setenv("PWD", driveLetter .. ":/")
	fs.mountDrive(nfs.asFilesystem(), driveLetter)
	dofile("A:/Fuchas/Interfaces/Fushell/main.lua")
	fs.unmountDrive(driveLetter)
else
	io.stderr:write("Invalid filesystem type: " .. tostring(options.fs))
	return
end