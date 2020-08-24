local tasks = require("tasks")
local shell = require("shell")
local args, ops = shell.parse(...)

if ops.h or ops.help then
	print("ps [-h|--help] [-r] [--old]")
	print("\tShows a list of all running processes.")
	print("Flags:")
	print("\t--help")
	print("\t-h    : Shows this help message")
	print("\t-r    : Raw output, meant for scripts")
	print("\t--old : Old output, to be removed")
	return
end

coroutine.yield() -- let time to update metrics

local function padRight(text, len)
	if #text < len then
		text = text .. (" "):rep(len-#text)
	end
	return text
end

local function fract(num)
	return num - math.floor(num)
end

local function padCenter(text, len)
	len = len - #text
	local leftRep = (" "):rep(math.ceil(len/2))
	local rightLen = math.ceil(len/2)
	if fract(len/2) >= 0.5 then
		rightLen = rightLen - 1
	end
	local rightRep = (" "):rep(rightLen)
	return leftRep .. text .. rightRep
end

local minNameLength = 4+2
local minPIDLength = 3+2
local minLoadLength = 8+2
local minStatusLength = 6+2
local minTimeLength = 8+2
local total = 0

if ops.old then
	print("Active Processes:")
	for _, pid in pairs(tasks.getPIDs()) do
		local m = tasks.getProcessMetrics(pid)
	    print("\t" .. m.name .. " - PID = " .. pid .. " - CPU time: " .. m.cpuTime .. "ms - CPU load: " .. tostring(m.cpuLoadPercentage):sub(1,5) .. "%" .. " - Status: " .. m.status:upper())
	end
elseif ops.r then
	for _, pid in pairs(tasks.getPIDs()) do
		local m = tasks.getProcessMetrics(pid)
	    print(pid .. " " .. m.name)
	end
else
	print("Uptime: " .. computer.uptime() .. " seconds")
	print("Total CPU load: " .. tostring(total):sub(1,5) .. "%")

	for _, pid in pairs(tasks.getPIDs()) do
		local m = tasks.getProcessMetrics(pid)
		minNameLength = math.max(minNameLength, #m.name+2)
		minPIDLength = math.max(minPIDLength, #tostring(pid)+2)
		minLoadLength = math.max(minLoadLength, #(tostring(m.cpuLoadPercentage):sub(1,5))+2)
		minStatusLength = math.max(minStatusLength, #m.status+2)
		minTimeLength = math.max(minTimeLength, #tostring(m.cpuTime)+4)
		total = total + m.cpuLoadPercentage
	end

	print(("-"):rep(minNameLength+minPIDLength+minLoadLength+minStatusLength+minTimeLength+6))
	io.write("|" .. padCenter("Name", minNameLength) .. "|")
	io.write(padCenter("PID", minPIDLength) .. "|")
	io.write(padCenter("CPU load", minLoadLength) .. "|")
	io.write(padCenter("CPU time", minTimeLength) .. "|")
	io.write(padCenter("Status", minStatusLength) .. "|")
	io.write("\n")
	io.write("|" .. ("-"):rep(minNameLength) .. "|")
	io.write(("-"):rep(minPIDLength) .. "|")
	io.write(("-"):rep(minLoadLength) .. "|")
	io.write(("-"):rep(minTimeLength) .. "|")
	io.write(("-"):rep(minStatusLength) .. "|")
	io.write("\n")

	for _, pid in pairs(tasks.getPIDs()) do
		local m = tasks.getProcessMetrics(pid)
	    io.write("|" .. padCenter(m.name, minNameLength) .. "|")
	    io.write(padCenter(tostring(pid), minPIDLength) .. "|")
	    io.write(padCenter(tostring(m.cpuLoadPercentage):sub(1,5), minLoadLength) .. "|")
	    io.write(padCenter(tostring(m.cpuTime).."ms", minTimeLength) .. "|")
	    io.write(padCenter(m.status, minStatusLength) .. "|")
	    io.write("\n")
	    --" - PID = " .. pid .. " - CPU time: " .. m.cpuTime .. "ms - CPU load: " .. tostring(m.cpuLoadPercentage):sub(1,5) .. "%" .. " - Status: " .. m.status:upper())
	end

	print(("-"):rep(minNameLength+minPIDLength+minLoadLength+minStatusLength+minTimeLength+6))
end
