local shell = require("shell")
local fs = require("filesystem")

local args, options = shell.parse(...)

print("format [-e] drive:")
print("  -e: Erase all the drive")