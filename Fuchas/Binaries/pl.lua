-- Process List
print("Active Processes:")
print("Uptime: " .. computer.uptime() .. " seconds")
coroutine.yield() -- let time to update metrics
local total = 0
for k, p in pairs(require("tasks").getProcesses()) do
    print("\t" .. p.name .. " - PID = " .. p.pid .. " - CPU time: " .. p.cpuTime .. "ms - CPU load: " .. tostring(p.cpuLoadPercentage):sub(1,5) .. "%")
    total = total + p.cpuLoadPercentage
end
print("Total CPU load: " .. tostring(total):sub(1,5) .. "%")