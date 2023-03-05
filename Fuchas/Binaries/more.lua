local shell = require("shell")
local dy = 1
local buf = ""

if not shell.getHeight() then
	io.stderr:write("output is not a terminal\n")
	return
end
local rh = shell.getHeight()

while not io.stdin.closed do
	local b = io.stdin:read("*L")
	if not b then break end
	io.write(b)
	dy = dy + 1
	if dy > rh - 3 then
		print("-- More --")
		require("event").pull("key_down")
		shell.setY(shell.getY() - 1)
		shell.clearLine()
		dy = 1
	end
end
