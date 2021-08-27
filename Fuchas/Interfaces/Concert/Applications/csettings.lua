-- Concert Settings (CSettings)

local win = require("window").newWindow(50, 16, "Settings")
win:show()

while win.visible do
	os.sleep()
end
