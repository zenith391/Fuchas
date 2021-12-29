-- TODO: ability to select driver
local drive = require("driver").drive
local written = drive.flushBuffer()
if written > 0 then
	print("Wrote " .. written .. " sectors.")
else
	print("No sector to write.")
end
