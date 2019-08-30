local drv = {}
local buffer = {}

-- Possible: driver-specific "voice-emulation" mode, allowing up to 3 "voices"

function drv.appendFrequency(channel, time, freq)
	table.insert(buffer, {time, freq})
	return true
end

function drv.setADSR(ch, attack, decay, sustain, release)
	return false, "unsupported"
end

function drv.setWave(ch, type)
	return false, "unsupported"
end

function drv.flush()
	for k, v in pairs(buffer) do
		computer.beep(v[0], v[1])
		table.remove(buffer, k)
	end
end

function drv.setSynchronous(sync)
	return false, "unsupported" -- failed
end

function drv.isSynchronous()
	return true
end

function drv.openChannel(channel)
	return false, "unsupported"
end

function drv.closeChannel(channel)
	return false, "unsupported"
end

function drv.getMaxChannels()
	return 1
end

function drv.getRank() -- used by "driver" library to choose best driver
	return 1
end

function drv.getCapabilities()
    return {
        adsr = false,
        asynchronous = false,
        volume = false,
        waveTypes = {"square"},
        channels = 1
    }
end

function drv.getName()
	return "Lame(R) PC Speaker"
end

return true, "sound", drv
