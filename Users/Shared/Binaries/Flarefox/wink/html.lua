local fhtml = ...
local html = {}

local function isupper(cp)
	cp = cp:byte()
	return (cp > 0x40 and cp <= 0x5A)
end

local function islower(cp)
	cp = cp:byte()
	return (cp > 0x60 and cp <= 0x7A)
end

local function isalpha(cp)
	return isupper(cp) or islower(cp)
end

function html.tokenize(text)
	local tokens = {}
	local state = {
		name = "data"
	}
	print("Tokenizing..")

	local i = 1
	while i < #text do
		local char = text:sub(i, i)
		local function emitTag()
			table.insert(tokens, {
				name = "tag_" .. state.tagType,
				tagName = state.tagName
			})
		end
		local ops = {
			data = function()
				if char == '<' then
					state.name = "tag_open"
					i = i + 1
				else
					table.insert(tokens, {
						name = "character",
						character = char
					})
					i = i + 1
				end
			end,
			tag_open = function()
				if char == '!' then
					state.name = "markup_declaration"
					i = i + 1
				elseif isalpha(char) then
					state.name = "tag_name"
					state.tagName = ""
					state.tagType = "open"
				elseif char == '/' then
					state.name = "end_tag_open"
					state.tagName = ""
					i = i + 1
				else
					error("unexpected char: " .. char)
				end
			end,
			end_tag_open = function()
				if char == '>' then
					error("missing-end-tag-name")
				elseif isalpha(char) then
					state.name = "tag_name"
					state.tagName = ""
					state.tagType = "close"
				end
			end,
			markup_declaration = function()
				if text:sub(i, i + 1) == "--" then
					state.name = "comment_start" -- we parsed <!--
					i = i + 2
				elseif text:sub(i, i + 6):upper() == "DOCTYPE" then
					state.name = "doctype"
					i = i + 7
				else
					error("unexpected char: " .. char .. " (incorrectly-opened-comment)")
				end
			end,
			comment_start = function()
				if char == '-' then
					state.name = "comment_start_dash"
					i = i + 1
				elseif char == '>' then
					error("abrupt-closing-of-empty-comment")
				else
					state.name = "comment"
				end
			end,
			comment = function()
				if char == '-' then
					state.name = "comment_start_dash" -- TODO: comment_end_dash ??
					i = i + 1
				else -- TODO: handle other cases
					state.name = "comment"
					i = i + 1
				end
			end,
			comment_start_dash = function()
				if char == '-' then
					state.name = "comment_end"
					i = i + 1
				elseif char == '>' then
					error("abrupt-closing-of-empty-comment")
				else
					state.name = "comment"
				end
			end,
			comment_end = function()
				if char == '>' then
					state.name = "data"
					i = i + 1
				elseif char == '!' then
					state.name = "comment_end_bang"
					i = i + 1
				else
					state.name = "comment"
				end
			end,
			tag_name = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' then
					state.name = "before_attribute_name"
					i = i + 1
				elseif char == '/' then
					--state.name = "self_closing_start_tag"
					table.insert(tokens, {
						name = "tag_self_closing",
						tagName = state.tagName
					})
					state.name = "data"
					i = i + 2
				elseif char == '>' then
					emitTag()
					state.name = "data"
					i = i + 1
				else -- TODO: handle NULL and EOF
					state.tagName = state.tagName .. char:lower()
					i = i + 1
				end
			end,

			-- Attributes
			before_attribute_name = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' then
					-- ignore
					i = i + 1
				elseif char == '/' or char == '>' then
					state.name = "after_attribute_name"
				elseif char == '=' then
					error("unexpected-equals-sign-before-attribute-name")
				else
					state.attributeName = ""
					state.name = "attribute_name"
				end
			end,
			attribute_name = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' or char == '/' or char == '>' then
					state.name = "after_attribute_name"
				elseif char == '=' then
					state.name = "before_attribute_value"
					i = i + 1
				elseif char == '"' or char == "'" or char == '<' then
					print(char)
					print(text:sub(i-5, i+5))
					error("unexpected-character-in-attribute-name")
				else
					state.attributeName = state.attributeName .. char:lower()
					i = i + 1
				end
			end,
			after_attribute_name = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' then
					-- ignore
					i = i + 1
				elseif char == '/' then
					--state.name = "self_closing_start_tag"
					table.insert(tokens, {
						name = "tag_self_closing",
						tagName = state.tagName
					})
					i = i + 2
					state.name = "data"
				elseif char == '=' then
					state.name = "before_attribute_value"
					i = i + 1
				elseif char == '>' then
					emitTag()
					state.name = "data"
					i = i + 1
				else
					-- TOOD: start new attribute
					state.name = "attribute_name"
					state.attributeName = ""
				end
			end,
			before_attribute_value = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' then
					-- ignore
					i = i + 1
				elseif char == '"' or char == "'" then
					state.name = "attribute_value"
					state.attributeValue = ""
					if char == '"' then
						state.quotation = "double"
					else
						state.quotation = "single"
					end
					i = i + 1
				elseif char == '>' then
					error("missing-attribute-value")
				else
					state.name = "attribute_value"
					state.attributeValue = ""
					state.quotation = "unquoted"
				end
			end,
			attribute_value = function()
				local isBlankChar = char == '\t' or char == '\n' or char == '\x0c' or char == ' '
				if
					(state.quotation == "double" and char == '"') or
					(state.quotation == "single" and char == "'") then
					state.name = "after_attribute_value"
					i = i + 1
				elseif state.quotation == "unquoted" and isBlankChar then
					state.name = "before_attribute_name"
				elseif char == "&" then
					state.returnState = state.name
					state.name = "character_reference"
					i = i + 1
				elseif state.quotation == "unquoted" and char == '>' then
					emitTag()
					state.name = "data"
					i = i + 1
				else
					state.attributeValue = state.attributeValue .. char
					i = i + 1
				end
			end,
			after_attribute_value = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' then
					state.name = "before_attribute_name"
					i = i + 1
				elseif char == '>' then
					emitTag()
					state.name = "data"
					i = i + 1
				else
					error("after_attribute_value: TODO char '" .. char .. "'")
				end
			end,

			-- Everything DOCTYPE
			doctype = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' then
					state.name = "before_doctype_name"
					i = i + 1
				elseif char == '>' then
					state.name = "before_doctype_name"
				else
					error("missing-whitespace-before-doctype-name")
				end
			end,
			before_doctype_name = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' then
					-- ignore
					i = i + 1
				elseif isalpha(char) then
					state.name = "doctype_name"
					state.doctypeName = char:lower()
					i = i + 1
				else
					error("unexpected char:" .. char) -- TODO: handle
				end
			end,
			doctype_name = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' then
					state.name = "after_doctype_name"
					i = i + 1
				elseif char == '>' then
					table.insert(tokens, {
						name = "doctype",
						doctypeName = state.doctypeName
					})
					state.name = "data"
					i = i + 1
				elseif isalpha(char) then
					state.doctypeName = state.doctypeName .. char:lower()
					i = i + 1
				else
					error("unexpected char:" .. char) -- TODO: handle
				end
			end,
			after_doctype_name = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' then
					-- ignore
					i = i + 1
				elseif char == '>' then
					table.insert(tokens, {
						name = "doctype",
						doctypeName = state.doctypeName
					})
					state.name = "data"
					i = i + 1
				else -- TODO: handle EOF
					if text:sub(i, i + 5):upper() == "PUBLIC" then
						state.name = "after_doctype_public_keyword"
						i = i + 6
					else
						error("invalid-character-sequence-after-doctype-name")
					end
				end
			end,
			after_doctype_public_keyword = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' then
					state.name = "before_doctype_public_identifier"
					i = i + 1
				else
					error("something unexpected") -- todo: implement respective errors
				end
			end,
			before_doctype_public_identifier = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' then
					-- ignore
					i = i + 1
				elseif char == '"' then
					state.name = "doctype_public_identifier_double_quoted"
					state.publicIdentifier = ""
					i = i + 1
				else
					error("something unexpected") -- todo: implement respective errors
				end
			end,
			doctype_public_identifier_double_quoted = function()
				if char == '"' then
					state.name = "after_doctype_public_identifier"
					i = i + 1
				elseif char == '>' then -- TODO: handle null
					error("abrupt-doctype-public-identifier")
				else -- TODO: handle EOF
					state.publicIdentifier = state.publicIdentifier .. char
					i = i + 1
				end
			end,
			after_doctype_public_identifier = function()
				if char == '\t' or char == '\n' or char == '\x0c' or char == ' ' then
					error("TODO: between doctype public and system identifiers state")
				elseif char == '>' then
					state.name = "data"
					table.insert(tokens, {
						name = "doctype",
						doctypeName = state.doctypeName,
						publicIdentifier = state.publicIdentifier
					})
				else
					error("unexpected char: " .. char)
				end
			end
		}
		if ops[state.name] then
			ops[state.name]()
		else
			error("missing state implementation: " .. state.name)
		end

		if i % 5000 == 0 then
			coroutine.yield()
		end
	end
	if state.name ~= "data" then
		error("eof-in-" .. state.name)
	end

	return tokens
end

local specificScopeForbidden = {
	"applet", "caption", "html", "table", "td", "th", "marquee", "object",
	"template", "mi", "mo", "mn", "ms", "mtext", "annotation-xml", "desc",
	"foreignObject", "title",

	"#root", -- TODO: instead just ensure everything is in <html>
}
local function isInScope(currentNode, tagName, forbidden)
	forbidden = forbidden or specificScopeForbidden

	if table.contains(forbidden, currentNode.tagName) then
		return false
	elseif currentNode.tagName == tagName then
		return true
	else
		return isInScope(currentNode.parentNode, tagName)
	end
end

--- Parses an HTML document
-- @returns Document
function html.parse(text)
	local tokens = html.tokenize(text)

	local root = fhtml.Element:new("#root")
	local currentNode = root -- '#root' is an implementation detail!
	local text = ""

	local impliedEndTags = {
		"dd", "dt", "li","optgroup", "option", "p", "rb", "rp", "rt", "rtc",

		"nextid", -- backward compatibility with the first web page
		"hr", "link" -- those aren't in the spec list? TODO see the special thing about it in html spec
	}
	local impliedTagCloser = {
		"address", "article", "aside", "blockquote", "center", "details",
		"dialog", "dir", "div", "dl", "fieldset", "figcaption", "figure",
		"footer", "header", "hgroup", "main", "menu", "nav", "ol", "p",
		"section", "summary", "ul",
		"h1", "h2", "h3", "h4", "h5", "h6", "pre", "listing" -- TODO: they're special case
	}
	local selfClosing = {
		"area", "br", "embed", "img", "keygen", "wbr"
	}

	local function closeNode()
		if not currentNode.parentNode then
			print("we already reached " .. currentNode.tagName .. " node?")
			error("test")
		end
		local parent = currentNode.parentNode
		parent:appendChild(currentNode)
		currentNode = parent
	end

	local function generateImpliedEndTags(except)
		except = except or {}

		while table.contains(impliedEndTags, currentNode.tagName) and not table.contains(except, currentNode.tagName) do
			closeNode()
		end
	end

	print("Parsing..")

	local line = 1
	local lastYield = 0
	for i, token in pairs(tokens) do
		if computer.uptime() - 1 > lastYield then
			lastYield = computer.uptime()
			coroutine.yield()
		end
		if token.name == "tag_open" then
			if text:len() > 0 then
				currentNode:appendChild(fhtml.Text:new(text, currentNode))
				text = ""
			end
			if table.contains(impliedTagCloser, token.tagName) then
				if isInScope(currentNode, "p") then -- TODO: 'button' -> https://html.spec.whatwg.org/multipage/parsing.html#has-an-element-in-button-scope)
					-- TODO: generate implied end tags except for 'p'
					--while currentNode.tagName ~= "p" do
						generateImpliedEndTags({ "p" })
						closeNode()
					--end
				end
			end
			currentNode = fhtml.Element:new(token.tagName, currentNode)

			if table.contains(selfClosing, token.tagName) then
				print("current parent node = " .. currentNode.parentNode.tagName)
				closeNode()
			end
		elseif token.name == "tag_close" then
			if token.tagName == "li" then
				generateImpliedEndTags({ "li" })
			else
				-- TODO: follow 'in body' any other end tag
				generateImpliedEndTags({ token.tagName })
			end

			if token.tagName ~= currentNode.tagName then
				error("expected </" .. currentNode.tagName .. ">, got </" .. token.tagName .. "> line " .. line)
			end
			closeNode()
		elseif token.name == "character" then
			if token.character == "\n" or token.character == "\r" then
				text = text .. " " -- replaced by a space
				line = line + 1
			else
				text = text .. token.character
			end
		elseif token.name == "tag_self_closing" then
			print("self closing: " .. token.tagName)
			-- TODO: currently tokenizer incorrectly parses things as self-closing
			if token.tagName ~= "link" and token.tagName ~= "meta" and token.tagName ~= "use" and token.tagName ~= "img" and token.tagName ~= "br"
				and token.tagName ~= "input" then
				currentNode = fhtml.Element:new(token.tagName, currentNode)
			end
		elseif token.name == "doctype" then
			-- right now, we don't care about that doctype
		else
			error("unhandled token: " .. token.name)
		end
	end

	if currentNode.tagName ~= "#root" then
		--error("end node isn't root")
	end
	while currentNode.tagName ~= "#root" do -- definitely not valid to do that, but until all TODOs are solved..
		currentNode = currentNode.parentNode
	end
	--return currentNode
	return currentNode
end

return html
