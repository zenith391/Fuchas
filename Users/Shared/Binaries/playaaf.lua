local shell = require("shell")
local args, ops = shell.parse(...)
if args[1] then
	args[1] = shell.resolveToPwd(args[1])
end
local file = io.open(args[1] or "A:/Users/Shared/Binaries/song.aaf", "r")
local sound = require("driver").sound

file:read(5) -- skip signature
file:read(2) -- skip capability flags

local channelsNum = file:read(1):byte()
print("Using " .. channelsNum .. " channels")
local channelNotes = {}
local channelIdx = {}

for i=1, channelsNum do
	sound.openChannel(i)
	sound.setWave(i, "square")
	sound.setVolume(i, 0)
	sound.setADSR(i)
	channelNotes[i] = {}
	channelIdx[i] = 1
end

local fileEnded = false
while not fileEnded do
	for i=1, channelsNum do
		local freqStr = file:read(2)
		if not freqStr then fileEnded = true; break; end
		local freq = string.unpack("<I2", freqStr)
		local dur = string.unpack("<I2", file:read(2))
		local start = 0
		if channelNotes[i][#channelNotes[i]] then
			local note = channelNotes[i][#channelNotes[i]]
			start = note.start + note.duration
		end
		table.insert(channelNotes[i], { frequency = freq, duration = math.floor(dur/1.0), start = start })
	end
end

local time = 0
local lastProcess = 0
while true do
	local minDur = math.huge
	for i=1, channelsNum do
		local note = channelNotes[i][channelIdx[i]]
		if note and (time >= note.start + note.duration) then
			channelIdx[i] = channelIdx[i] + 1
			note = channelNotes[i][channelIdx[i]]
		end
		if note then
			if time >= note.start and not note.played then
				if note.frequency == 0 then
					sound.setFrequency(i, 0)
				else
					sound.setADSR(i)
					sound.setADSR(i, 0, 250, 0.3, 100)
					sound.setVolume(i, 1)
					sound.setFrequency(i, note.frequency)
					print(time .. " ms: press " .. note.frequency .. " Hz for " .. note.duration .. " ms, channel " .. i)
				end
				note.played = true
			end
			local dur = (note.start + note.duration) - time
			minDur = math.min(minDur, dur)
		end
	end
	time = time + minDur
	sound.delay(minDur)
	if time - lastProcess > 3000 then
		while not sound.flush() do
			os.sleep(0)
		end
		lastProcess = time
	end
end

file:close()
