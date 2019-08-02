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
			if type(tab[1]) == "table" then
				print(require("liblon").sertable(tab[1]))
			else
				print(table.unpack(tab))
			end
		end)
		.catch(function(err)
			print(err)
		end)
	end
end
