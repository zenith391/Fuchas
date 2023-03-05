local file = io.open("A:/Users/Shared/Binaries/mario/music/song-spider-dance.aaf", "r")
local sound = require("driver").sound
local ui = require("OCX/OCUI")
local dbg = require("driver").debugger
local SPEED = 1.0

-- disable debug
dbg = nil

file:read(5) -- skip signature
file:read(2) -- skip capability flags

local channelsNum = file:read(1):byte()
local channelNotes = {}
local channelIdx = {}
local channelsVolume = {}

if sound.getCapabilities().channels < channelsNum and sound.getCapabilities().channels ~= 8 then
	require("concert").dialogs.showErrorMessage(
		"You can have much better sound quality using the Sound Card from the Computronics mod!",
		"Notice")
end

for i=1, sound.getCapabilities().channels do
	sound.closeChannel(i)
end

for i=1, channelsNum do
	if i <= sound.getCapabilities().channels then
		sound.openChannel(i)
		sound.setWave(i, "square")
		sound.setVolume(i, 0)
		sound.setADSR(i)
	end
	channelNotes[i] = {}
	channelIdx[i] = 1
	channelsVolume[i] = 0.5
end

if channelsNum < 8 and false then
	sound.openChannel(8)
	sound.setWave(8, "sine")
	sound.setFrequency(8, 880)
	for i=1, channelsNum do
		sound.setFM(i, 8, 100)
	end
end

local fileEnded = false
while not fileEnded do
	for i=1, channelsNum do
		local freqStr = file:read(2)
		if not freqStr then fileEnded = true; break; end
		local freq = string.unpack("<I2", freqStr)
		if freq == 2 then -- set volume
			local volume = string.unpack("<I1", file:read(1))
			local start = 0
			if channelNotes[i][#channelNotes[i]] then
				local note = channelNotes[i][#channelNotes[i]]
				start = note.start + (note.duration or 0)
			end
			table.insert(channelNotes[i], { volume = volume / 255, start = start })
		elseif freq == 3 then -- set wave type
			local waveTypeInt = string.unpack("<I1", file:read(1))
			local waveType = ({"square","sine","triangle","sawtooth"})[waveTypeInt + 1]
			local start = 0
			if channelNotes[i][#channelNotes[i]] then
				local note = channelNotes[i][#channelNotes[i]]
				start = note.start + (note.duration or 0)
			end
			table.insert(channelNotes[i], { waveType = waveType, start = start })
		else
			local dur = string.unpack("<I2", file:read(2))
			local start = 0
			if channelNotes[i][#channelNotes[i]] then
				local note = channelNotes[i][#channelNotes[i]]
				start = note.start + (note.duration or 0)
			end
			table.insert(channelNotes[i], { frequency = freq, duration = dur, start = start })
		end
	end
end
file:close()

local songDuration = 0
for i=1, channelsNum do
	for j=1, #channelNotes[i] do
		local note = channelNotes[i][j]
		if note.frequency and note.frequency ~= 0 then
			songDuration = math.max(songDuration, note.start + note.duration)
		end
	end
end

local time = 0
--time = 120 * 1000
local lastProcess = 0


local window = require("window").newWindow(50, 16, "Fuchas Media Player")

local title = ui.label("Audio has " .. channelsNum .. " channel(s) / Playing on " .. sound.getMaxChannels() .. " channel(s)")
window.container:add(title)

local timeLabel = ui.label("Time: 0s")
timeLabel.y = 2
window.container:add(timeLabel)

window:show()

local BUFFER_MSECS = 1000 * SPEED

local function formatTime(secs)
	local time = ""
	if secs >= 60 then
		time = time .. tostring(math.floor(secs / 60)) .. "m"
	end
	if secs % 60 < 10 and secs / 60 >= 1 then time = time .. "0" end
	time = time .. tostring(secs % 60) .. "s"
	return time
end

local cardChannels = sound.getCapabilities().channels
while window.visible do
	local minDur = math.huge
	for i=1, channelsNum do
		local note = channelNotes[i][channelIdx[i]]
		while note and time >= note.start + (note.duration or 0) do
			channelIdx[i] = channelIdx[i] + 1
			note = channelNotes[i][channelIdx[i]]
			if note and note.volume then
				sound.setVolume(i, note.volume)
				channelsVolume[i] = note.volume
			end
			if note and note.waveType then
				sound.setWave(i, note.waveType)
			end
		end
		if note then
			if note.volume then
				sound.setVolume(i, note.volume)
				channelsVolume[i] = note.volume
			elseif note.waveType then
				sound.setWave(i, note.waveType)
			else
				if time >= note.start and not note.played then
					if i <= cardChannels then
						if note.frequency == 0 then
							sound.setFrequency(i, 0)
						else
							sound.setADSR(i)
							sound.setADSR(i, 0, 250, 0.3, 100)
							sound.setVolume(i, channelsVolume[i])
							sound.setFrequency(i, note.frequency)
						end
					end
					note.played = true
				end
				--print("note dur of " .. channelIdx[i] .. " = " .. note.duration)
				--for k in pairs(note) do print(k .. " = " .. note[k]) end
				local dur = (note.start + note.duration) - time
				minDur = math.min(minDur, dur)
				if dbg then
					dbg.out():write("At " .. time .. "ms play note " .. note.frequency .. "Hz for " .. note.duration .. "ms"
						.. " (=" .. dur .. " ms) on channel " .. i .. " (note start is " .. note.start .. "ms)")
				end
			end
		end
	end
	if minDur >= lastProcess - time + BUFFER_MSECS then minDur = lastProcess - time + BUFFER_MSECS end
	if minDur <= 0 then minDur = 1 end
	if minDur == math.huge then
		goto continue
	end
	time = time + minDur
	sound.delay(math.floor(minDur / SPEED))
	if dbg then
		dbg.out():write("Effective minDur = " .. math.floor(minDur))
	end
	if time - lastProcess > BUFFER_MSECS then
		local refreshed = false
		while not sound.flush() do
			os.sleep(0)
		end
		timeLabel:setText("Time: " .. formatTime(math.floor(time/1000)) .. " / " .. formatTime(math.floor(songDuration/1000)))
		if time > songDuration then
			break
		end
		local ok, err = pcall(timeLabel.redraw, timeLabel)
		if not ok then
			print(err)
		end
		refreshed = true
		lastProcess = time
	end
	::continue::
end
