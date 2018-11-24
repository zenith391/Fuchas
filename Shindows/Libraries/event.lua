local interrupt = {}
local handlers = {}
interrupt.handlers = handlers
local _pullSignal = computer.pullSignal
setmetatable(handlers, {__call=function(_,...)return _pullSignal(...)end})

function interrupt.register(key, callback, interval, times, opt_handlers)
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

computer.pullSignal = function(...)
	local event_data = table.pack(handlers(...))
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
			--pcall(interrupt.onError, message)
		elseif message == false and handlers[id] == handler then
			handlers[id] = nil
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

function interrupt.pullFiltered(...)
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

function interrupt.pull(...)
  local args = table.pack(...)
  if type(args[1]) == "string" then
    return interrupt.pullFiltered(createPlainFilter(...))
  else
    checkArg(1, args[1], "number", "nil")
    checkArg(2, args[2], "string", "nil")
    return interrupt.pullFiltered(args[1], createPlainFilter(select(2, ...)))
  end
end

function interrupt.listen(name, callback)
  checkArg(1, name, "string")
  checkArg(2, callback, "function")
  for _, handler in pairs(handlers) do
    if handler.key == name and handler.callback == callback then
      return false
    end
  end
  return interrupt.register(name, callback, math.huge, math.huge)
end

function interrupt.cancel(timerId)
  checkArg(1, timerId, "number")
  if interrupt.handlers[timerId] then
    interrupt.handlers[timerId] = nil
    return true
  end
  return false
end

function interrupt.ignore(name, callback)
  checkArg(1, name, "string")
  checkArg(2, callback, "function")
  for id, handler in pairs(interrupt.handlers) do
    if handler.key == name and handler.callback == callback then
      interrupt.handlers[id] = nil
      return true
    end
  end
  return false
end

return interrupt