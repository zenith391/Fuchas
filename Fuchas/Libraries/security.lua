--- Library for managing process permissions
-- @module security
-- @alias lib

local lib = {}
local permtable = {}
local userPerms = {}
local userPermsLoaded = false
local tasks = require("tasks")

local function currentProcess()
	local proc = tasks.getCurrentProcess()
	if not permtable[proc.pid] then
		permtable[proc.pid] = {}
	end
	return proc
end

-- TODO! Implement https://github.com/zenith391/Fuchas/wiki
local function loadUserPermissions()
	local fileStream = io.open("A:/Fuchas/permissions.lon")
	-- As it is called during boot, calling coroutine.yield would have OC wait for an event
	fileStream.greedy = true
	if not fileStream then
		error("Could not load permissions, 0 permissions given.")
	end
	userPerms = require("liblon").loadlon(fileStream)
	fileStream:close()
end

--- Internal function
-- @local
function lib.lateInit()
	if not userPermsLoaded then
		loadUserPermissions()
		userPermsLoaded = true
	else
		error("cannot run late init twice")
	end
end

--- Revoke all permissions from the given process
-- @permission security.revoke
-- @int pid The PID of the process from which permissions will be removed
function lib.revoke(pid)
	if tasks.getProcess(pid).status == "dead" then
		permtable[pid] = nil
		return true
	else
		if lib.hasPermission("security.revoke") then
			permtable[pid] = nil
			return true
		end
	end
	return false
end

local function initPerms(pid)
	if package.loaded.users then
		local user = package.loaded.users.getUser()
		if user ~= nil then
			for k, v in pairs(userPerms) do
				if k == user.name then
					permtable[pid] = {}
					for _, prm in pairs(v) do
						permtable[pid][prm] = true
					end
				end
			end
		end
	end
end

--- Request a permission to the parent process
-- @string perm requested permission
-- @treturn bool true if the was the permission given
-- @treturn[opt] string details on why the permission was not given
function lib.requestPermission(perm)
	if tasks.getCurrentProcess() == nil then
		return
	end
	initPerms(currentProcess().pid)
	if lib.hasPermission(perm, currentProcess().pid) then
		return true
	end
	local proc = currentProcess().parent
	if proc.permissionGrant then
		if not permtable[proc.pid] then permtable[proc.pid] = {} end
		if lib.hasPermission(perm, proc.pid) and proc.permissionGrant(perm, currentProcess().pid) then
			permtable[currentProcess().pid][perm] = true
			return true
		else
			return false, "permission not granted"
		end
	else
		return false, "parent process does not grants permission"
	end
end

--- Internal function
-- @local
function lib.isRegistered(pid)
	return permtable[pid] ~= nil
end

--- Returns whether the given or current process has the given permission.
-- @string perm permission to be checked
-- @int[opt=current] pid The PID of the process to check if it has or not the given permission
-- @treturn bool Whether the process has the given permission
function lib.hasPermission(perm, pid)
	if not pid and tasks.getCurrentProcess() == nil then
		return true
	end
	local proc = pid or currentProcess().pid
	initPerms(proc)
	if permtable[proc]["*"] then
		return true
	else
		return permtable[proc][perm] ~= nil
	end
end

--- Function to throw an error if the current process doesn't have the given permission.
-- @usage
--  security.requestPermission("permission.cool")
--  security.requirePermission("permission.cool")
--  -- guarenteed to have the 'permission.cool' permission
-- @string perm permission to be checked
function lib.requirePermission(perm)
	if not lib.hasPermission(perm) then
		error("'" .. perm .. "' permission is required", 2)
	end
end

--- Returns the list of all the permissions the given or current process has.
-- @int[opt=current] pid The PID of the process
function lib.getPermissions(pid)
	local proc = pid or currentProcess().pid
	local copy = {}
	for k, v in pairs(permtable[proc.pid]) do
		copy[k] = v
	end
	return copy
end

return lib
