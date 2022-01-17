local driver = require("driver")
local drive = driver.drive
if not drive then return end
local log = require("log")("Disk Buffer " .. drive.address)

while true do
	-- Write a max of 10 sectors at a time, to avoid slowing down
	local wroteSectors = drive.flushBuffer(10)
	if wroteSectors > 0 then
		log.info("Wrote " .. wroteSectors .. " sectors")
		os.sleep(1)
	else
		os.sleep(5)
	end
end
