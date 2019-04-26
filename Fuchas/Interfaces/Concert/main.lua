-- Main UI file for the Operating System frontend UI (optional)
local wins = require("Concert/wins")
local event = require("event")
local draw = require("OCX/OCDraw")

local windows = wins.windowingSystem()

local ctx = draw.newContext(0, 0, 160, 50)
local canvas = draw.canvas(ctx)
local test = wins.newWindow()
local taskBar = wins.newWindow()

windows.setCanvas(canvas)
windows.setUndecorated(taskBar, true)
windows.setPosition(taskBar, 0, 50)
windows.setSize(taskBar, 160, 1)

canvas.fillRect(0, 0, 160, 50, 0xAAAAAA)

function w(name, addr, x, y, button, player)
	local wx, wy = windows.getPosition(test)
	local ww, wh = windows.getSize(test)
	canvas.fillRect(wx, wy, ww, wh, 0xAAAAAA)
	windows.setPosition(test, x, y)
	windows.renderWindow(test, canvas)
	windows.renderWindow(taskBar, canvas)
	canvas.drawText(1, 1, "ram: " .. math.floor((computer.totalMemory() - computer.freeMemory()) / computer.totalMemory() * 100) .. "%, free: " .. (computer.freeMemory() / 1024) .. "K", 0xFFFFFF)
	draw.drawContext(ctx)
end

function run()
	local draw = require("OCX/OCDraw")
	windows.setTitle(test, "Test Window")
	coroutine.yield()
end

w("touch", "", 10, 20, 1, nil)
while true do
	local name, addr, x, y, button, player = event.pull()
	if name == "touch" or name == "drag" then
		w(name, addr, x, y, button, player)
	end
	run()
end