-- Concert Explorer
local UI = require("OCX/OCUI")
local filesystem = require("filesystem")
local Concert = require("concert")
local window = require("window").newWindow(50, 16, "Explorer")

local container = window.container
container.layout = UI.LineLayout({ spacing = 0 })

local list = UI.list()

for path in filesystem.list("A:/") do
	local listItem = UI.listItem(path)
	list:addItem(listItem)
end
container:add(list)

window:show()
while window.visible do
	os.sleep(1)
end
 
