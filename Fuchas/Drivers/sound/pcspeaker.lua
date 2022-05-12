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
	drv.freq = 440
	function drv.appendFrequency(channel, time, freq)
		table.insert(buffer, {time / 1000, freq})
		return true
	end

	function drv.setFrequency(channel, freq)
		if channel > 1 then
			return false, "channel must be in range [1, 1]"
		end
		drv.freq = freq
	end

	function drv.delay(time)
		if buffer[#buffer] then
			local previousItem = buffer[#buffer]
			-- If we're adding the same frequency as the previous item
			if previousItem[2] == drv.freq then
				-- Just merge the two
				previousItem[1] = previousItem[1] + time / 1000
				return
			end
		end
		
		table.insert(buffer, {time / 1000, drv.freq})
	end

	function drv.setVolume(channel, volume)
		return false, "unsupported"
	end

	function drv.setADSR(ch, attack, decay, sustain, release)
		return false, "unsupported"
	end

	function drv.setWave(ch, type)
		return false, "unsupported"
	end

	function drv.flush()
		for k, v in pairs(buffer) do
			if v[2] >= 20 and v[2] <= 2000 then
				computer.beep(v[2], v[1])
			else
				os.sleep(v[1])
			end
		end
		buffer = {}
		return true
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
	        channels = 1,
	        frequencyModulation = false,
	        amplitudeModulation = false,
	    }
	end
	return drv
end

return spec
