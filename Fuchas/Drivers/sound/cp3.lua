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
	local max = math.floor(sound.channel_count)

	function drv.appendFrequency(channel, time, freq)
		sound.setFrequency(channel, freq)
		sound.delay(time)
	    t = t + time
		return true
	end

	function drv.setFrequency(channel, freq)
		if channel < 1 or channel > max then
			return false, "channel must be in range [1, " .. max .. "]"
		end
		sound.setFrequency(channel, freq)
		return true
	end

	function drv.delay(time)
		sound.delay(time)
		t = t + time
		return true
	end

	function drv.setADSR(ch, attack, decay, sustain, release)
		if ch < 1 or ch > max then
			return false, "channel must be in range [1, " .. max .. "]"
		end
		if attack then
			sound.setADSR(ch, attack, decay, sustain, release)
		else
			sound.resetEnvelope(ch)
		end
		return true
	end

	function drv.setLFSR(channel, initial, mask)
		if channel < 1 or channel > max then
			return false, "channel must be in range [1, " .. max .. "]"
		end
		sound.setLFSR(channel, initial, mask)
	end

	function drv.setWave(ch, type)
		if ch < 1 or ch > max then
			return false, "channel must be in range [1, " .. max .. "]"
		end
		if not sound.modes[type] then
			error("invalid wave type '" .. tostring(type) .. "', expected one of 'sine', 'square', 'sawtooth', 'triangle', 'noise'")
		end
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
		if channel < 1 or channel > max then
			return false, "channel must be in range [1, " .. max .. "]"
		end
		sound.open(channel)
		return true
	end

	function drv.closeChannel(channel)
		if channel < 1 or channel > max then
			return false, "channel must be in range [1, " .. max .. "]"
		end
		sound.close(channel)
		return true
	end

	function drv.getMaxChannels()
		-- Floored so it returns an integer instead of a float which would cause printing it as 8.0
		return math.floor(sound.channel_count)
	end

	function drv.setVolume(channel, volume)
		if not volume then
			volume = channel
			channel = -1
		end
		if channel == -1 then
			sound.setTotalVolume(volume)
		else
			if channel < 1 or channel > max then
				return false, "channel must be in range [1, " .. max .. "] or -1"
			end
			sound.setVolume(channel, volume)
		end
	end

	function drv.setAM(carrier, modulator)
		if modulator then
			sound.setAM(carrier, modulator)
		else
			sound.resetAM(carrier)
		end
	end

	function drv.setFM(carrier, modulator, index)
		if modulator then
			sound.setFM(carrier, modulator, index)
		else
			sound.resetFM(carrier)
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
	        channels = sound.channel_count,
	        frequencyModulation = true,
	        amplitudeModulation = true,
	    }
	end

	return drv
end

return spec
