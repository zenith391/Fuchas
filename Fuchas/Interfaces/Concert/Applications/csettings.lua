-- Concert Settings (CSettings)
local UI = require("OCX/OCUI")

local window = require("window").newWindow(50, 16, "Settings")
local container = window.container
container.layout = UI.LineLayout({ spacing = 0 })

local check = UI.checkBox("Background", function() end)
check.x = 2
container:add(check)

window:show()
while window.visible do
	os.sleep(1)
end
