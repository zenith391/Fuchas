-- Tweaks were made to port GERTi v1.3 to Fuchas
-- GERTi v1.3
local GERTi = {}
local protocol = {}
local component = ...
local event = require("event")
local lon = require("liblon")
local modem
local tunnel

if (component.isAvailable("modem")) then
	modem = component.modem
	modem.open(4378)
	if (component.modem.isWireless()) then
		modem.setStrength(500)
	end
end
if (component.isAvailable("tunnel")) then
	tunnel = component.tunnel
end
if not (modem or tunnel) then
	io.stderr:write("This program requires a network or linked card to run.")
	os.exit(1)
end

local iAdd
local tier = 3
-- nodes[GERTi]{"add", "port", "tier"}, "add" is modem
local nodes = {}
local firstN = {}

-- connections[connectDex][data/order] Connections are established at any point along a route
local connections = {}
local cPend = {}
local rPend = {}
local function waitWithCancel(timeout, cancelCheck)
	local now = computer.uptime()
	local deadline = now + timeout
	while now < deadline do
		event.pull(deadline - now, "modem_message")
		local response = cancelCheck()
		if response then return end
		now = computer.uptime()
	end
end

local function storeNodes(gAddress, sendingModem, port, nTier)
	nodes[gAddress] = {add = sendingModem, port = tonumber(port), tier = nTier}
	if (not firstN["tier"]) or nTier < firstN["tier"] then
		tier = nTier+1
		firstN = nodes[gAddress]
		firstN["gAdd"] = gAddress
	end
end
local function storeConnection(origin, ID, GAdd, nextHop, port)
	ID = math.floor(ID)
	local connectDex = origin.."|"..GAdd.."|"..ID
	connections[connectDex] = {}
	connections[connectDex]["origin"]=origin
	connections[connectDex]["dest"]=GAdd
	connections[connectDex]["ID"]=ID
	if GAdd ~= iAdd then
		connections[connectDex]["nextHop"]=nextHop
		connections[connectDex]["port"]=port
	else
		connections[connectDex]["data"]={}
		connections[connectDex]["order"]=1
	end
end

local function storeData(connectDex, data, order)
	if #connections[connectDex]["data"] > 20 then
		table.remove(connections[connectDex]["data"], 1)
	end
	if order >= connections[connectDex]["order"] then
		table.insert(connections[connectDex]["data"], data)
		connections[connectDex]["order"] = order
	else
		table.insert(connections[connectDex]["data"], #connections[connectDex]["data"], data)
	end
	computer.pushSignal("GERTData", connections[connectDex]["origin"], connections[connectDex]["ID"])
end

local function transInfo(sendTo, port, ...)
	if modem and port ~= 0 then
		modem.send(sendTo, port, ...)
	elseif tunnel then
		tunnel.send(...)
	end
end

local handler = {}
handler.CloseConnection = function(sendingModem, port, connectDex)
	if connections[connectDex]["nextHop"] then
		transInfo(connections[connectDex]["nextHop"], connections[connectDex]["port"], "CloseConnection", connectDex)
	else
		computer.pushSignal("GERTConnectionClose", connections[connectDex]["origin"], connections[connectDex]["dest"], connections[connectDex]["ID"])
	end
	connections[connectDex] = nil
end

handler.Data = function (sendingModem, port, data, connectDex, order, origin)
	if connectDex == -1 then
		return computer.pushSignal("GERTData", origin, -1, data)
	end
	if connections[connectDex] then
		if connections[connectDex]["dest"] == iAdd then
			storeData(connectDex, data, order)
		else
			transInfo(connections[connectDex]["nextHop"], connections[connectDex]["port"], "Data", data, connectDex, order)
		end
	end
end

handler.NewNode = function (sendingModem, port, gAddress, nTier)
	if gAddress then
		storeNodes(tonumber(gAddress), sendingModem, port, nTier)
	else
		transInfo(sendingModem, port, "NewNode", iAdd, tier)
	end
end
local function sendOK(bHop, recPort, dest, origin, ID)
	if dest==iAdd then
		computer.pushSignal("GERTConnectionID", origin, ID)
	end
	if origin ~= iAdd then
		transInfo(bHop, recPort, "RouteOpen", dest, origin, ID)
	end
end
handler.OpenRoute = function (sendingModem, port, dest, intermediary, origin, ID)
	if dest == iAdd then
		storeConnection(origin, ID, dest)
		sendOK(sendingModem, port, dest, origin, ID)
	elseif nodes[dest] then
		transInfo(nodes[dest]["add"], nodes[dest]["port"], "OpenRoute", dest, nil, origin, ID)
	elseif not intermediary then
		transInfo(firstN["add"], firstN["port"], "OpenRoute", dest, nil, origin, ID)
	else
		local nextHop = tonumber(string.sub(intermediary, 1, string.find(intermediary, "|")-1))
		intermediary = string.sub(intermediary, string.find(intermediary, "|")+1)
		transInfo(nodes[nextHop]["add"], nodes[nextHop]["port"], "OpenRoute", dest, intermediary, origin, ID)
	end
	cPend[dest..origin]={["bHop"]=sendingModem, ["port"]=port}
end
handler.RegisterComplete = function(sender, port, target, newG)
	if (modem and target == modem.address) or (tunnel and target == tunnel.address) then
		iAdd = tonumber(newG)
	elseif rPend[target] then
		transInfo(rPend[target]["add"], rPend[target]["port"], "RegisterComplete", target, newG)
		rPend[target] = nil
	end
end
handler.RegisterNode = function (sender, sPort, origin, nTier, serialTable)
	transInfo(firstN["add"], firstN["port"], "RegisterNode", origin, nTier, serialTable)
	rPend[origin] = {}
	rPend[origin]["add"] = sender
	rPend[origin]["port"] = sPort
end

handler.RemoveNeighbor = function (sendingModem, port, origination)
	if nodes[origination] then
		nodes[origination] = nil
	end
	transInfo(firstN["add"], firstN["port"], "RemoveNeighbor", origination)
end

handler.RouteOpen = function (sModem, sPort, pktDest, pktOrig, ID)
	if cPend[pktDest..pktOrig] then
		sendOK(cPend[pktDest..pktOrig]["bHop"], cPend[pktDest..pktOrig]["port"], pktDest, pktOrig, ID)
		storeConnection(pktOrig, ID, pktDest, sModem, sPort)
		cPend[pktDest..pktOrig] = nil
	end
end
local function receivePacket(eventName, receivingModem, sendingModem, port, distance, code, ...)
	if handler[code] then
		handler[code](sendingModem, port, ...)
	end
end

------------------------------------------
event.listen("modem_message", receivePacket)
if tunnel then
	tunnel.send("NewNode")
end
if modem then
	modem.broadcast(4378, "NewNode")
end
os.sleep(2)

-- forward neighbor table up the line
local serialTable = lon.serialize(nodes)
if serialTable ~= "{}" then
	local mncUnavailable = true
	local addr = (modem or tunnel).address
	transInfo(firstN["add"], firstN["port"], "RegisterNode", addr, tier, serialTable)
	waitWithCancel(5, function () return iAdd end)
	if not iAdd then
		print("Unable to contact the MNC. Functionality will be impaired.")
	end
end

if tunnel then
	tunnel.send("NewNode", iAdd, tier)
end
if modem then
	modem.broadcast(4378, "NewNode", iAdd, tier)
end
--Listen to computer.shutdown to allow for better network leaves
local function safedown()
	for key, value in pairs(connections) do
		handler.CloseConnection((modem or tunnel).address, 4378, key)
	end
	if tunnel then
		tunnel.send("RemoveNeighbor", iAdd)
	end
	if modem then
		modem.broadcast(4378, "RemoveNeighbor", iAdd)
	end
end
event.listen("shutdown", safedown)

-------------------
local function writeData(self, data)
	if type(data) ~= "table" or type(data) ~= "function" then
		transInfo(self.nextHop, self.outPort, "Data", data, self.outDex, self.order)
		self.order=self.order+1
	end
end

local function readData(self, doPeek)
	if connections[self.inDex] then
		local data = connections[self.inDex]["data"]
		if tonumber(doPeek) ~= 2 then
			connections[self.inDex]["data"] = {}
		end
		return data
	else
		return {}
	end
end

local function closeSock(self)
	handler.CloseConnection((modem or tunnel).address, 4378, self.outDex)
end
function GERTi.openSocket(gAddress, doEvent, outID)
	if type(doEvent) ~= "boolean" then
		outID = doEvent
	end
	local port, add
	if not outID then
		outID = #connections + 1
	end
	outID = math.floor(outID)
	if nodes[gAddress] then
		port = nodes[gAddress]["port"]
		add = nodes[gAddress]["add"]
		handler.OpenRoute((modem or tunnel).address, 4378, gAddress, nil, iAdd, outID)
	else
		handler.OpenRoute((modem or tunnel).address, 4378, gAddress, nil, iAdd, outID)
	end
	waitWithCancel(3, function () return (not cPend[gAddress..iAdd]) end)
	if not cPend[gAddress..iAdd] then
		local socket = {origination = iAdd,
			destination = gAddress,
			outPort = port or firstN["port"],
			nextHop = add or firstN["add"],
			ID = outID,
			order = 1,
			outDex=iAdd.."|"..gAddress.."|"..outID,
			inDex = gAddress.."|"..iAdd.."|"..outID,
			write = writeData,
			read = readData,
			close = closeSock}
		return socket
	else
		return false
	end
end
function GERTi.broadcast(data)
	if modem and (type(data) ~= "table" or type(data) ~= "function") then
		modem.broadcast(4378, data, -1, iAdd, -1)
	end
end
function GERTi.send(dest, data)
	if nodes[dest] and (type(data) ~= "table" or type(data) ~= "function") then
		transInfo(nodes[dest]["add"], nodes[dest]["port"], "Data", data, -1, 0, iAdd)
	end
end

function protocol.getAddress()
	return iAdd
end

function protocol.getAddresses()
	return {iAdd} -- cannot know GERTc address
end

function protocol.open(addr, port)
	if addr == "4095.4095:4095.4095" then -- TODO: open broadcast socket
	end
	return GERTi.openSocket(addr, false, port)
end

function protocol.isProtocolAddress(addr)
	if type(addr) == "number" then
		return true -- ex: 4.5
	else
		local num = tonumber(addr)
		if num ~= nil then
			return true -- ex: "4.5"
		else
			local split = string.split(addr, ":")
			if #split == 2 and tonumber(split[1]) ~= nil and tonumber(split[2]) ~= nil then
				return true -- ex: "123.456:4.5"
			end
		end
	end
end

return protocol