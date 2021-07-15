local tasks = require("tasks")
local shell = require("shell")
local text  = require("text")
local args, ops = shell.parse(...)

if ops.h or ops.help then
	print("pl [-h|--help] [-r] [--old]")
	print("\tShows a list of all running processes.")
	print("Flags:")
	print("\t--help")
	print("\t-h    : Shows this help message")
	print("\t-r    : Raw output, meant for scripts")
	print("\t--old : Old output, to be removed")
	return
end

coroutine.yield() -- let time to update metrics

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
	local cpuLoadTotal = 0
	local data = {
		["Name"]     = {},
		["PID"]      = {},
		["CPU load"] = {},
		["CPU time"] = {},
		["Status"]   = {}
	}
	for _, pid in pairs(tasks.getPIDs()) do
		local m = tasks.getProcessMetrics(pid)
		table.insert(data["Name"], m.name)
		table.insert(data["PID"], pid)
		table.insert(data["CPU load"], m.cpuLoadPercentage .. "%")
		table.insert(data["CPU time"], m.cpuTime .. "ms")
		table.insert(data["Status"], m.status)
		cpuLoadTotal = cpuLoadTotal + m.cpuLoadPercentage
	end
	print("Uptime: " .. computer.uptime() .. " seconds")
	print("Total CPU load: " .. tostring(cpuLoadTotal):sub(1,5) .. "%")
	print(
		text.formatTable(data, { "Name", "PID", "CPU load", "CPU time", "Status" })
	)
end
