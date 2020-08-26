local shell = require("shell")
local driver = require("driver")
local dy = 0
local buf = ""
local rw, rh = driver.gpu.getResolution()

while not io.stdin.closed do
	local b = io.stdin:read(math.huge)
	if b then
		buf = buf .. b
	end
	while buf:find("\n") do
		local idx = buf:find("\n")
		local line = buf:sub(1, idx)
		io.write(line)
		buf = buf:sub(idx+1)
		dy = dy + 1
		if dy > rh then
			print("-- More --")
			require("event").pull("key_down")
			shell.setY(shell.getY()-1)
			shell.clearLine()
			dy = 0
		end
	end
end
