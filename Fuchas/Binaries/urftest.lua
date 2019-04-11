package.loaded["liburf"] = nil
local liburf = require("liburf")
local io = require("io")
local s = io.open("A:/test.urf", "w")

local arc = liburf.newArchive()
local f = liburf.newEntry(arc.root, "test.lua", false)
liburf.writeArchive(arc, s)

s:close()