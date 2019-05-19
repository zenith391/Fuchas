local cui = require("OCX/ConsoleUI")
local gpu = component.getPrimary("gpu")
local hasAccount = false
local choosing = false
local entries = {}

local function detectEntries()
	for k, v in pairs(require("filesystem").list("A:/Fuchas/Interfaces")) do
		table.insert(entries, v)
	end
end

gpu.setResolution(50, 16)
cui.clear(0xAAAAAA)
cui.drawBorder(1, 1, 49, 15)

while true do
	local i = 1
	while i < #entries+1 do
		local entry = entries[i]
		gpu.set(2, i + 1, entry)
		i = i + 1
	end
	local id, a, b, c, d = require("event").pull()
end