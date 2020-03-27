local args = require("shell").parse(...)
print(table.concat(args, " "))
