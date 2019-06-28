local cui = require("OCX/ConsoleUI")
local fs = require("filesystem")
local gpu = component.gpu
local hasAccount = false
local choosing = false

local entries = {}
local users = {}

local function detectEntries()
	for k, v in fs.list("A:/Fuchas/Interfaces") do
		table.insert(entries, k)
	end
end

local function detectUsers()
	for k, v in fs.list("A:/Users") do
		local configStream = io.open("A:/Users/" .. k .. "/account.lon")
		local config = require("liblon").loadlon(configStream)
		configStream:close()
		table.insert(users, {
			name = config.name,
			password = config.password,
			security = "sha256"
		})
	end
end

detectEntries()
detectUsers()

gpu.setResolution(50, 16)
cui.clear(0xAAAAAA)
cui.drawBorder(1, 1, 49, 15)

local container = cui.container()
local loginBtn = cui.button("Login")
local userField = cui.textField()
local passField = cui.textField()
passField.y = 7
passField.x = 10

userField.y = 5
userField.x = 10

passField.width = 25
userField.width = 25

loginBtn.y = 15
loginBtn.x = 45
loginBtn.ontouch = function()
	gpu.setResolution(gpu.maxResolution())
	dofile("A:/Fuchas/Interfaces/Fushell/main.lua")
end

container.add(loginBtn)
container.add(passField)
container.add(userField)
container.render()

while true do
	local i = 1
	local t = table.pack(require("event").pull())
	container.event(t)
	container.render()
end