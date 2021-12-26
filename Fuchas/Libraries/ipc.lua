--- IPC library implemented using the per-process event system.
-- It implements OETF #18 (Open Inter-Process Communication), the main difference being that
-- `computer.pushProcessSignal` is used instead of `computer.pushSignal`.
-- @module ipc
-- @alias lib

local lib = {}
local tasks = require("tasks")
local event = require("event")

--- Sockets are used for both listening and writing and are not necessary to be opened on both sides.
-- This is a best-effort asynchronous in write and synchronous in read message passing.
-- Due to the way they work, they cannot be closed unlike streams.
-- @int target process PID
-- @string id the unique identifier of the socket that should be shared between both processes
function lib.socket(target, id)
	if not tasks.getProcessMetrics(target) then
		error("invalid process: " .. target)
	end

	local socket = {}
	socket.target = target
	socket.id = id
	socket.pid = tasks.getCurrentProcess().pid -- source pid

	function socket:write(...)
		if self:closed() then error("ipc socket " + self.id + " closed") end
		computer.pushProcessSignal(self.target, "oipc_sock_comms", self.id, ...);
	end

	function socket:read()
		if self:closed() then error("ipc socket " + self.id + " closed") end
		local _, id, ... = event.pull("oipc_sock_comms");
		if id == self.id then
			return ...
		else
			-- TODO: do it in a way that preserves the send order
			computer.pushProcessSignal(self.pid, "oipc_sock_comms", id, ...) -- resend the event to itself
		end
	end

	function socket:closed()
		local proc = tasks.getProcess(target)
		if not proc then -- not alive
			return true
		else
			return false
		end
	end

	computer.pushProcessSignal(self.target, "incoming_ipc_socket", socket.pid)

	return socket
end

return lib
