-- Concert Task Manager (CSysGuard)

local tasks = require("tasks")
local draw = require("OCX/OCDraw")
local ui = require("OCX/OCUI")
local window = require("window").newWindow(50, 16, "Task Manager")
local gpu = require("driver").gpu

local processTab = ui.component()
processTab.background = 0xFFFFFF
processTab.render = function(self)
	self.canvas.fillRect(1, 1, self.width, self.height, self.background)

	for k, pid in pairs(tasks.getPIDs()) do
		local x = 1
		local y = k
		local metrics = tasks.getProcessMetrics(pid)

		self.canvas.drawText(x, y, metrics.name, 0)
		x = x + metrics.name:len() + 2
		self.canvas.drawText(x, y, tostring(math.floor(metrics.cpuLoadPercentage)) .. "%", 0)
		x = x + tostring(math.floor(metrics.cpuLoadPercentage)):len() + 3
		self.canvas.drawText(x, y, tostring(metrics.cpuTime) .. "ms", 0)
	end
end

local metricsTab = ui.component()
metricsTab.background = 0xFFFFFF
metricsTab.render = function(self)
	self.canvas.fillRect(1, 1, self.width, self.height, self.background)

	local usedMem = math.floor((computer.totalMemory() - computer.freeMemory()) / 1024)
	local totalMem = math.floor(computer.totalMemory() / 1024)
	self.canvas.drawText(1, 1, "RAM  : " .. usedMem .. " / " .. totalMem .. "KiB used", 0)

	local gpuStats = gpu.getStatistics()
	local gpuCaps  = gpu.getCapabilities()
	if gpuCaps.hardwareBuffers then
		local usedKb   = gpuStats.usedMemory / 1000
		local totalKb  = gpuStats.totalMemory / 1000
		self.canvas.drawText(1, 2, "VRAM : " .. tostring(usedKb) .. "/" .. tostring(totalKb) .. "KB used", 0)
	else
		self.canvas.drawText(1, 2, "VRAM : no", 0)
	end
end

local tabBar = ui.tabBar()
tabBar:addTab(processTab, "Processes")
tabBar:addTab(metricsTab, "Metrics")
window.container = tabBar

window:show()
while window.visible do
	window:update()
	os.sleep(1)
end
