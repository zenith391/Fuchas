local user = nil
local users = {}
local security = require("security")
local fs = require("filesystem")
local hashes = {
	["sha3-256"] = require("sha3").sha256,
	["sha3-512"] = require("sha3").sha512
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
				pathName = config.pathName,
				password = config.password,
				security = config.security,
			})
		end
	end
end

function lib.getSharedUserPath()
	return "A:/Users/Shared"
end

function lib.getUserPath()
	if user == nil then
		return lib.getSharedUserPath()
	else
		return "A:/Users/" .. user.pathName or user.name
	end
end

function lib.getUser()
	return user
end

-- Logouts and set account to guest (Shared).
function lib.logout()
	if user ~= nil then
		if not not security.hasPermission("users.logout") then
			return false, "missing permission: users.logout"
		end
	end
	user = nil
	os.setenv("USER", "guest")
	return true
end

function lib.login(username, passwd)
	if user ~= nil and not security.hasPermission("users.logout") then
		local ok, reason = lib.logout()
		if not ok then
			return ok, reason
		end
	end
	for _, v in pairs(users) do
		if v.name == username then
			if v.security ~= "none" and hashes[v.security] then
				local algo = hashes[v.security]
				local hash = algo("$@^PO!°]" .. passwd) -- salt + passwd; salt against rainbow tables
				if v.password == hash then
					user = v
					os.setenv("USER", user.name)
					return true
				else
					return false, "invalid password"
				end
			elseif v.security == "none" then
				user = v
				os.setenv("USER", user.name)
				return true
			end
		end
	end
	return false, "invalid username"
end

retrieveUsers()

return lib
