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
	if not fileStream then
		error("Could not load permissions, 0 permissions given.")
	end
	userPerms = require("liblon").loadlon(fileStream)
	fileStream:close()
end

function lib.lateInit()
	if not userPermsLoaded then
		loadUserPermissions()
		userPermsLoaded = true
	else
		error("cannot run late init twice")
	end
end

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
		return false, "parent process do not grants permission"
	end
end

function lib.isRegistered(pid)
	return permtable[pid] ~= nil
end

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

function lib.requirePermission(perm)
	if not lib.hasPermission(perm) then
		error("permission required : " .. perm, 2)
	end
end

function lib.getPermissions(pid)
	local proc = pid or currentProcess().pid
	local copy = {}
	for k, v in pairs(permtable[proc.pid]) do
		copy[k] = v
	end
	return copy
end

return lib
