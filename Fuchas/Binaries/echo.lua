local args = require("shell").parse(...)

for k, v in pairs(args) do
	io.stdout:write(v)
	if k < #args then
		io.stdout:write(" ")
	end
end
print()
