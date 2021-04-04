local draw = require("OCX/OCDraw")
local ui = require("OCX/OCUI")
local window = require("window").newWindow(50, 16, "Media Player") 

window:show()

local file = io.open("A:/Fuchas/Interfaces/Concert/song.mid", "r")
--local file = require("filesystem").open("A:/Fuchas/Interfaces/Concert/song.mid", "r")

local function readVarInt(stream)
	local num = 0
	local bytes = 0
	while true do
		if bytes == 4 then
			error("too many bytes in varint")
		end
		local byte = string.byte(stream:read(1))
		if byte & 0x80 == 0 then
			break
		end
		num = (num << 7) | (byte & 0x7F)
		bytes = bytes + 1
	end
	return num, bytes
end

local function readSInt(stream, bytes)
	return string.unpack(">i" .. bytes, stream:read(bytes))
end

local function readUInt(stream, bytes)
	return string.unpack(">I" .. bytes, stream:read(bytes))
end

local function readChunkMetadata(stream)
	local id = stream:read(4)
	local size = stream:readUInt(4)
	return {
		id   = id,
		size = size
	}
end

file.readVarInt = readVarInt
file.readUInt = readUInt
file.readSInt = readSInt
file.readChunkMetadata = readChunkMetadata

if readChunkMetadata(file).id ~= "MThd" then
	error("header isn't at the start of the MIDI file")
end

local formatType = file:readUInt(2)
local numberOfTracks = file:readUInt(2)
local timeDivision = file:readUInt(2) -- assumed to be ticks per beat

local function readTrack(stream)
	local meta = stream:readChunkMetadata()
	if meta.id ~= "MTrk" then
		error("invalid chunk type")
	end

	local bytesRead = 0
	local events = {}
	local lastStatus = 0

	while bytesRead < meta.size do
		local dt, dtRead = stream:readVarInt()
		bytesRead = bytesRead + dtRead
		local firstByte = stream:readUInt(1)
		bytesRead = bytesRead + 1

		if firstByte < 128 then
			firstByte = lastStatus -- running status
			bytesRead = bytesRead - 1
			stream:seek("cur", -1)
		end
		lastStatus = firstByte

		if firstByte == 0xFF then -- Meta Event
			local eventType = stream:readUInt(1)
			bytesRead = bytesRead + 1
			local length, lengthRead = stream:readVarInt()
			bytesRead = bytesRead + lengthRead
			local data = stream:read(length)
			bytesRead = bytesRead + length

			table.insert(events, {
				deltaTime = dt,
				type = "meta",
				subtype = eventType,
				data = data
			})
		elseif firstByte == 0xF0 or firstByte == 0xF7 then -- SysEx Event
			local length, lengthRead = stream:readVarInt()
			bytesRead = bytesRead + lengthRead
			local data = stream:read(length)
			bytesRead = bytesRead + length
		else
			local eventType = (firstByte >> 4) & 0xF
			local channel = firstByte & 0xF
			local parameters = { stream:readUInt(1) }
			bytesRead = bytesRead + 1
			if eventType ~= 0xC and eventType ~= 0xD then
				parameters[2] = stream:readUInt(1)
				bytesRead = bytesRead + 1
			end

			table.insert(events, {
				deltaTime = dt,
				type = "channel",
				subtype = eventType,
				channel = channel,
				parameters = parameters
			})
		end
	end
	print(bytesRead .. " / " .. meta.size)
	print("last: " .. require("liblon").sertable(events[#events-1]))
	print("t: " .. stream:read(1))

	return events
end

print("format " .. formatType .. " with " .. numberOfTracks .. " tracks")

local tracks = {}
local beats = 1
local bpm = 120

for i=1, numberOfTracks do
	print("reading track #" .. i)
	tracks[i] = {
		events = readTrack(file),
		bpm = 120,
		pos = 1
	}
end

while window.visible do
	local proceeded = false
	local sleepTime = math.huge

	for _, track in pairs(tracks) do
		if trackPos < maxLength then
			proceeded = true
			local note = track[track.pos]

			if note.type == "channel" then
				if note.deltaTime > 0 then
					sleepTime = math.min(note.deltaTime, sleepTime)
				end

				if note.subtype == 0x08 then -- Note Off
					--print(string.format("0x%x %x", note.subtype, note.parameters[1]))
				elseif note.subtype == 0x09 then -- Note On
					print(string.format("0x%x %x", note.subtype, note.parameters[1]))
				else
					print(string.format("0x%x", note.subtype))
				end
			end

			track.pos = track.pos + 1
		end
	end
	if sleepTime ~= math.huge then
		os.sleep((sleepTime / (bpm*4)) * 5)
		time = time + sleepTime
	end

	if not proceeded then
		break
	end
end
