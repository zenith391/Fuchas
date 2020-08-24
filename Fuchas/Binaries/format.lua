local shell = require("shell")
local fs = require("filesystem")
local part = require("partition")

local args, options = shell.parse(...)

if not options.p then
	print("format [-e] <-p=openupt|osdi> [drive]:")
	print("  -e: Erase all the drive")
	print("  -p=...: Can be 'osdi' for OSDI partition table or 'openupt' for OpenUPT partition table or 'none' for no partition table (not recommended)")
	return
end

local drive = require("driver").drive

if options.e then
	print("Full formatting...")
	local dots = 0
	for i=0, drive.getCapacity()/512-512 do
		if dots > 20 then
			dots = 0
		end
		shell.clear()
		print("Full formatting" .. ("."):rep(dots))
		print("(this might take around 20 minutes)")
		dots = dots + 1
		print(math.floor(i/(drive.getCapacity()/512-512)*100) .. "%")
		drive.writeBytes((i==0 and 1) or i*512, ("\x00"):rep(512))
	end
	print("Done.")
end

if options.p == "osdi" then
	io.stderr:write("OSDI partition table is not yet supported.\n")
	return
elseif options.p == "openupt" then
	print("Formatting..")
	part.openupt1().format(drive, function(str)
		print(str)
	end)
elseif options.p == "none" then
	print("Formatting..")
	drive.writeBytes(1, ("\x00"):rep(512))
	print("Done.")
else
	io.stderr:write("Invalid partition table type: " .. tostring(options.p))
	return
end
