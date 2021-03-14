local tasks = require("tasks")
local proc  = tasks.getCurrentProcess()
proc.watchedEvents.file.open = {"*"} -- watch for any opened file

while true do
	print("test service")
	os.sleep(3)
end
