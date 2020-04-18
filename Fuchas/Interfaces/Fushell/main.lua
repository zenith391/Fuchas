local sh = require("shell")
local fs = require("filesystem")
local tasks = require("tasks")
local driver = require("driver")

-- Avoid killing (safely) system process with a custom quit handler
tasks.getCurrentProcess().safeKillHandler = function()
	io.stderr:write("cannot kill system process!\n")
	return false
end

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
	io.write(string.rep(" ", math.floor(rw/2-str:len()/2)))
	print(str)
end

sh.clear()
-- splash
print(string.rep("=-", math.floor(rw/2)))
printCentered(_OSVERSION .. "'s Fushell")
printCentered("Type \"help\" if you don't know what to do!")
printCentered("GitHub: https://github.com/zenith391/Fuchas")
if computer.getArchitecture() == "Lua 5.2" then
	for k, v in pairs(computer.getArchitectures()) do
		if v == "Lua 5.3" then
			printCentered("/!\\ Please switch to Lua 5.3 by shift-clicking on your CPU or APU")
			printCentered("/!\\ You cannot login on password protected account with Lua 5.2!")
		end
	end
end
print(string.rep("-=", math.floor(rw/2)))

os.setenv("PWD", "")
local drive = "A"
local run = true
while run do
	while true do -- used for break (to act as "continue" in other other languages)
	os.setenv("PWD_DRIVE", drive)
	io.write(drive .. ":/" .. os.getenv("PWD") .. ">")
	local ok, l = pcall(sh.read, {
		["autocomplete"] = sh.fileAutocomplete
	})
	io.write(" \n")
	if not ok and string.endsWith(l, "interrupted") then
		print("Ctrl+Alt+C: Restarting")
		computer.shutdown(true)
		return
	end
	local async = false
	if string.endsWith(l, "&") then
		l = l:sub(1, l:len()-1)
		async = true
	end
	local commands = sh.parseCL(l)
	local chainStream = nil
	for i=1, #commands do
		local args = commands[i]
		if #args == 0 then
			args[1] = ""
		end
		if args[1] == "exit" then -- special case: exit cmd
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

				local func = function()
					if f ~= nil then
						xpcall(f, function(err)
							io.stderr:write(err .. "\n")
							io.stderr:write(debug.traceback(nil, 2) .. "\n")
						end, programArgs)
					end
				end
				local proc = nil

				if i == #commands then
					proc = tasks.newProcess(args[1], func)
					if chainStream then
						proc.io.stdin = chainStream
					end
					if not async then
						proc:join()
						driver.gpu.setForeground(0xFFFFFF)
						driver.gpu.setColor(0)
					end
				else
					local oldChainStream = chainStream
					chainStream, proc = io.pipedProc(func, args[1], "r")
					if oldChainStream then
						proc.io.stdin = oldChainStream
					end
				end
			end, function(err)
				print(debug.traceback(err))
			end)
		else
			print("No such command or external file found.")
			break
		end
	end
	end -- end of "continue" while
end
