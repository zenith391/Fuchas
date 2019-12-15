local shell = require("shell")
local args, ops = shell.parse(...)

if #args < 1 then
	for k, v in pairs(os.getenvs()) do
		print(k .. "=" .. v)
	end
else
	local pos = string.find(args[1], '=')
	if pos then
		local name = args[1]:sub(1,pos-1)
		local val = args[1]:sub(pos+1)
		print("Set " .. name .. " to " .. val)
		os.setenv(name, val)
	else
		if os.getenv(args[1]) then
			print(tostring(os.getenv(args[1])))
		else
			print("No environment variable with name \"" .. args[1] .. "\"")
		end
	end
end