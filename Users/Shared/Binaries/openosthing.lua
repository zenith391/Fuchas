local component = require("component")
local term = require("term")
local gpu = component.gpu
term.setCursor(1, 11)
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)
gpu.fill(1, 1, 20, 10, "X")
term.write("I just filled!\n")
