local shell = require("shell")

print(_VERSION .. " Copyright (C) 1994-2016 Lua.org, PUC-Rio")
print("Add '=' at the start of your code to print the result")
print("Type 'os.exit()' or '\\q' to exit the interpreter.")

while true do
	io.write("> ")
	local txt = shell.read()
	io.write("\n ")
	if string.startsWith(txt, "\\q") then
		break
	end
	if string.startsWith(txt, "=") then
		txt = "return " .. txt:sub(2)
	end
	local ck, err = load(txt, "stdin")
	if ck == nil then
		io.stderr:write(err .. "\n")
	else
		xpcall(function()
			local tab = table.pack(ck())
			if type(tab[1]) == "table" then
				print(require("liblon").sertable(tab[1]))
			else
				print(table.concat(tab, "\t"))
			end
		end, function(err)
			io.stderr:write(err .. "\n")
			io.stderr:write(debug.traceback(nil, 2))
		end)
	end
end
