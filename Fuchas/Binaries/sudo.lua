-- executes command as "admin" (* permission)
local security = require("security")
local args = table.pack(...)
local cmd = args[1]
table.remove(args, 1)