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
        type = type,
        opened = true,
        data = {},
        setData = function(self, data)
            self.data = data
        end
    }
    local id = 1
    sources[id] = source
    return id
end

-- TODO: UPDATE
function lib.readSound(sound, buffer, type)
	if type == "psa" then
		local sound = dll.createSoundContext()
		local ver = string.byte(buffer:read(1))
		local len = string.byte(buffer:read(1))
		if ver == 1 then
			local i = 0
			while i < len do
				local freq = io.tou16({string.byte(buffer:read(1)), string.byte(buffer:read(1))}, 1)
				freq = tonumber(freq)
				print(freq)
				local dur = tonumber(string.byte(buffer:read(1)))
				dur = dur / 100
				dll.appendFrequency(sound, tonumber(freq), dur)
				i = i + 1
			end
		end
	end
end

function lib.close(soundID)
  lib.clear(soundID)
  sources[soundID].opened = false
  sources[soundID] = nil
end

return lib
