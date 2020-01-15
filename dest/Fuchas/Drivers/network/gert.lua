-- Port of GERTiClient from GlobalEmpire for Fuchas
-- GERT v1.2
local GERTi = {}
local event = require("event")
local liblon = require("liblon")
local modem = nil
local tunnel = nil

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

local iAdd = nil
local tier = 3
-- nodes[GERTi]{"add", "port", "tier"}, "add" is modem
local nodes = {}
local firstN = {}

-- connections[connectDex][data/order] Connections are established at any point along a route
local connections = {}

local function addTempHandler(timeout, code, cb, cbf)
	local disable = false
	local function cbi(...)
		if disable then return end
		local evn, rc, sd, pt, dt, code2 = ...
		if code ~= code2 then return end
		if cb(...) then
			disable = true
			return false
		end
	end
	event.listen("modem_message", cbi)
	event.timer(timeout, function ()
		event.ignore("modem_message", cbi)
		if disable then return end
		cbf()
	end)
end
local function waitWithCancel(timeout, cancelCheck)
	local now = computer.uptime()
	local deadline = now + timeout
	while now < deadline do
		event.pull(deadline - now, "modem_message")
		local response = cancelCheck()
		if response then return response end
		now = computer.uptime()
	end
	return cancelCheck()
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
	local connectDex = origin.."|"..GAdd.."|"..ID
	connections[connectDex] = {}
	connections[connectDex]["origin"]=origin
	connections[connectDex]["dest"]=GAdd
	connections[connectDex]["ID"]=ID
	if nextHop then
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

handler.NewNode = function (sendingModem, port)
	transInfo(sendingModem, port, "RETURNSTART", iAdd, tier)
end

local function routeOpener(dest, origin, bHop, nextHop, intermediary, recPort, transPort, ID)
	local function sendOKResponse(isDestination)
		transInfo(bHop, recPort, "RouteOpen", dest, origin)
		if isDestination then
			computer.pushSignal("GERTConnectionID", origin, ID)
		end
		storeConnection(origin, ID, dest, nextHop, transPort)
	end
	if iAdd ~= dest then
		local response
		transInfo(nextHop, transPort, "OpenRoute", dest, intermediary, origin, ID)
		addTempHandler(3, "RouteOpen", function (eventName, recv, sender, port, distance, code, pktDest, pktOrig)
			if (dest == pktDest) and (origin == pktOrig) then
				response = code
				sendOKResponse(false)
				return true -- This terminates the wait
			end
		end, function () end)
		waitWithCancel(3, function () return response end)
		return response
	else
		sendOKResponse(true)
	end
end
handler.OpenRoute = function (sendingModem, port, dest, intermediary, origin, ID)
	if dest == iAdd then
		return routeOpener(iAdd, origin, sendingModem, nil, nil, port, nil, ID)
	end
	if nodes[dest] then
		return routeOpener(dest, origin, sendingModem, nodes[dest]["add"], nil, port, nodes[dest]["port"], ID)
	end
	if not nodes[intermediary] then
		return routeOpener(dest, origin, sendingModem, firstN["add"], nil, port, firstN["port"], ID)
	end
	local nextHop = tonumber(string.sub(intermediary, 1, string.find(intermediary, "|")-1))
	intermediary = string.sub(intermediary, string.find(intermediary, "|")+1)
	return routeOpener(dest, origin, sendingModem, nodes[nextHop]["add"], intermediary, port, nodes[nextHop]["port"], ID)
end

handler.RegisterNode = function (sendingModem, sendingPort, origination, nTier, serialTable)
	transInfo(firstN["add"], firstN["port"], "RegisterNode", origination, nTier, serialTable)
	addTempHandler(3, "RegisterComplete", function (eventName, recv, sender, port, distance, code, targetMA, iResponse)
		if targetMA == origination then
			transInfo(sendingModem, sendingPort, "RegisterComplete", targetMA, iResponse)
			return true
		end
	end, function () end)
end

handler.RemoveNeighbor = function (sendingModem, port, origination)
	if nodes[origination] then
		nodes[origination] = nil
	end
	transInfo(firstN["add"], firstN["port"], "RemoveNeighbor", origination)
end

handler.RETURNSTART = function (sendingModem, port, gAddress, nTier)
	storeNodes(tonumber(gAddress), sendingModem, port, nTier)
end

local function receivePacket(eventName, receivingModem, sendingModem, port, distance, code, ...)
	if handler[code] then
		handler[code](sendingModem, port, ...)
	end
end

------------------------------------------
if tunnel then
	tunnel.send("NewNode")
end
if modem then
	modem.broadcast(4378, "NewNode")
end
event.listen("modem_message", receivePacket)
os.sleep(2)

-- forward neighbor table up the line
local serialTable = liblon.sertable(nodes)
if serialTable ~= "{}" then
	local mncUnavailable = true
	local addr = (modem or tunnel).address
	transInfo(firstN["add"], firstN["port"], "RegisterNode", addr, tier, serialTable)
	addTempHandler(3, "RegisterComplete", function (_, _, _, _, _, code, targetMA, iResponse)
		if targetMA == addr then
			iAdd = tonumber(iResponse)
			mncUnavailable = false
			return true
		end
	end, function () end)
	waitWithCancel(5, function () return iAdd end)
	if mncUnavailable then
		print("Unable to contact the MNC. Functionality will be impaired.")
	end
end

if tunnel then
	tunnel.send("RETURNSTART", iAdd, tier)
end
if modem then
	modem.broadcast(4378, "RETURNSTART", iAdd, tier)
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
	if nodes[gAddress] then
		port = nodes[gAddress]["port"]
		add = nodes[gAddress]["add"]
		routeOpener(gAddress, iAdd, "A", nodes[gAddress]["add"], nil, nodes[gAddress]["port"], nodes[gAddress]["port"], outID)
	else
		if not routeOpener(gAddress, iAdd, nil, firstN["add"], nil, firstN["port"], firstN["port"], outID) then
			return nil
		end
	end
	
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
end
function GERTi.broadcast(data)
	if modem and (type(data) ~= "table" or type(data) ~= "function") then
		modem.broadcast(4378, data, -1, iAdd, -1)
	end
end
function GERTi.send(dest, data)
	if nodes[dest] and (type(data) ~= "table" or type(data) ~= "function") then
		transInfo(nodes[dest]["add"], nodes[dest]["port"], "Data", data, dest, iAdd, -1)
	end
end
function GERTi.getConnections()
	local tempTable = {}
	for key, value in pairs(connections) do
		tempTable[key] = {}
		tempTable[key]["origin"] = value["origin"]
		tempTable[key]["destination"] = value["dest"]
		tempTable[key]["ID"] = value["ID"]
		tempTable[key]["nextHop"] = value["nextHop"]
		tempTable[key]["port"] = value["port"]
		tempTable[key]["order"] = value["order"]
	end
	return tempTable
end

function GERTi.getNeighbors()
	return nodes
end

function GERTi.getVersion()
	return "v1.2", "1.2"
end

local gert = {}

function gert.getAddress()
	return iAdd
end

function gert.getAddresses()
	return {gert.getAddress()}
end

function gert.isProtocolAddress(addr)
	if tonumber(addr) then -- ex: 1.2, any GERTi
		return true
	else -- ex: 1.2:3.4, any GERTc
		local sp = string.split(addr, ":")
		return (tonumber(sp[1]) ~= nil) and (tonumber(sp[2]) ~= nil)
	end
end

function gert.open(addr, port)
	local gSocket = GERTi.openSocket(addr, port)
	return {
		close = gSocket.close,
		write = gSocket.write,
		read = gSocket.read
	}
end

function gert.cancelAsync(id)
	event.cancel(id)
end

function gert.listenAsync(port, callback)
	local hnd = 0
	event.listen("GERTConnectionID", function(_, origin, port)
		local nSocket = gert.open(origin, port)
		event.cancel(hnd)
		callback(nSocket)
	end)
	return hnd
end

function gert.listen(port)
	local _, origin, port = event.pull("GERTConnectionID") -- TODO prevent GERTi sending events and instdead use API
	return gert.open(origin, port)
end

return "gert", gert