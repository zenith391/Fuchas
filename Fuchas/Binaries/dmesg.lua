while true do
	local t = table.pack(require("event").pull())
	if t[1] == "interrupt" then
		break
	end
	print(table.concat(t, "\t"))
end
