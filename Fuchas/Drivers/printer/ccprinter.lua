local spec = {}
local cp = ...

function spec.isCompatible(address)
	return cp.proxy(address).type == "adapter" -- TODO: check if it's CC printer?
end

function spec.getName()
	return "ComputerCraft Printer Driver 1.0"
end

function spec.getRank()
	return 1
end

function spec.new(address)
	local out = nil
	local outbuf = ""
	printer = cp.proxy(address)

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
end

return spec