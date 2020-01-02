-- Process List
print("Active Processes:")
print("Uptime: " .. computer.uptime())
for k, p in pairs(require("tasks").getProcesses()) do
    print("\t" .. p.name .. " - PID = " .. p.pid .. " - CPU Time: " .. p.cpuTime .. "ms - CPU Percentage: " .. p.cpuPercentage .. "%")
end
