local cp = _G.component.unrestricted
local fcp = require("component")

function cp.getPrimary()
	return fcp.getPrimary()
end

return cp
