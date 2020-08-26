local event = require("event")
local logger = require("log")("Tasks Scheduler")
local mod = {}
local incr = 1
local currentProc = nil
local processes = {}

--[[
	name: process name
	func: process function
	onlyIPC: true if the process should only use IPC to communicate with parent process (using main memory in this mode is DISALLOWED!)
	         this also allows the process to benefit from asymetric multi-processing if available.
]]
function mod.newProcess(name, func, onlyIPC)
	local pid
	pid = incr
	incr = incr + 1
	logger.debug("Creating process " .. name)
	local proc = {
		name = name,
		func = func,
		pid = pid, -- reliable pointer to process that help know if a process is dead
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
		detach = function(self)
			self.parent = nil
		end,
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
		proc.parent = currProc
		if currProc.userKey then
			proc.userKey = currProc.userKey
		end
	else
		proc.env = {}
		require("security").requestPermission("*", pid)
	end
	processes[pid] = proc
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
	local parent = p.parent
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
		if p.status == "wait_signal" then
			if lastEvent ~= nil then
				if lastEvent[1] ~= nil then
					p.result = lastEvent
					p.status = "ready"
				elseif computer.uptime() >= p.timeout then
					p.status = "ready"
					p.timeout = nil
				end
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
				p.timeout = computer.uptime() + a1
			elseif ret == "pull_event" then
				if a1 then
					p.timeout = computer.uptime() + a1
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

function mod.getCurrentProcess()
	return currentProc
end

function mod.sleep(secs)
	coroutine.yield("sleep", secs)
end

os.sleep = mod.sleep

function mod.getProcess(pid)
	if require("security").hasPermission("scheduler.list") or require("security").hasPermission("process.edit") then
		return processes[pid]
	else
		error("missing permission: scheduler.list or process.edit")
	end
end

function mod.waitFor(proc)
	while proc.status ~= "dead" do
		coroutine.yield()
	end
end

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
function mod.unsafeKill(proc)
	proc.status = "dead"
	if require("security").isRegistered(proc.pid) then
		require("security").revoke(proc.pid)
	end
	for k, v in pairs(proc.exitHandlers) do
		v()
	end
	proc.io.stdout:close()
	proc.io.stdin:close()
	proc.io.stderr:close()
	processes[proc.pid] = nil
	if currentProc == proc then
		coroutine.yield() -- process is dead and will now yield
	end
end

function mod.getProcessMetrics(pid)
	local proc = processes[pid]
	local parentPid = -1
	if proc.parent then parentPid = proc.parent.pid end
	return {
		name = proc.name,
		cpuTime = proc.cpuTime,
		lastCpuTime = proc.lastCpuTime,
		cpuLoadPercentage = proc.cpuLoadPercentage,
		status = proc.status,
		parent = parentPid
	}
end

function mod.getPIDs()
	local pids = {}
	for k, v in pairs(processes) do
		table.insert(pids, v.pid)
	end
	return pids
end

function mod.getProcesses()
	if require("security").hasPermission("scheduler.list") then
		return processes
	else
		error("missing permission: scheduler.list")
	end
end

return mod
