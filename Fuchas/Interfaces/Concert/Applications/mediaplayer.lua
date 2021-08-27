local file = io.open("A:/Users/Shared/Binaries/mario/music/song-piggies.aaf", "r")
local sound = require("driver").sound
local ui = require("OCX/OCUI")

file:read(5) -- skip signature
file:read(2) -- skip capability flags

local channelsNum = file:read(1):byte()
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
file:close()

local time = 0
local lastProcess = 0


local window = require("window").newWindow(50, 16, "Horacles")

local title = ui.label("Audio has " .. channelsNum .. " channel(s) / Playing on " .. sound.getMaxChannels() .. " channel(s)")
window.container:add(title)

local timeLabel = ui.label("Time: 0s")
timeLabel.y = 2
window.container:add(timeLabel)

window:show()

while window.visible do
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
				end
				note.played = true
			end
			local dur = (note.start + note.duration) - time
			minDur = math.min(minDur, dur)
		end
	end
	time = time + minDur
	sound.delay(minDur)
	if time - lastProcess > 1000 then
		local refreshed = false
		while not sound.flush() do
			os.sleep(0)
		end
		timeLabel:setText("Time: " .. math.floor(time/1000) .. "s")
		window:update()
		refreshed = true
		lastProcess = time
	end
end
