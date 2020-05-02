local tasks = require("tasks")

print("Active Processes:")
print("Uptime: " .. computer.uptime() .. " seconds")
coroutine.yield() -- let time to update metrics
local total = 0
for _, pid in pairs(tasks.getPIDs()) do
	local m = tasks.getProcessMetrics(pid)
    print("\t" .. m.name .. " - PID = " .. pid .. " - CPU time: " .. m.cpuTime .. "ms - CPU load: " .. tostring(m.cpuLoadPercentage):sub(1,5) .. "%" .. " - Status: " .. m.status:upper())
    total = total + m.cpuLoadPercentage
end
print("Total CPU load: " .. tostring(total):sub(1,5) .. "%")
