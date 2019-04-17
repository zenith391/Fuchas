-- Process List
print("Active Processes:")
for k, p in pairs(shin32.getProcesses()) do
	if p == shin32.getCurrentProcess() then
		print("\tCURRENT - " .. p.name .. " - PID = " .. p.pid)
	else
		print("\t" .. p.name .. " - PID = " .. p.pid)
	end
end