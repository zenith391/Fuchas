local lib = {}
local windowing = require("window")
local ui = require("OCX/OCUI")

function lib.showErrorMessage(message, title, asynchronous)
	local width = math.max(message:len() + 2, 10)
	local dialog = windowing.newWindow(width, 6, title or "Error")
	local text = ui.label(message)
	text.x = 2; text.y = 2
	dialog.container:add(text)

	local close = ui.button("Close", function()
		dialog:dispose()
	end)
	close.x = width - 7
	close.y = 4
	dialog.container:add(close)

	dialog:show()
	while dialog.visible and not asynchronous do
		os.sleep(1)
	end
end

return lib
