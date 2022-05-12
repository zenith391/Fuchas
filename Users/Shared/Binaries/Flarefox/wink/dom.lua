local dom = {}

local EventTarget = {}

function EventTarget:addEventListener(name, listener)
	if not self.eventListeners then
		self.eventListeners = {}
	end

	if not self.eventListeners[name] then
		self.eventListeners[name] = {}
	end
	table.insert(self.eventListeners[name], listener)
end

function EventTarget:removeEventListener(name, listener)
	error("TODO EventTarget:removeEventListener")
end

function EventTarget:dispatchEvent(event)
	local name = event:getType()
	event.dispatch = true

	if self.eventListeners[name] then
		for _, listener in ipairs(self.eventListeners[name]) do
			listener(event:getArguments())
		end
	end
end

local Event = {}
Event.__index = Event

function Event:new(type, opts)
	return setmetatable({
		type = type,
		arguments = {},
		dispatch = false
	})
end

function Event:getType()
	return self.type
end

function Event:getTarget()
	return self.target
end

function Event:getArguments()
	return table.unpack(self.arguments)
end

local Node = {}
Node.__index = Node
Node = setmetatable(Node, { __index = EventTarget })

function Node:new(type)
	checkArg(1, type, "string")
	return setmetatable({
		parentNode = nil,
		children = {},
		nodeType = type
	}, Node)
end

function Node:getFirstChild()
	return self.children[1]
end

function Node:getLastChild()
	return self.children[#self.children]
end

function Node:appendChild(node)
	table.insert(self.children, node)
end

function Node:getNodeName()
	if self.nodeType == "element" then
		return self.tagName
	elseif self.nodeType == "text" then
		return "#text"
	elseif self.nodeType == "document" then
		return "#document"
	else
		error("TODO: Node:getNodeName for node type '" .. self.nodeType .. "'")
	end
end

function Node:getTextContent()
	if self.nodeType == "text" then
		return self.wholeText
	else
		local text = ""

		for _, child in pairs(self.children) do
			text = text .. child:getTextContent()
		end

		return text
	end
end

local Element = {}
Element.__index = Element
Element = setmetatable(Element, { __index = Node })

function Element:new(name, parent)
	checkArg(1, name, "string")
	local instance = Node:new("element")
	instance.tagName = name
	instance.parentNode = parent -- parent may be nil
	return setmetatable(instance, Element)
end

function Element:__tostring()
	local str = "<" .. self.tagName .. ">"
	for _, child in ipairs(self.children) do
		str = str .. "\n\t" .. tostring(child)
	end
	if #self.children > 0 then
		str = str .. "\n"
	end
	str = str .. "</" .. self.tagName .. ">"
	return str
end

local Text = {}
Text.__index = Text
Text = setmetatable(Text, { __index = Node })

function Text:new(text, parent)
	checkArg(1, text, "string")
	checkArg(2, parent, "table")
	local instance = Node:new("text")
	instance.wholeText = text
	instance.parentNode = parent -- parent may be nil
	return setmetatable(instance, Text)
end

function Text:__tostring()
	return "#text" .. self.wholeText
end

return {
	Node = Node,
	Element = Element,
	Text = Text,
	Event = Event
}
