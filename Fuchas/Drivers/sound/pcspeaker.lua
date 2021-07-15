local buffer = {}
local spec = {}
local cp = ...

function spec.getRank() -- used by "driver" library to choose best default driver
	return 1
end

function spec.getName()
	return "Lame(R) PC Speaker"
end

function spec.isCompatible(address)
	return cp.type(address) == "computer"
end

function spec.new(address)
	local drv = {}
	drv.getName = spec.getName
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
			computer.beep(v[2], v[1])
		end
		buffer = {}
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

	function drv.getCapabilities()
	    return {
	        adsr = false,
	        asynchronous = false,
	        volume = false,
	        waveTypes = {"square"},
	        channels = 1
	    }
	end
	return drv
end

return spec
