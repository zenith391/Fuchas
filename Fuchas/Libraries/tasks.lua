--- User library allowing to create and manage processes.
-- @module tasks
-- @alias mod

local event = require("event")
local logger = require("log")("Tasks Scheduler")
local mod = {}
local incr = 1
local currentProc = nil
local processes = {}

--[[
	Creates a process that can only communicate with other processes using IPC.
	Those processes cannot use I/O and cannot have a parent.

	name: Process name
	code: Process code
]]
function mod.newDaemon(name, code)
	local pid
	pid = incr
	incr = incr + 1

	logger.debug("Creating daemon process " .. name)
	if worker then
		local currProc = mod.getCurrentProcess()
		worker.sendNewProcess(pid, code, currProc.env)
		processes[pid] = {
			name = name,
			pid = pid,
			peer = "worker"
		}
	else
		local proc = {
			name = name,
			func = code,
			pid = pid, -- reliable pointer to process that help know if a process is dead
			kill = function(self)
				mod.safeKill(self)
			end,
			join = function(self)
				mod.waitFor(self)
			end
		}
		local currProc = mod.getCurrentProcess()
		if currProc ~= nil then
			proc.env = currProc.env
		else
			proc.env = {}
			require("security").requestPermission("*", pid)
		end
		processes[pid] = proc
	end
	return proc
end

local function systemEvent(pack)
	local fs = require("filesystem")
	local id = pack[1]
	if id == "component_added" then
		if pack[3] == "filesystem" then
			local letter = fs.freeDriveLetter()
			if letter ~= nil then -- if nil, then cannot mount another drive
				fs.mountDrive(component.proxy(pack[2]), letter)
			end
		end
	end
	if id == "component_removed" then
		if pack[3] == "filesystem" then
			fs.unmountDrive(fs.getLetter(pack[2]))
		end
	end
	return true
end

local function handleProcessError(err, p)
	local parent = processes[p.parent]
	if parent ~= nil then
		if parent.childErrorHandler then
			currentProc = p
			parent.childErrorHandler(p, err)
			currentProc = nil
			return true
		else
			return handleProcessError(err, parent)
		end
	else
		return false
	end
end

-- Debug Utilities --
local logHandle = nil
local function startLogging()
	logHandle = require("filesystem").open("A:/scheduler.csv", "w")
	logHandle:write("Name,Burst Time\n")
end

local function writeBurst(name, time)
	if logHandle then
		logHandle:write(name .. "," .. tostring(time) .. "\n")
	end
end

local function stopLogging()
	logHandle:close()
end

-- Scheduler --
local lastLoadPercentage = 0
local totalStart = 0
local minSleepTime = 0
local canSleep = true

local schedulerMode = "SJF" -- SJF or FCFS
local sjfAlpha = 0.3 -- alpha value for SJF scheduler

--- Used internally.
-- @local
function mod.scheduler()
	if not logHandle and false then
		startLogging()
		require("event").listen("shutdown", function()
			stopLogging()
		end)
	end
	if mod.getCurrentProcess() ~= nil then
		error("only system can use tasks.scheduler()")
	end
	
	local measure = computer.uptime
	local lastEvent = table.pack(event.handlers((not canSleep and 0) or minSleepTime, 1))
	if not systemEvent(lastEvent) then
		lastEvent = nil -- if not propagating
	end
	if lastEvent and lastEvent[1] then
		event.exechandlers(lastEvent)
	end
	minSleepTime = math.huge
	canSleep = true
	if totalStart == 0 then
		totalStart = measure()
	end
	local orderedProcesses = {}
	for k, v in pairs(processes) do
		table.insert(orderedProcesses, v)
	end
	if schedulerMode == "SJF" then
		table.sort(orderedProcesses, function(a, b)
			return a.cpuTimeEstimate < b.cpuTimeEstimate
		end)
	end
	for k, p in pairs(orderedProcesses) do
		--logger.info(p.name .. ": " .. p.status)
		if lastEvent and lastEvent[1] then table.insert(p.events, lastEvent) end
		local start = measure()
		if p.status == "created" then
			p.thread = coroutine.create(p.func)
			p.status = "ready"
			p.func = nil
			canSleep = false
		end
		if coroutine.status(p.thread) == "dead" then -- if it died for some unhandled reason
			mod.unsafeKill(p) -- no need to safe kill, it's already dead
		end
		if p.parent and not processes[p.parent] then -- if the parent died, die too
			mod.unsafeKill(p)
		end
		if p.status == "wait_signal" then
			if #p.events == 0 and computer.uptime() >= p.timeout then
				p.status = "ready"
				p.timeout = nil
			elseif #p.events > 0 then
				p.result = table.remove(p.events, 1)
				p.status = "ready"
			end
			minSleepTime = math.min(minSleepTime, math.max(0, (p.timeout or 0) - computer.uptime()))
		end
		if p.status == "sleeping" then
			if computer.uptime() >= p.timeout then
				p.status = "ready"
				p.timeout = nil
			end
			minSleepTime = math.min(minSleepTime, (p.timeout or computer.uptime()) - computer.uptime())
		end
		if p.status == "ready" then
			p.status = "running"
			local ok, ret, a1
			currentProc = p
			if p.result then
				ok, ret, a1 = coroutine.resume(p.thread, p.result)
				p.result = nil
			else
				ok, ret, a1 = coroutine.resume(p.thread)
			end
			currentProc = nil
			if not ok then
				if p.errorHandler then
					currentProc = p
					p.errorHandler(ret)
					currentProc = nil
				else
					if not handleProcessError(ret, p) then
						mod.unsafeKill(p)
					end
				end
			end
			if ret == "sleep" then
				p.status = "sleeping"
				p.timeout = computer.uptime() + (a1 or 0)
			elseif ret == "pull_event" then
				if a1 then
					p.timeout = computer.uptime() + (a1 or 0)
				else
					p.timeout = math.huge
				end
				p.status = "wait_signal"
			elseif p.status ~= "dead" then
				p.status = "ready"
				canSleep = false
			end
		end
		local e = measure()
		p.lastCpuTime = p.lastCpuTime + math.floor(e*1000 - start*1000) -- cpu time used in 1 second
		writeBurst(e*1000 - start*1000)
		p.cpuTime = p.cpuTime + math.floor(e*1000 - start*1000)
	end

	if computer.uptime() > lastLoadPercentage+1 then -- 1 second
		local totalEnd = measure()
		local time = math.floor(totalEnd*1000 - totalStart*1000)
		time = 1000

		for k, p in pairs(processes) do
			if time ~= 0 then
				p.cpuLoadPercentage = (p.lastCpuTime / time) * 100
				if schedulerMode == "SJF" then
					p.cpuTimeEstimate = sjfAlpha * p.lastCpuTime + (1 - sjfAlpha) * p.cpuTimeEstimate
				end
				p.lastCpuTime = 0
			end
		end
		--totalStart = 0
		lastLoadPercentage = computer.uptime()
	end
end

--- Returns the current process object or nil if no process is active (only the case during boot)
-- @return process object
function mod.getCurrentProcess()
	return currentProc
end

--- Pause the current process for the specified number of seconds
-- @param secs Seconds to wait
-- @see os.sleep
function mod.sleep(secs)
	coroutine.yield("sleep", secs)
end
os.sleep = mod.sleep

--- Get the process object corresponding to the given PID.
-- @param pid PID of the process
-- @return process object
-- @permission scheduler.list or process.edit
function mod.getProcess(pid)
	if require("security").hasPermission("scheduler.list") or require("security").hasPermission("process.edit") then
		return processes[pid]
	else
		error("missing permission: scheduler.list or process.edit")
	end
end

--- Pause the current process until the given process has ended
-- @param proc Process to wait for
-- @see process:join
function mod.waitFor(proc)
	while proc.status ~= "dead" do
		coroutine.yield()
	end
end

--- Kill the given process, calling the safe kill handler if present
-- @param proc process object
function mod.kill(proc)
	if proc.safeKillHandler then
		local oldProc = currentProc
		currentProc = proc
		local doKill = proc.safeKillHandler()
		currentProc = oldProc
		if doKill then
			mod.unsafeKill(proc)
		end
	else
		mod.unsafeKill(proc)
	end
end
mod.safeKill = mod.kill

--- Kill the given process without accounting for the safe kill handler.
-- @param proc process object
function mod.unsafeKill(proc)
	proc.status = "dead"
	if require("security").isRegistered(proc.pid) then
		require("security").revoke(proc.pid)
	end

	local oldCurrentProc = currentProc
	currentProc = proc
	for k, v in pairs(proc.exitHandlers) do
		v()
	end
	currentProc = oldCurrentProc

	proc.io.stdout:close()
	proc.io.stdin:close()
	proc.io.stderr:close()
	processes[proc.pid] = nil
	if currentProc == proc then
		coroutine.yield() -- process is dead and will now yield
	end
end

--- Returns the process metrics from the given PID
-- @param pid pid of process
-- @return process metrics
function mod.getProcessMetrics(pid)
	local proc = processes[pid]
	local parentPid = -1
	if proc.parent then parentPid = proc.parent end
	return {
		name = proc.name,
		cpuTime = proc.cpuTime,
		lastCpuTime = proc.lastCpuTime,
		cpuLoadPercentage = proc.cpuLoadPercentage,
		status = proc.status,
		parent = parentPid
	}
end

--- Returns the permission granter function from the given PID
--- This is only used in the security library
-- @param pid pid of process
-- @return function?
function mod.getPermissionGrant(pid)
	local proc = processes[pid]
	return proc.permissionGrant
end

--- Returns the user key
-- @param pid pid of process
-- @return user key
function mod.getUserKey(pid)
	local proc = processes[pid]
	return proc.userKey
end

--- Returns the list of PIDs used by living processes
-- @treturn number[] all PIDs
function mod.getPIDs()
	local pids = {}
	for k, v in pairs(processes) do
		table.insert(pids, v.pid)
	end
	return pids
end

--- Returns the list of all living process objects
-- @permission scheduler.list
-- @treturn process[] all process objects
function mod.getProcesses()
	if require("security").hasPermission("scheduler.list") then
		return processes
	else
		error("missing permission: scheduler.list")
	end
end

--- Spawns and starts a new process
-- @param name The name of the process
-- @param func The function to be called as process
-- @treturn process process object
-- @constructor
function mod.newProcess(name, func, onlyIPC)
	local pid
	pid = incr
	incr = incr + 1
	logger.debug("Creating process " .. name)

	--- A process object.
	-- @type process
	-- @string name The name
	local proc = {
		--- The name of the process
		name = name,
		--- The coroutine function of the process
		func = func,
		--- The PID of the process. It's a reliable pointer to process that help know if a process is dead
		pid = pid,
		--- The status of the process, can be one of "created", "running", "sleeping" or "wait_signal"
		status = "created",
		cpuTime = 0,
		cpuTimeEstimate = 0, -- used for SJF scheduler
		lastCpuTime = 0,
		cpuLoadPercentage = 0,
		exitHandlers = {},
		events = {},
		operation = nil, -- the current async operation
		io = { -- a copy of current parent process's io streams
			stdout = io.stdout,
			stderr = io.stderr,
			stdin = io.stdin
		},
		errorHandler = nil,

		--- Detach the given process, that is make it an orphan process (with no parent)
		-- @function detach
		detach = function(self)
			self.parent = nil
		end,

		--- Kill the given process
		-- @function kill
		kill = function(self)
			mod.safeKill(self)
		end,
		join = function(self)
			mod.waitFor(self)
		end
	}

	local currProc = mod.getCurrentProcess()
	if currProc ~= nil then
		proc.env = {}
		for k, v in pairs(currProc.env) do
			proc.env[k] = v
		end
		proc.parent = currProc.pid
		if currProc.userKey then
			proc.userKey = currProc.userKey -- TODO: the child key isn't valid so use userKeyForChild
		end
	else
		proc.env = {}
		require("security").requestPermission("*", pid)
	end
	processes[pid] = proc
	return processes[pid]
end

return mod
