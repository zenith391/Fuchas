-- Concert Task Manager (CSysGuard)

local tasks = require("tasks")
local draw = require("OCX/OCDraw")
local ui = require("OCX/OCUI")
local window = require("window").newWindow(70, 23, "NeoQuack")
local gpu = require("driver").gpu

local fileName = ...
fileName = fileName or "A:/Fuchas/Interfaces/Concert/Applications/editor.lua"

local tabBar = ui.tabBar()
local config = {
	tabWidth = 4
}

local function createTextEditor()
	local textEditor = ui.component()
	textEditor.background = 0xFFFFFF
	textEditor.foreground = 0x000000
	textEditor.text = ""

	function textEditor:_render()
		self.canvas.fillRect(1, 1, self.width, self.height, self.background)
		local y = 1
		local text = self.text
		for line in text:gmatch("([^\n]*)\n?") do
			line = line:gsub("\t", (" "):rep(config.tabWidth))
			self.canvas.drawText(1, y, line, self.foreground, self.background)
			y = y + 1
		end
	end

	return textEditor
end

local function openText(name, text)
	checkArg(1, name, "string")
	checkArg(2, text, "string")
	local editor = createTextEditor()
	editor.text = text
	tabBar:addTab(editor, name)
end

local file = io.open(fileName, "r")
local text = file:read("*a")
file:close()
openText("editor.lua", text)

window.container = tabBar

window:show()
while window.visible do
	os.sleep(10)
end
