local event = require("event")
local mod = {}

local incr = 1
local currentProc = nil
local processes = {}

function mod.newProcess(name, func)
	local pid
	pid = incr
	incr = incr + 1
	local proc = {
		name = name,
		func = func,
		pid = pid, -- reliable pointer to process that help know if a process is dead; TODO: remove
		status = "created",
		cpuTime = 0,
		lastCpuTime = 0,
		cpuLoadPercentage = 0,
		exitHandlers = {},
		events = {},
		operation = nil, -- the current async operation
		closeables = {}, -- used for file streams; replaced iwth exitHandlers
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
		end,
		commitOperation = function(self, op)
			self.operation = op
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
			parent.childErrorHandler(p, err)
			return true
		else
			return handleProcessError(err, parent)
		end
	else
		return false
	end
end

local lastLoadPercentage = 0
local totalStart = 0
function mod.scheduler()
	if mod.getCurrentProcess() ~= nil then
		error("only system can use shin32.scheduler()")
	end
	
	local measure = computer.uptime
	local lastEvent = table.pack(event.handlers(0))
	if not systemEvent(lastEvent) then
		lastEvent = nil -- if not propagating
	end
	if lastEvent and lastEvent[1] then
		event.exechandlers(lastEvent)
	end
	
	if totalStart == 0 then
		totalStart = measure()
	end
	for k, p in pairs(processes) do
		local start = measure()
		if p.status == "created" then
			p.thread = coroutine.create(p.func)
			p.status = "ready"
			p.func = nil
		end
		if coroutine.status(p.thread) == "dead" then -- if it died for some unhandled reason
			mod.unsafeKill(p)
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
		end
		if p.status == "ready" then
			p.status = "running"
			local ok, ret, a1, a2, a3
			currentProc = p
			if p.result then
				ok, ret, a1, a2, a3 = coroutine.resume(p.thread, p.result)
				p.result = nil
			else
				ok, ret, a1, a2, a3 = coroutine.resume(p.thread)
			end
			currentProc = nil
			if p.status ~= "dead" then
				p.status = "ready"
			end
			if not ok then
				if p.errorHandler then
					p.errorHandler(ret)
				else
					if not handleProcessError(ret, p) then
						mod.unsafeKill(p)
					end
				end
			end
			if ret == "pull_event" then
				if a1 then
					p.timeout = computer.uptime() + a1
				else
					p.timeout = math.huge
				end
				p.status = "wait_signal"
			end
		end
		local e = measure()
		p.lastCpuTime = p.lastCpuTime + math.floor(e*1000 - start*1000) -- cpu time used in 1 second
		p.cpuTime = p.cpuTime + math.floor(e*1000 - start*1000)
	end

	if measure() > lastLoadPercentage+1 then -- 1 second
		local totalEnd = measure()
		local time = math.floor(totalEnd*1000 - totalStart*1000)

		for k, p in pairs(processes) do
			if time ~= 0 then
				p.cpuLoadPercentage = (p.lastCpuTime / time) * 100
				p.lastCpuTime = 0
			end
		end
		totalStart = 0
		lastLoadPercentage = measure()
	end
end

function mod.getCurrentProcess()
	return currentProc
end

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
		local doKill = proc.safeKillHandler()
		currentProc = proc
		if doKill then
			mod.unsafeKill(proc)
		end
		currentProc = nil
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
	for k, v in pairs(proc.closeables) do
		v:close()
	end
	for k, v in pairs(proc.exitHandlers) do
		v()
	end
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