local sh = require("shell")
local fs = require("filesystem")
local tasks = require("tasks")
local driver = require("driver")

local date = os.date

tasks.getCurrentProcess().childErrorHandler = function(proc, err)
	io.stderr:write(tostring(err) .. "\n")
end

tasks.getCurrentProcess().permissionGrant = function(perm, pid)
	local l = nil
	while l ~= "N" and l ~= "Y" do
		io.stdout:write("Grant permission \"" .. perm .. "\" to process? (Y/N) ")
		l = sh.read():upper()
		io.stdout:write(" \n")
	end
	if l == "Y" then
		return true
	else
		return false
	end
end

local rw, rh = driver.gpu.getResolution()

local function printCentered(str)
	write(string.rep(" ", math.floor(rw/2-str:len()/2)))
	print(str)
end

sh.clear()

print(string.rep("=-", math.floor(rw/2)))
printCentered("Kabam Beta interface on " .. _OSVERSION)
printCentered("It is " .. date("%H:%M, the %d %b %Y"))
printCentered("Type \"help\" if you don't know what to do!")
if computer.getArchitecture() == "Lua 5.2" then
	for k, v in pairs(computer.getArchitectures()) do
		if v == "Lua 5.3" then
			printCentered("/!\\ Switch to Lua 5.3 by shift-clicking on your CPU or APU")
		end
	end
end

local lastBox = {0, 0, 0, 0}
local lastAutocomplete = nil

local function drawAutocomplete(tab, pos, current)
	driver.gpu.fill(lastBox[1], lastBox[2], lastBox[3], lastBox[4], 0)
	local maxLen = 0
	for _,v in pairs(tab) do
		maxLen = math.max(maxLen, current:len() + v:len())
	end
	lastAutocomplete = tab
	driver.gpu.fill(1, sh.getY()+1, maxLen, #tab, 0x2D2D2D)
	lastBox = {1, sh.getY()+1, pos+maxLen, #tab}
	for k,v in pairs(tab) do
		driver.gpu.drawText(1, sh.getY()+k, current, 0x00FFFF)
		driver.gpu.drawText(pos+1, sh.getY()+k, v, 0xFFFFFF)
	end
end

local function drawType(current, pos)
	if lastAutocomplete ~= nil then
		drawAutocomplete(sh.autocompleteFor(current, sh.fileAutocomplete), pos, current)
	end
end

print(string.rep("-=", math.floor(rw/2)))

os.setenv("PWD", "")
local drive = "A"
local run = true
while run do
	while true do -- used for break (to act as "continue" in other other languages)
	local ox, oy = sh.getCursor()
	sh.setCursor(1, 1)
	write(date("%H:%M"))
	sh.setCursor(ox, oy)
	os.setenv("PWD_DRIVE", drive)
	write(drive .. ":/" .. os.getenv("PWD") .. ">")
	local l = sh.read({
		["autocomplete"] = sh.fileAutocomplete,
		["autocompleteHandler"] = drawAutocomplete,
		["onType"] = drawType
	})
	driver.gpu.fill(lastBox[1], lastBox[2], lastBox[3], lastBox[4])
	lastAutocomplete = nil
	lastBox = {0, 0, 0, 0}
	local async = false
	if string.endsWith(l, "&") then
		l = l:sub(1, l:len()-1)
		async = true
	end
	local args = sh.parseCL(l)
	write(" \n")
	if #args == 0 then
		args[1] = ""
	end
	if args[1] == "exit" then
		run = false
		break
	end
	if args[1]:len() == 2 then
		if args[1]:sub(2, 2) == ":" then
			if not fs.isMounted(args[1]:sub(1, 1)) then
				print("No such drive: " .. args[1]:sub(1, 1))
				break
			end
			drive = args[1]:sub(1, 1)
			os.setenv("PWD", "")
			break
		end
	end
	
	if sh.getCommand(args[1]) ~= nil then
		args[1] = sh.getCommand(args[1])
	end

	local newargs = string.split(args[1])
	if #newargs > 1 then
		table.remove(args, 1)
		for i=#newargs, 1, -1 do
			table.insert(args, 1, newargs[i])
		end
	end
	
	local path = sh.resolve(args[1])
	local exists = true
	if not path then
		exists = false
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
			local f, err = loadfile(path)
			if f == nil then
				print(err)
			end

			local proc = tasks.newProcess(args[1], function()
				if f ~= nil then
					xpcall(f, function(err)
						io.stderr:write(err .. "\n")
						io.stderr:write(debug.traceback(nil, 2) .. "\n")
					end, programArgs)
				end
			end)
			if not async then
				proc:join()
			end
			driver.gpu.setForeground(0xFFFFFF)
			driver.gpu.setColor(0x000000)
		end, function(err)
			print(debug.traceback(err))
		end)
	else
		print("No such command or external file found.")
	end
	end -- end of "continue" while
end
