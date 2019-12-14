local drv = {}
local out = nil
local outbuf = ""
local cp, printer = ...
printer = cp.proxy(printer)

function drv.out()
	if out == nil then
		out = {
			write = function(self, str)
				local ln = table.pack(string.find(str, "\n", 1, true))
				local last = 1
				for k, v in pairs(ln) do
					if k ~= "n" then
						if outbuf ~= nil then
							printer.writeln(outbuf)
							outbuf = nil
						end
						printer.writeln(string.sub(last, v))
						last = v+1
					end
				end
				if last < str:len() then
					outbuf = str:sub(last, str:len())
				end
			end,
			flush = function(self)
				if outbuf ~= nil then
					printer.writeln(outbuf)
				end
			end,
			print = function(self)
				self.flush()
				return printer.print()
			end
		}
	end
end

function drv.isCompatible()
	return printer and printer.type == "openprinter"
end

function drv.getName()
	return "OpenPrinter (" .. printer.address:sub(1, 3) .. ")"
end

function drv.getRank()
	return 1
end

return drv