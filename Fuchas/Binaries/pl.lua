-- Process List
print("Active Processes:")
for k, p in pairs(shin32.getProcesses()) do
    print("\t" .. p.name .. " - PID = " .. p.pid)
end
