local drv = {}
local buffer = {}

-- Possible: driver-specific "voice-emulation" mode, allowing up to 3 "voices"

function drv.appendFrequency(channel, time, freq)
	table.insert(buffer, {time, freq})
	return true
end

function drv.flush()
	for k, v in pairs(buffer) do
		computer.beep(v[0], v[1])
		table.remove(buffer, k)
	end
end

function drv.setSynchronous(sync)
	return false -- failed
end

function drv.isSynchronous()
	return true
end

function drv.openChannel(channel)
	return false
end

function drv.closeChannel(channel)
	return false
end

function drv.getMaxChannels()
	return 1
end

return true, drv