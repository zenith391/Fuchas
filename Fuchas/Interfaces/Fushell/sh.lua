-- Avoid killing (safely) system process with a custom quit handler
shin32.getCurrentProcess().safeKillHandler = function()
	io.stderr:write("cannot kill system process!\n")
	return false
end

shin32.getCurrentProcess().childErrorHandler = function(proc, err)
	io.stderr:write(err .. "\n")
end

local sh = require("shell")
local cui = require("OCX/ConsoleUI")
local fs = require("filesystem")
local run = true
sh.clear()
-- splash
print(string.rep("=-", 15))
print(OSDATA.NAME .. " " .. OSDATA.VERSION .. " - Fushell")
print("I'm sure you'll only use it")
print("when Concert doesn't work!")
print(string.rep("-=", 15))

shin32.setSystemVar("PWD", "")
local drive = "A"
while run do
	shin32.setSystemVar("PWD_DRIVE", drive)
	write(drive .. ":/" .. shin32.getSystemVar("PWD") .. ">")
	local l = sh.read()
	local args = sh.parseCL(l)
	write(" \n")
	if #args == 0 then
		args[1] = ""
	end
	if args[1] == "exit" then -- special case: exit cmd
		run = false
	end
	if args[1] == "pwd" then
		print("Drive: " .. drive .. ", pwd = " .. shin32.getSystemVar("PWD"))
	end
	if args[1]:len() == 2 then
		if args[1]:sub(2, 2) == ":" then
			drive = args[1]:sub(1, 1)
		end
	end
	local path = args[1]
	local exists = false
	local tpath = path
	local pathv = string.split(shin32.getSystemVar("PATH"), ";")
	table.insert(pathv, shin32.getSystemVar("PWD"))
	local exts = string.split(shin32.getSystemVar("PATHEXT"), ";")
	table.insert(exts, "")
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
	if exists and args[1] ~= "" then
		local f, err = xpcall(function()
			local programArgs = {}
			if #args > 1 then
				for k, v in pairs(args) do
					if k > 1 then
						table.insert(programArgs, v)
					end
				end
			end
			local f, err = loadfile(tpath)
			if f == nil then
				print(err)
			end

			local proc = shin32.newProcess("shell child program", function()
				f(programArgs)
			end)
			shin32.waitFor(proc)
		end, function(err)
			print(debug.traceback(err))
		end)
	else
		print("file " .. args[1] .. " does not exists")
	end
end
