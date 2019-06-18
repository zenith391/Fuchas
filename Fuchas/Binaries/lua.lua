local shell = require("shell")

while true do
	write(" > ")
	local ck, err = load(shell.read(), "usercode")
	write("\n ")
	if ck == nil then
		print(err)
	else
		ck()
	end
end