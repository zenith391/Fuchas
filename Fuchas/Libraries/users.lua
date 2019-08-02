local user = {}
local users = {}
local security = require("security")
local hashes = {
	sha256 = require("sha256")
}
local lib = {}

local function retrieveUsers()
    for k, v in fs.list("A:/Users") do
		local configStream = io.open("A:/Users/" .. k .. "/account.lon")
		if configStream then
			local config = require("liblon").loadlon(configStream)
			configStream:close()
			table.insert(users, {
				name = config.name,
				password = config.password,
				security = config.security,
                level = config.level
			})
		end
	end
end

function lib.login(username, passwd)
	if not security.hasPermission("users.login") then
		return false, "missing permission: users.login"
	end
	for _, v in pairs(users) do
		if v.name == username then
			if v.security ~= "none" and hashes[v.security] then
				local algo = hashes[v.security]
				local hash = algo(passwd)
				if v.password == hash then
					user = v
					return true
				else
					return false, "invalid password"
				end
			end
		end
	end
	return false, "invalid username"
end

retrieveUsers()

return lib
