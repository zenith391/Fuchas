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
		--os.sleep(0.5)
		coroutine.yield()
	end
end)

do
	local comp = ui.component()
	comp.render = function(self)
		self:initRender()
		self.canvas.fillRect(1, 1, self.width, self.height, self.background)
		for k, v in pairs(tasks.getProcesses()) do
			local x = 1
			self.canvas.drawText(x, k, v.name)
			x = x + v.name:len() + 2
			self.canvas.drawText(x, k, tostring(math.floor(v.cpuPercentage)) .. "%")
			x = x + tostring(math.floor(v.cpuPercentage)):len() + 3 -- + "%""
			self.canvas.drawText(x, k, tostring(v.lastCpuTime) .. "ms")
			x = x + tostring(v.lastCpuTime):len() + 4 -- + "ms"
			self.canvas.drawText(x, k, tostring(v.cpuTime) .. "ms")
		end
		draw.drawContext(self.context)
	end
	comp.background = 0xFFFFFF
	win.container = comp
end

win:show()
