local shell = require("shell")

while true do
	io.write(" > ")
	local ck, err = load("return " .. shell.read(), "usercode")
	io.write("\n ")
	if ck == nil then
		print(err)
	else
		try(function()
			local tab = table.pack(ck())
			print(table.unpack(tab))
		end)
		.catch(function(err)
			print(err)
		end)
	end
end