--- Event library, similar to the one found in OpenOS.
-- @module event
-- @alias event

local event = {}
local kbd = nil
local handlers = {}
event.handlers = handlers
local _pullSignal = computer.pullSignal
setmetatable(handlers, {__call=function(_,...)return _pullSignal(...)end})

-- undocumented
function event.register(key, callback, interval, times, opt_handlers)
		local pid
		if require("tasks").getCurrentProcess() then
				pid = require("tasks").getCurrentProcess().pid
		end
		local handler =
		{
				key = key,
				times = times or 1,
				callback = callback,
				interval = interval or math.huge,
		}
		handler.timeout = computer.uptime() + handler.interval
		opt_handlers = opt_handlers or handlers
		local id = 0
		repeat
				id = id + 1
		until not opt_handlers[id]
		opt_handlers[id] = handler
		return id
end

-- undocumented
function event.exechandlers(event_data)
		local signal = event_data[1]
		local copy = {}
		for id,handler in pairs(handlers) do
				copy[id] = handler
		end
		local current_time = os.clock()
		for id,handler in pairs(copy) do
				-- timers have false keys
				-- nil keys match anything
				if (handler.key == nil or handler.key == signal) or current_time >= handler.timeout then
						handler.times = handler.times - 1
						handler.timeout = current_time + handler.interval
						-- we have to remove handlers before making the callback in case of timers that pull
						-- and we have to check handlers[id] == handler because callbacks may have unregistered things
						if handler.times <= 0 and handlers[id] == handler then
								handlers[id] = nil
						end
						-- call
						local result, message = pcall(handler.callback, table.unpack(event_data, 1, event_data.n))
						if not result then
								--pcall(event.onError, message)
								error(message)
						elseif message == false and handlers[id] == handler then
								handlers[id] = nil
						end
				end
		end
end

computer.pushProcessSignal = function(pid, name, ...)
		local cproc = pid
		if type(cproc) == "number" then
				cproc = require("tasks").getProcess(pid)
		else
				return false, "invalid process/pid"
		end
		table.insert(cproc.events, table.pack(name, ...))
		return true
end

computer.pullSignal = function(...)
		if kbd == nil then kbd = require("keyboard") end
		local event_data
		if require("tasks").getCurrentProcess() == nil then
				event_data = table.pack(handlers(...))
				event.exechandlers(event_data)
		else
				local cproc = require("tasks").getCurrentProcess()
				if #cproc.events ~= 0 then
						event_data = table.remove(cproc.events, 1)
				else
						event_data = coroutine.yield("pull_event", ...) or {nil, n = 1}
				end
		end
		if kbd.isCtrlPressed() then
				if kbd.isPressed(46) then
						if kbd.isAltPressed() then
								kbd.resetInterrupted()
								error("interrupted", 2)
						else
								event.exechandlers({"interrupt"})
								return "interrupt"
						end
				end
		end
		return table.unpack(event_data, 1, event_data.n)
end

local function createPlainFilter(name, ...)
	local filter = table.pack(...)
	if name == nil and filter.n == 0 then
		return nil
	end

	return function(...)
		local signal = table.pack(...)
		if name and not (type(signal[1]) == "string" and signal[1]:match(name)) then
			return false
		end
		for i = 1, filter.n do
			if filter[i] ~= nil and filter[i] ~= signal[i + 1] then
				return false
			end
		end
		return true
	end
end

--- Gets an event that satisfies filter or a filter and a timeout in seconds.
-- @tparam[opt] number seconds Time in seconds until the function returns if no event was found
-- @tparam ?function filter The filter to use to filter out events
function event.pullFiltered(...)
	local args = table.pack(...)
	local seconds, filter

	if type(args[1]) == "function" then
		filter = args[1]
	else
		checkArg(1, args[1], "number", "nil")
		checkArg(2, args[2], "function", "nil")
		seconds = args[1]
		filter = args[2]
	end

	local deadline = seconds and (computer.uptime() + seconds) or math.huge
	repeat
		local closest = deadline
		for _,handler in pairs(handlers) do
			closest = math.min(handler.timeout, closest)
		end
		local signal = table.pack(computer.pullSignal(closest - computer.uptime()))
		if signal.n > 0 then
			if not (seconds or filter) or filter == nil or filter(table.unpack(signal, 1, signal.n)) then
				return table.unpack(signal, 1, signal.n)
			end
		end
	until computer.uptime() >= deadline
end

--- Flush all pending events, that is all pending events of the current process are immediately discarded.
function event.flush()
	local cproc = require("tasks").getCurrentProcess()
	cproc.events = {}
end

--- Gets an event for which the name satisfies the given match or the timeout is elapsed.
-- @tparam[opt] number seconds Time in seconds until the function returns if no event was found
-- @tparam ?string filter The match for the event name
function event.pull(...)
	local args = table.pack(...)
	if type(args[1]) == "string" then
		return event.pullFiltered(createPlainFilter(...))
	else
		checkArg(1, args[1], "number", "nil")
		checkArg(2, args[2], "string", "nil")
		return event.pullFiltered(args[1], createPlainFilter(select(2, ...)))
	end
end

--- Setup a callback to be called when an event with the given name is received.
-- @tparam string name The name of the event
-- @tparam function callback The function to be called when that event is received
-- @treturn int The timer ID
function event.listen(name, callback)
	checkArg(1, name, "string")
	checkArg(2, callback, "function")
	for _, handler in pairs(handlers) do
		if handler.key == name and handler.callback == callback then
			return false
		end
	end
	return event.register(name, callback, math.huge, math.huge)
end

--- Cancels a listener using its timer ID.
-- @see ignore
-- @tparam int timerId The timer ID
-- @treturn bool Returns true if there was a listener with the given timer iD
function event.cancel(timerId)
	checkArg(1, timerId, "number")
	if event.handlers[timerId] then
		event.handlers[timerId] = nil
		return true
	end
	return false
end

--- Cancels one listener waiting for the given event and using the given callback
-- @see cancel
-- @tparam string name The name of the event
-- @tparam function callback The callback funciton
-- @treturn bool Returns true if a listener matching the criterias was cancelled
function event.ignore(name, callback)
	checkArg(1, name, "string")
	checkArg(2, callback, "function")
	for id, handler in pairs(event.handlers) do
		if handler.key == name and handler.callback == callback then
			event.handlers[id] = nil
			return true
		end
	end
	return false
end

return event