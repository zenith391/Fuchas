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

shin32.setSystemVar("PWD", "")
local drive = "A"
while run do
	write(">")
	local l = sh.read()
	write(" \n")
	if l == "exit" then -- special case: exit cmd
		run = false
	end
	if l == "drv" then
		print("Drive: " .. drive .. ", pwd = " .. shin32.getSystemVar("PWD"))
	end
	if l:len() == 2 then
		drive = l:sub(1, 1)
	end
	local path = drive .. ":/" .. shin32.getSystemVar("PWD") .. l
	local exists = false
	local tpath = path
	local exts = string.split(shin32.getSystemVar("PATHEXT"), ";")
	local tpi = 1
	while not fs.exists(tpath) do
		if tpi > table.getn(exts) then
			break
		end
		tpath = path .. exts[tpi]
		if fs.exists(tpath) then
			exists = true
		end
		tpi = tpi + 1
	end
	if exists then
		local f, err = xpcall(function()
			local l, err = loadfile(tpath)
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