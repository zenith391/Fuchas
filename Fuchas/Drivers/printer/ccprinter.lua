local spec = {}
local cp = ...

function spec.isCompatible(address)
	return cp.proxy(address).type == "printer" and cp.proxy(address).newPage
end

function spec.getName()
	return "CC Printer Fuchas driver"
end

function spec.getRank()
	return 1
end

function spec.new(address)
	local out = nil
	local outbuf = ""
	local inPage = false
	printer = cp.proxy(address)

	function drv.getStatistics()
		local pw, ph = printer.getPageSize()
		return {
			paperLevel = printer.getPaperLevel(),
			blackInkLevel = printer.getInkLevel(),
			inkLevel = printer.getInkLevel(),
			maxInkLevel = 64,
			maxBlackInkLevel = 64,
			maxPaperLevel = 64,
			pageWidth = pw,
			pageHeight = ph
		}
	end

	function drv.out()
		if out == nil then
			out = {
				write = function(self, str)
					if not inPage then
						inPage = printer.newPage()
						if not inPage then
							if printer.getInkLevel() == 0 then
								error("out of ink")
							elseif printer.getPaperLevel() == 0 then
								error("out of paper")
							else
								error("unknown printer error")
							end
						end
					end
					local start = string.find(str, "\n")
					local e
					if start then
						e = string.sub(str, start+1)
						str = str:sub(1, start-1)
					end
					printer.write(str)
					if start then
						local x, y = printer.getCursorPos()
						local w, h = printer.getPageSize()
						if y+1 > h then
							if not printer.endPage() then
								error("could not print the current page")
							end
							inPage = printer.newPage()
							if not inPage then
								if printer.getInkLevel() == 0 then
									error("out of ink")
								elseif printer.getPaperLevel() == 0 then
									error("out of paper")
								else
									error("unknown printer error")
								end
							end
						else
							printer.setCursorPos(x, y+1)
						end
						printer.write(e)
					end
				end,
				flush = function(self) end,
				print = function(self)
					inPage = false
					return printer.endPage()
				end
			}
		end
		return out
	end
end

return spec