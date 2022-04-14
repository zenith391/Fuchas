local spec = {}
local cp = ...

function spec.isCompatible(address)
	return cp.proxy(address).type == "ocemu"
end

function spec.getName()
	return "OCEmu logging driver"
end

function spec.getRank()
	return 1
end

function spec.new(address)
	local drv = {}
	local ocemu = cp.proxy(address)

	function drv.out()
		if out == nil then
			out = {
				write = function(self, str)
					ocemu.log(str)
				end,
				flush = function(self) end,
			}
		end
		return out
	end

	return drv
end

return spec