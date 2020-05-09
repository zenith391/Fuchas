-- Concert Task Manager (CSysGuard)

local tasks = require("tasks")
local draw = require("OCX/OCDraw")
local ui = require("OCX/OCUI")
local win = require("Concert/wins").newWindow(50, 16, "Task Manager")

tasks.newProcess("csysguard", function()
	while true do
		if not win.visible then
			break
		end
		win.container:render() -- update
		os.sleep(0.2)
	end
end)

do
	local comp = ui.component()
	comp.render = function(self)
		self:initRender()
		self.canvas.fillRect(1, 1, self.width, self.height, self.background)
		for k, pid in pairs(tasks.getPIDs()) do
			local x = 1
			local metrics = tasks.getProcessMetrics(pid)
			self.canvas.drawText(x, k, metrics.name, 0)
			x = x + metrics.name:len() + 2
			self.canvas.drawText(x, k, tostring(math.floor(metrics.cpuLoadPercentage)) .. "%", 0)
			x = x + tostring(math.floor(metrics.cpuLoadPercentage)):len() + 3 -- + "%""
			--self.canvas.drawText(x, k, tostring(metrics.lastCpuTime) .. "ms", 0)
			--x = x + tostring(metrics.lastCpuTime):len() + 4 -- + "ms"
			self.canvas.drawText(x, k, tostring(metrics.cpuTime) .. "ms", 0)
		end
		draw.drawContext(self.context)
	end
	comp.background = 0xFFFFFF
	win.container = comp
end

win:show()
