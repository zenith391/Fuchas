-- IPC library using the useful per-process event
-- Implements OETF #18 (Open Inter-Process Communication), doesn't respect it low-level receive with computer.pullSignal

local lib = {}
local tasks = require("tasks")
local event = require("event")

-- Sockets are used for both listening and writing and are not necessary to be opened on both sides.
-- This is a best-effort asynchronous in write and synchronous in read message passing.
-- Due to the way they work, they cannot be closed unlike streams.
-- target: process PID
-- id: the identifier (string) of the socket
function lib.socket(target, id)
	if not tasks.getProcess(target) then
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
