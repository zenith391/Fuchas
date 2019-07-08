local shell = require("shell")

while true do
	write(" > ")
	local ck, err = load(shell.read(), "usercode")
	write("\n ")
	if ck == nil then
		print(err)
	else
		try(function()
        ck()
    end)
    .catch(function(err)
        print(err)
    end)
	end
end