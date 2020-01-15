-- Old library for audio. To be reconsidered.
-- Do NOT use for now.

local driver = require("driver")
local lib = {}
local sources = {}

local function checkCapabilities(cap)
    local s = driver.getDriver("sound")
    local scap = s.getCapabilities()
    if cap.adsr and not scap.adsr then
        return false, "no adsr"
    elseif cap.asynchronous and not scap.asynchronous then
        return false, "no asynchronous"
    elseif cap.volume and not scap.volume then
        return false, "no volume option"
    end
    
    for _, v in pairs(cap.waveTypes) do
        local contain = false
        for _, w in pairs(scap.waveTypes) do
            if w == v then
                contain = true
            end
        end
        if not contain then
            return false, "missing " .. v .. " wave type"
        end
    end
    
    if cap.channels > scap.channels then
        return false, "not enough channels"
    end
end

function lib.newSource(capabilities)
    if not capabilities then
        capabilities = {
            adsr = false, -- no ADSR required
            asynchronous = false, -- synchronous
            volume = false, -- no volume setting
            waveTypes = [], -- neither wave type
            channels = 1 -- 1 channel minimum
        }
    end
    local ok, err = checkCapabilities(cap)
    if not ok then
        return nil, err
    end
    local source = {
        opened = true,
        data = {},
        setData = function(self, data)
            self.data = data
        end
    }
    local id = #sources+1
    sources[id] = source
    return id
end

-- Availables formats:
--	- AAF: Adaptive Audio Format
function lib.readFile(src, type)
	if not type then
		type = "aaf"
	end
	if type == "aaf" then
		local signature = src:read(5)
		if signature ~= string.char(19) .. "AAF" .. string.char(3) then -- DC3 .. AAF .. ETX
			return nil, "file isn't aaf"
		end
		local caps = {}
		local flag = string.byte(src:read(1)) -- waves flag
		if bit32.band(flag, 1) == 1 then
			table.insert(caps.waveTypes, "square")
		end
		if bit32.band(flag, 2) == 2 then
			table.insert(caps.waveTypes, "sine")
		end
		if bit32.band(flag, 4) == 4 then
			table.insert(caps.waveTypes, "triangle")
		end
		if bit32.band(flag, 8) == 8 then
			table.insert(caps.waveTypes, "sawtooth")
		end
		flag = string.byte(src:read(1)) -- miscelanous flag
		if bit32.band(flag, 1) == 1 then
			caps.adsr = true
		end
		if bit32.band(flag, 1) == 1 then
			caps.volume = true
		end
		caps.channels = string.byte(src:read(1))

		local ok, err = checkCapabilities(caps)
		if not ok then
			return nil, "missing capability: " .. err
		end


	end
end

function lib.play(soundID)
	local sound = sources[soundID]
	local driver = driver.getDriver("sound")
	local data = sound.data
	local lastWaveTypes = {}
	for 1, #data do
		local dat = data[i]
		if dat.wave ~= lastWaveTypes[dat.channel] then
			if driver.setWave(dat.channel, dat.wave) then
				lastWaveTypes[dat.channel] = dat.wave
			end
		end
		if dat.type == "flush" then
		end
		if dat.type == "adsr" then
			driver.setADSR(dat.channel, 0, 0, 0, 0)
		end
		if dat.type == "volume" then
			
		end
	end
end

function lib.close(soundID)
	lib.clear(soundID)
	sources[soundID].opened = false
	sources[soundID] = nil
end

return lib
