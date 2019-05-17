-- Old library for audio. To be reconsidered.
-- Do NOT use for now.

local component = require("component")
local lib = {}
local sounds = {}

-- PS (PC Speaker), PCM
function dll.createSoundContext(type)
  local s = {}
  s.type = type
  s.closed = false
  s.buff = {}
  nSound = nSound + 1
  if nSound > 752 then
    nSound = 1
  end
  sounds[nSound] = s
  return nSound
end

-- internal api
function dll.initSoundSystem()
	-- Pro: Buffer, Audio (from API side) is asynchronous
	-- Con: Freeze other programs if using PC Speaker instdead of Computronics Sound Card..
	local pid1 = shin32.newProcess("voiceprocess", function()
		while true do
			local i = 1
			local i0 = 1
			while i0 < table.getn(apS1)+1 do
				local sound = apS1[i0]
				while i < table.getn(sound.buff)+1 do
					local freq = sound.buff[i]
					pcspeaker.beep(freq[1], freq[2])
					i = i + 1
					coroutine.yield()
				end
				table.remove(apS1, 1)
			end
			print("Voice 1")
			os.sleep(0.15)
		end
	end)
end
-- 8895
function dll.readSound(sound, buffer, type)
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

function dll.appendFrequency(soundID, freq, dur)
  if sounds[soundID].closed == false then
	table.insert(sounds[soundID].buff, {freq, dur})
  end
end

function dll.pcm(soundID, channel, freq)
end

function dll.play(soundID, voice)
	if voice == 1 then
		table.insert(apS1, sounds[soundID])
	end
	if voice == 2 then
		table.insert(apS2, sounds[soundID])
	end
end

function dll.clear(soundID)
  local i = 1
  while i < table.getn(sounds[soundID].buff) do
    table.remove(sounds[soundID].buff)
  end
end

function dll.close(soundID)
  dll.clear(soundID)
  sounds[soundID].closed = true
  sounds[soundID] = nil
end

return dll