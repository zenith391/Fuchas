--- Users library
-- @module users
-- @alias lib

local lib = {}
local users = {}
local userKeys = {} -- keys to recognize user login
local security = require("security")
local filesystem = require("filesystem")
local tasks = require("tasks")
local hashes = {
	-- lazy-loaded, Lua 5.2-ers cannot login to a password-protected account
	["sha3-256"] = function(input)
		local bin = require("sha3").bin
		return bin.stohex(require("sha3").sha3.sha256(input))
	end,
	["sha3-512"] = function(input)
		local bin = require("sha3").bin
		return bin.stohex(require("sha3").sha3.sha512(input))
	end
}

local function retrieveUsers()
	for k, v in filesystem.list("A:/Users") do
		local configStream = io.open("A:/Users/" .. k .. "/account.lon")
		if configStream then
			local config = require("liblon").loadlon(configStream)
			configStream:close()
			table.insert(users, config)
		end
	end
end

local function userLogin(user)
	local curProc = tasks.getCurrentProcess()
	os.setenv("USER", user.name)
	local userKey
	while not userKey or userKeys[userKey] do
		userKey = string.format("%x", math.floor(math.random() * 0xFFFFFFFF))
	end
	userKeys[userKey] = {
		user = user,
		pid = curProc.pid
	}
	curProc.userKey = userKey
	security.initPermissions(curProc.pid)
end

--- Returns the shared user path
-- @treturn string shared user path
function lib.getSharedUserPath()
	return "A:/Users/Shared"
end

--- Returns the current user path
-- @treturn string current user path
function lib.getUserPath()
	if user == nil then
		return lib.getSharedUserPath()
	else
		return "A:/Users/" .. (user.pathName or user.name)
	end
end

--- Returns the user object for the given key and pid
-- @string key
-- @int pid
-- @treturn User current user
function lib.userForKey(key, pid)
	if userKeys[key] then
		if userKeys[key].pid == pid then
			return true, userKeys[key].user
		end
	end
	return false -- the key isn't valid
end

--- Internal function to create a user key to give to the child of current process
-- @number pid The PID of the child
function lib.createKeyForChild(pid)
	local user = lib.getUser()

	local userKey
	while not userKey or userKeys[userKey] do
		userKey = string.format("%x", math.floor(math.random() * 0xFFFFFFFF))
	end
	userKeys[userKey] = {
		user = user,
		pid = pid
	}

	return userKey
end

--- Returns the current user key
-- @treturn User current user
function lib.getUser()
	local curProc = tasks.getCurrentProcess()
	if curProc.userKey then
		local ok, user = lib.userForKey(curProc.userKey, curProc.pid)
		if not ok then
			error("invalid user key!")
		end
		return user
	end
	return nil
end

--- Logouts and set account to guest (Shared).
function lib.logout()
	os.setenv("USER", "guest")
	tasks.getCurrentProcess().userKey = nil
	return true
end

local function randomSalt(len)
	local binsalt = ""
	for i=1, len do
		binsalt = binsalt .. string.char(math.floor(math.random() * 255))
	end
	return binsalt
end

--- Get user object from ID
-- @int uid User ID
-- @treturn User
function lib.getById(uid)
	for _, user in pairs(users) do
		if user.userId == uid then
			local copy = {}
			for k, v in pairs(user) do
				copy[k] = v
			end
			return copy
		end
	end
	return nil, "no such user"
end

--- Register a new user
-- @string username
-- @tab ops
-- @string ops.password The new user's password
-- @string[opt="sha3-512"] ops.algorithm The algorithm for hashing the password
function lib.createUser(username, ops)
	local passwd = ops.password
	local perms = ops.permissions
	ops.algorithm = ops.algorithm or "sha3-512"
	local algo = hashes[ops.algorithm]
	if not algo then
		error("no such hash algorithm: " .. ops.algorithm)
	end
	security.requirePermission("file.system")
	security.requirePermission("users.create")

	local salt = randomSalt(64)
	local hash = algo(salt .. passwd)

	local user = {
		name = username,
		security = ops.algorithm,
		password = hash,
		salt = salt
	}
	table.insert(users, user)
	filesystem.makeDirectory("A:/Users/" .. username)
	local stream = io.open("A:/Users/" .. username .. "/account.lon", "w")
	stream:write(require("liblon").sertable(user))
	stream:close()
end

--- Login to a new user using given credentials
-- @string username The username to login with
-- @string passwd The password used to authenticate
function lib.login(username, passwd)
	if user ~= nil then
		local ok, reason = lib.logout()
		if not ok then
			return ok, reason
		end
	end
	if username == "guest" then
		return true -- we already logged out
	end
	if #users == 0 then
		retrieveUsers()
	end
	for _, v in pairs(users) do
		if v.name == username then
			if v.security ~= "none" and hashes[v.security] then
				local algo = hashes[v.security]
				local hash = algo(v.salt .. passwd)
				if v.password == hash then
					userLogin(v)
					return true
				else
					return false, "the password is not valid"
				end
			elseif v.security == "none" then
				userLogin(v)
				return true
			end
		end
	end
	return false, "no user with username \"" .. username .. "\" was found."
end

return lib
