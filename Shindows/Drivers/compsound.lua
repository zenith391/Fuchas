-- Driver for Computronics's Sound Card
local drv = {}

function drv.playFrequency(time, freq)
	-- TODO
end

function drv.isSynchronous()
	return false
end

return component.isAvailable("sound"), drv