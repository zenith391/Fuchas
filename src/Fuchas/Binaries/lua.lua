local shell = require("shell")

while true do
	io.write(" > ")
	local txt = shell.read()
	if string.startsWith(txt, "=") then
		txt = "return " .. txt:sub(2)
	end
	local ck, err = load(txt, "usercode")
	io.write("\n ")
	if ck == nil then
		print(err)
	else
		try(function()
			local tab = table.pack(ck())
			if type(tab[1]) == "table" then
				print(require("liblon").sertable(tab[1]))
			else
				print(table.concat(tab, "\t"))
			end
		end)
		.catch(function(ex)
			print(ex.details)
			io.stderr:write(ex.trace)
		end)
	end
end
