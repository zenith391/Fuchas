-- Flarefox WWW Browser

local draw = require("OCX/OCDraw")
local ui = require("OCX/OCUI")
local wink = dofile("A:/Users/Shared/Binaries/Flarefox/wink.lua")

local internet = require("driver").internet
local url = "https://drewdevault.com/2022/05/09/hare-ssh.html"
--local url = "https://www.lua.org/manual/5.3/manual.html"
--local url = "https://zig.run"
local page = internet.readFully(url)

local root = wink.html.parse(page)

if os.getenv("INTERFACE") == "Concert" then
	local window = require("window").newWindow(70, 25, "Flarefox")
	window:show()

	while window.visible do
		os.sleep(0.05)
	end
else
	print("text: " .. tostring(root):sub(1, 1000))

	io.stderr:write("TODO: Flarefox UI on " .. (os.getenv("INTERFACE") or "current interface") .. "\n")
end
