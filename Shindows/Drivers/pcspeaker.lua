local drv = {}

function drv.playFrequency(time, freq)
	computer.beep(freq, time)
end

function drv.isSynchronous()
	return true
end

return true, drv