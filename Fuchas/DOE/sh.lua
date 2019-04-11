local sh = require("shell")
local cui = require("OCX/ConsoleUI")
local fs = require("filesystem")
local run = true
sh.clear()
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
	if l == "pwd" then
		print("Drive: " .. drive .. ", pwd = " .. shin32.getSystemVar("PWD"))
	end
	if l:len() == 2 then
		if l:sub(2, 2) == ":" then
			drive = l:sub(1, 1)
		end
	end
	local path = shin32.getSystemVar("PWD") .. l
	local exists = false
	local tpath = path
	local pathv = string.split(shin32.getSystemVar("PATH"), ";")
	local exts = string.split(shin32.getSystemVar("PATHEXT"), ";")
	local tpi = 1
	while not fs.exists(tpath) do
		if tpi > table.getn(exts) then
			break
		end
		local org = tpath
		for i, sp in pairs(pathv) do
			tpath = sp .. path .. exts[tpi]
			if fs.exists(tpath) then
				exists = true
			end
			if not exists then
				tpath = org
			else
				break
			end
		end
		if not exists then
			tpath = drive .. ":/" .. org .. exts[tpi]
			exists = fs.exists(tpath)
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