-- Driver for Computronics's Sound Card (I call it CP3)
-- TODO: Support CP1 (Beep Card)
--       and CP2 (Noise Card)
local drv = {}
local t = 0
local syn = false
local sound = component.getPrimary("sound")

-- Universal for all sound drivers
function drv.appendFrequency(channel, time, freq)
	sound.setFrequency(freq)
	sound.delay(time)
    t = t + time
	return true
end

function drv.setADSR(ch, attack, decay, sustain, release)
	sound.setADSR(ch, attack, decay, sustain, release)
	return true
end

function drv.setWave(ch, type)
	sound.setWave(ch, type)
	return true
end

function drv.flush()
	sound.process()
    if syn then
        os.sleep(t)
    end
    t = 0
end

function drv.setSynchronous(sync)
	syn = sync
	return true
end

function drv.isSynchronous()
	return syn
end

function drv.openChannel(channel)
	if channel > drv.getMaxChannels() or channel < 0 then
		return false
	end
	sound.open(channel)
	return true
end

function drv.closeChannel(channel)
	if channel > drv.getMaxChannels() or channel < 0 then
		return false
	end
	sound.close(channel)
	return true
end

function drv.getMaxChannels()
	return 8
end

-- Specific to sound card

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

function drv.getRank() -- used by "driver" library to choose best driver
	return 4 -- 1: PC speaker, 2: CP1, 3: CP2
end

function drv.getCapabilities()
    return {
        adsr = true,
        asynchronous = true,
        volume = true,
        waveTypes = {"sine", "square", "triangle", "sawtooth"},
        channels = 8
    }
end

return component.isAvailable("sound"), "sound", drv
