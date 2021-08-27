-- Driver for Computronics's Sound Card (called CP3)
-- TODO: Support CP1 (Beep Card)
--       and CP2 (Noise Card)
local cp = ...
local spec = {}

function spec.getRank()
	return 4
end

function spec.getName()
	return "Yanaki Sound Systems Drivers for MinoSound 244-X"
end

function spec.isCompatible(address)
	return cp.proxy(address).type == "sound"
end

function spec.new(address)
	local t = 0
	local syn = false
	local sound = cp.proxy(address)
	local drv = {}

	function drv.appendFrequency(channel, time, freq)
		sound.setFrequency(channel, freq)
		sound.delay(time)
	    t = t + time
		return true
	end

	function drv.setFrequency(channel, freq)
		sound.setFrequency(channel, freq)
		return true
	end

	function drv.delay(time)
		sound.delay(time)
		t = t + time
		return true
	end

	function drv.setADSR(ch, attack, decay, sustain, release)
		if not attack then
			sound.resetEnvelope(ch)
		else
			sound.setADSR(ch, attack, decay, sustain, release)
		end
		return true
	end

	-- TODO: LFSR

	function drv.setWave(ch, type)
		sound.setWave(ch, sound.modes[type])
		return true
	end

	function drv.flush()
		if not sound.process() then
			return false
		end
	    if syn then
	        os.sleep(t)
	    end
	    t = 0
	    return true
	end

	function drv.setSynchronous(sync)
		syn = sync
		return true
	end

	function drv.isSynchronous()
		return syn
	end

	function drv.openChannel(channel)
		if channel > drv.getMaxChannels() or channel <= 0 then
			return false
		end
		sound.open(channel)
		return true
	end

	function drv.closeChannel(channel)
		if channel > drv.getMaxChannels() or channel <= 0 then
			return false
		end
		sound.close(channel)
		return true
	end

	function drv.getMaxChannels()
		return sound.channel_count
	end

	function drv.setVolume(channel, volume)
		if not volume then
			volume = channel
			channel = -1
		end
		if channel == -1 then
			sound.setTotalVolume(volume)
		else
			sound.setVolume(channel, volume)
		end
	end

	function drv.getRank()
		return 4
	end

	function drv.getCapabilities()
		local waveTypes = {}
		for k, v in pairs(sound.modes) do
			if type(k) == "string" then
				table.insert(waveTypes, k)
			end
		end

	    return {
	        adsr = true,
	        asynchronous = true,
	        volume = true,
	        waveTypes = waveTypes,
	        channels = sound.channel_count
	    }
	end

	return drv
end

return spec
