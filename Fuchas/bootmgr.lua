-- Bootstrap for Fuchas interface.
local fs = require("filesystem")
local tasks = require("tasks")

-- Unmanaged drives: TO-REDO
for addr, _ in component.list("drive") do
	--if fs.isValid(addr) then
	--	fs.mountDrive(fs.asFilesystem(addr), fs.freeDriveLetter())
	--end
end

-- User
if not fs.exists("A:/Users/Shared") then
	fs.makeDirectory("A:/Users/Shared")
end

local interface = tasks.newProcess("System Interface", function()
	dofile("A:/Fuchas/autorun.lua") -- system variables autorun
	local f, err = xpcall(function()
		require("users").login("guest") -- no password required
		print("(5/5) Loading " .. OSDATA.CONFIG["DEFAULT_INTERFACE"])
		while true do
			local name, _, char, code = require("event").pull(0)
			if not name then
				break
			elseif name == "key_down" then
				if code == 59 then -- F1
					OSDATA.CONFIG["SAFE_MODE"] = true
				end
			end
		end
		if OSDATA.CONFIG["SAFE_MODE"] then
			print("/!\\ Booting under Safe Mode! All non-essential drivers are disabled!")
			os.sleep(1)
		end
		local path = "A:/Fuchas/Interfaces/" .. OSDATA.CONFIG["DEFAULT_INTERFACE"] .. "/main.lua"
		if not fs.exists(path) then
			error("No such interface: " .. path)
		end
		local l, err = loadfile(path)
		if l == nil then
			error(err)
		end
		if false then
			local sound = require("driver").sound
			if sound then -- boot tone
				sound.openChannel(1)
				sound.appendFrequency(1, 0.2, 250)
				sound.appendFrequency(1, 0.2, 330)
				sound.appendFrequency(1, 0.2, 440)
				sound.flush()
				if sound.isSynchronous() then
					sound.closeChannel(1)
				end
			end
		end
		os.setenv("PWD", "")
		if not OSDATA.CONFIG["SAFE_MODE"] then
			local fileStream = io.open("A:/Fuchas/services.lon")
			local ok, services = pcall(require("liblon").loadlon, fileStream)
			fileStream:close()
			if ok and services then
				print("Starting services")
				if fs.exists("A:/Fuchas/Services") then
					for k, v in fs.list("A:/Fuchas/Services") do
						local fp = fs.concat("A:/Fuchas/Services/", k)
						local name = k:sub(1, k:len()-4)
						for _, n in ipairs(services.enabled) do
							if name == n then
								goto found
							end
						end
						goto continue
						::found::
						local f, err = loadfile(fp)
						if not f then
							io.stderr:write("Error while loading service '" .. k .. "': " .. err .. "\n")
							goto continue
						end
						local proc = tasks.newProcess(name, f)
						proc.isService = true
						::continue::
					end
				end
				if fs.exists("A:/Users/Shared/Services") then
					for k, v in fs.list("A:/Users/Shared/Services") do
						local fp = fs.concat("A:/Users/Shared/Services", k)
						local name = k:sub(1, k:len()-4)
						for _, n in ipairs(services.enabled) do
							if name == n then
								goto found
							end
						end
						goto continue
						::found::
						local f, err = loadfile(fp)
						if not f then
							io.stderr:write("Error while loading service '" .. k .. "': " .. err .. "\n")
							goto continue
						end
						local proc = tasks.newProcess(name, f)
						proc.isService = true
						::continue::
					end
				end
			else
				io.stderr:write("[Warning] Invalid services.lon file!\n\n")
			end
		end
		if OSDATA.CONFIG["DEFAULT_INTERFACE"] == "Fushell" then
			require("shell").clear()
		end
		return l()
	end, function(err)
		io.stderr:write("\nInterface crash:\n")
		io.stderr:write(err .. "\n")
		io.stderr:write(debug.traceback(nil, 2) .. "\n")
		return err
	end)
	if f == true then
		computer.shutdown() -- main interface exit
	else
		io.stderr:write("Restarting in 10 seconds..\n")
		os.sleep(10)
		computer.shutdown(true, { force = true })
	end
end)

while true do
	if interface.status == "dead" then
		computer.shutdown(true, { force = true })
	end
	tasks.scheduler()
end
