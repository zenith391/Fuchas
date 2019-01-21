local sh = require("shell")
local cui = require("OCX/ConsoleUI")
local run = true
x = 1
y = 1

-- splash
print(string.rep("=-", 15))
print(OSDATA.NAME .. " " .. OSDATA.VERSION)
print("Disk Operation Environment")
print(string.rep("-=", 15))


while run do
	write(">")
	local l = sh.read()
	write(" \n")
	print("execcmd: " .. l)
	if l == "exit" then -- special case: exit cmd
		run = false
	end
end