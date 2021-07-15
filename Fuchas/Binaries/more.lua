local shell = require("shell")
local driver = require("driver")
local dy = 1
local buf = ""
local rw, rh = driver.gpu.getResolution()

while not io.stdin.closed do
	local b = io.stdin:read("*L")
	if not b then break end
	io.write(b)
	dy = dy + 1
	if dy > rh then
		print("-- More --")
		require("event").pull("key_down")
		shell.setY(shell.getY() - 1)
		shell.clearLine()
		dy = 1
	end
end
