local spec = {}
local cp = ...

function spec.isCompatible(address)
	return cp.proxy(address).type == "openprinter"
end

function spec.getName()
	return "OpenPrinter Fuchas Driver"
end

function spec.getRank()
	return 1
end

function spec.new(address)
	local drv = {}
	local out = nil
	local outbuf = ""
	local printer = cp.proxy(address)

	function drv.getStatistics()
		return {
			blackInkLevel = printer.getBlackInkLevel(),
			colorInkLevel = printer.getColorInkLevel(),
			inkLevel = printer.getBlackInkLevel() + printer.getColorInkLevel(),
			maxBlackInkLevel = 4000,
			maxColorInkLevel = 4000,
			maxInkLevel = 8000,
			paperLevel = printer.getPaperLevel(),
			maxPaperLevel = 256
		}
	end

	function drv.out()
		if out == nil then
			out = {
				write = function(self, str)
					local ln = table.pack(string.find(str, "\n", 1, true))
					local last = 1
					for k, v in ipairs(ln) do
						if outbuf ~= nil then
							printer.writeln(outbuf)
							outbuf = nil
						end
						printer.writeln(string.sub(last, v))
						last = v+1
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
		return out
	end

	return drv
end

return spec