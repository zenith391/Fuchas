local lib = {}
local permtable = {}

local function currentProcess()
	local proc = shin32.getCurrentProcess()
	if not permtable[proc.pid] then
		permtable[proc.pid] = {}
	end
	return proc
end

function lib.revoke(pid)
	if shin32.getProcess(pid).status == "dead" then
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

function lib.requestPermission(perm)
	local proc = currentProcess().parent
	if proc.permissionGrant then
		if proc.permissionGrant(perm, currentProcess().pid) then
			permtable[currentProcess().pid][perm] = true
			return true
		else
			return false, "permission not granted"
		end
	end
end

function lib.isRegistered(pid)
	return permtable[pid] ~= nil
end

function lib.hasPermission(perm, pid)
	local proc = pid or currentProcess().pid
	if permtable[proc]["*"] then
		return true
	else
		return permtable[proc][perm] ~= nil
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