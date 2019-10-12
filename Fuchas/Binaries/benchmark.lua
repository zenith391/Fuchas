local computer = computer
local driver = require("driver")
--local gpu = component.gpu
local gpu = driver.getDriver("gpu")
local benchmarkTime = 1
local args, ops = require("shell").parse(...)

if #args > 0 then
	benchmarkTime = tonumber(args[1])
end

function benchmark(func)
	local start = computer.uptime()
	local funcStart = computer.uptime()
	func()
	local time = computer.uptime() - funcStart
	while computer.uptime() < start+benchmarkTime do
		local funcStart = computer.uptime()
		func()
		local funcTime = computer.uptime() - funcStart
		time = (time + funcTime) / 2
	end
	coroutine.yield()
	return time
end

print("Benchmarking..")
print("  - Event Pulling / Task Switch..")
time = benchmark(function()
	computer.pullSignal(0)
end)
print("      Average Time: " .. time)
print("  - 100000 Lua loops (no call inside)..")
time = benchmark(function()
	for i=1, 100000 do
	end
end)
print("      Average Time: " .. time)

print("  - GPU (get)..")
time = benchmark(function()
	gpu.get(1, 1)
end)
print("      Average Time: " .. time)

local org = gpu.get(1, 1)
print("  - GPU (set)..")
time = benchmark(function()
	gpu.drawText(1, 1, 'T')
end)
gpu.set(1, 1, org)
print("      Average Time: " .. time)

print("  - GPU (fill, 160x1)..")
time = benchmark(function()
	gpu.fill(1, 1, 160, 1)
end)
print("      Average Time: " .. time)