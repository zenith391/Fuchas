-- executes command as "admin" (* permission)
local security = require("security")
local shell = require("shell")
local args = table.pack(...)
local cmd = args[1]
table.remove(args, 1)
if args.n then args.n = args.n - 1 end
local res = shell.resolve(cmd)
security.requestPermission("*")
loadfile(res)(table.unpack(args))
