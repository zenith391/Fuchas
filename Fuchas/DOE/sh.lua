local sh = require("shell")
local cui = require("OCX/ConsoleUI")
local fs = require("filesystem")
local run = true
x = 1
y = 1

-- splash
print(string.rep("=-", 15))
print(OSDATA.NAME .. " " .. OSDATA.VERSION)
print("Disk Operation Environment")
print(string.rep("-=", 15))

shin32.getSystemVars()["PWD"] = "A:/"
while run do
	write(">")
	local l = sh.read()
	write(" \n")
	if l == "exit" then -- special case: exit cmd
		run = false
	end
	if fs.exists(shin32.getSystemVar("PWD") .. l) then
		local f, err = xpcall(function()
			local l, err = loadfile(l)
			if l == nil then
				print(err)
			end
			return l()
		end, function(err)
			print(err)
			print(debug.traceback(" ", 1))
		end)
	else
		print("file " .. l .. " does not exists")
	end
end