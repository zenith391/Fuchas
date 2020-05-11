local spec = {}
local cp = ...

function spec.isCompatible(address)
	return cp.proxy(address).type == "printer" and cp.proxy(address).newPage
end

function spec.getName()
	return "CC Printer w/ Adapter v1.0"
end

function spec.getRank()
	return 1
end

function spec.new(address)
	local out = nil
	local outbuf = ""
	printer = cp.proxy(address)

	function drv.getStatistics()
		local pw, ph = printer.getPageSize()
		return {
			paperLevel = printer.getPaperLevel(),
			blackInkLevel = printer.getInkLevel(),
			pageWidth = pw,
			pageHeight = ph
		}
	end

	function drv.out()
		if out == nil then
			out = {
				write = function(self, str)
					printer.write(str)
				end,
				flush = function(self)
					if outbuf ~= nil then
						printer.write(outbuf)
					end
				end,
				print = function(self)
					self.flush()
					return printer.endPage()
				end
			}
		end
	end
end

return spec