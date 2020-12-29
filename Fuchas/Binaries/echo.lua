local args, ops = require("shell").parse(...)
if ops.s then
	while true do
		local line = io.stdin:read("l")
		if not line or #line == 0 then break end
		print(line)
	end
else
	for k, v in pairs(args) do
		io.stdout:write(v)
		if k < #args then
			io.stdout:write(" ")
		end
	end
end

if not ops.n and not ops.s then
	print()
end
