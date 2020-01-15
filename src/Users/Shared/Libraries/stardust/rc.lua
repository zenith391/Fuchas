-- Just a support API, no "rc" services are active
local lib = {}

function lib.unload(name)
	error("no module loaded")
end

return lib