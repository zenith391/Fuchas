-- Geeko OHML Engine v1.0
-- OHML v1.0.1 compliant engine
-- Partially compatible with OHML v1.0.2 (Positioning)
-- Compatible with Styling (OHML v1.0.3)

local geeko = {
	-- The OS-independent filesystem API
	fs = nil,
	mt = nil, -- multi task
	version = "0.2.2", -- Geeko version
	browser = {"Unknown (name)", "Unknown (publisher or developer)", "1.0"},
	thread = nil,
	renderCallback = nil,
	log = nil,
	scriptEnv = {},
	runningScripts = {},
	objects = {},
	currentPath = "ohtp://geeko.com",
	os = "GeekOS/1.0"
}
local cx, cy = 1, 1
local scriptId = 1

-- Filesystem wrapper for OSes that exports a standard Lua "io" API.
local function fsLuaIO()
	return {
		readAll = function(path)
			local file = io.open(path, "r")
			local text = file:read("*a")
			file:close()
			return text
		end,
		parent = function(path)
			return require("filesystem").path(path)
		end
	}
end

local function fuchasMT()
	return {
		new = function(name, func)
			local proc = require("tasks").newProcess(name, func)
			return {
				kill = function()
					proc:kill()
				end
			}
		end
	}
end

local function openOSMT()
	return {
		new = function(name, func)
			local th = require("thread").create(func)
			return {
				kill = function()
					th:kill()
				end
			}
		end
	}
end

-- Filesystem wrapper for Fuchas and OpenOS
local function fuchasIO()
	local wrapper = fsLuaIO() -- supports standard Lua I/O
	wrapper.parent = function(path)
		return require("filesystem").path(path)
	end
	return wrapper
end

local function ccIO() -- yup, Geeko supports ComputerCraft alongside OpenComputers
	local wrapper = fsLuaIO() -- supports standard Lua I/O
	wrapper.parent = function(path)
		return fs.getDir(path)
	end
	return wrapper
end

local function objectWrapper(obj)
	if obj.type == "canvas" then
		local wrapper = {
			drawText = function(x, y, text)
				if obj.drawHandler ~= nil then
					obj.drawHandler("text", x, y, text)
				end
			end,
			fillRect = function(x, y, width, height, char)
				if obj.drawHandler ~= nil then
					obj.drawHandler("fill", x, y, width, height, char)
				end
			end,
			setBackground = function(color, pal)
				if obj.drawHandler ~= nil then
					obj.drawHandler("setbg", color, pal)
				end
			end,
			setForeground = function(color)
				if obj.drawHandler ~= nil then
					obj.drawHandler("setfg", color)
				end
			end
		}
		return wrapper
	end
	return nil
end

local function log(name, level, text)
	if geeko.log ~= nil and type(geeko.log) == "function" then
		geeko.log(name, level, text)
	end
end

local function makeScriptEnv()
	geeko.scriptEnv = {
		_G = geeko.scriptEnv,
		_ENV = geeko.scriptEnv,
		wait = os.sleep,
		navigator = {
			appName = geeko.browser[1],
			appCreator = geeko.browser[2],
			engine = "Geeko",
			engineVersion = geeko.version,
			appVersion = geeko.browser[3],
			userAgent = geeko.browser[1] .. "/" .. geeko.browser[2] .. " Geeko/" .. geeko.version,
			platform = _OSVERSION or "unknown"
		},
		document = {
			getElementById = function(id)
				for k, v in pairs(geeko.objects) do
					if v.tag and v.tag.attr.id == id then
						return objectWrapper(v)
					end
				end
			end
		},
		console = {
			info = function(text)
				log("script", "info", text)
			end,
			warn = function(text)
				log("script", "warn", text)
			end,
			error = function(text)
				log("script", "error", text)
			end,
			log = function(text)
				log("script", "log", text)
			end
		},
		math = math,
		coroutine = coroutine,
		string = string,
		table = table,
		bit32 = bit32,
		tostring = tostring,
		tonumber = tonumber,
		ipairs = ipairs,
		load = load,
		next = next,
		pairs = pairs,
		pcall = pcall,
		xpcall = xpcall,
		select = select,
		type = type,
		_VERSION = _VERSION
	}
end

-- This function must be called before exiting the browser, it
-- kills any child processes (mostly scripts) and do cleanup.
function geeko.clean()
	for k, v in pairs(geeko.runningScripts) do
		v:kill()
	end
end

local function loadScripts(tag)
	for _, v in pairs(tag.childrens) do
		if v.name == "#text" and v.parent.name == "script" and (not v.parent.attr.lang or v.parent.attr.lang == "application/lua") then
			local chunk, err = load(v.content, "web-script", "t", geeko.scriptEnv)
			if not chunk then
				log("geeko", "error", "could not load web script")
			end
			local process = geeko.mt.new("luaweb-script-" .. scriptId, chunk)
			table.insert(geeko.runningScripts, process)
			scriptId = scriptId + 1
		else
			loadScripts(v)
		end
	end
end

local function getFirstAttribute(tag, name)
	if not tag or not tag.attr then
		return nil
	end
	if tag.attr[name] then
		return tag.attr[name]
	else
		if tag.parent then
			return getFirstAttribute(tag.parent, name)
		else
			return nil
		end
	end
end

function geeko.read(tag)
	for _, v in pairs(tag.childrens) do
		if v.attr.x then
			cx = v.attr.x
		end
		if v.attr.y then
			cy = v.attr.y
		end
		if v.name == "#text" then
			if cx + v.content:len() > 160 then
				cx = 1
				cy = cy + 1
			end
			if v.parent.name == "link" then
				table.insert(geeko.objects, {
					type = "hyperlink",
					x = cx,
					y = cy,
					width = v.content:len(),
					height = 1,
					text = v.content,
					hyperlink = v.parent.attr.href,
					tag = v.parent,
					color = tonumber(getFirstAttribute(v.parent, "color") or "2020FF", 16),
					bgcolor = tonumber(getFirstAttribute(v.parent, "bgcolor") or "0", 16)
				})
			elseif v.parent.name == "script" then
				-- handled by loadScripts
			elseif v.parent.name == "notavailable" then
				if v.parent.attr.feature == "Lua 5.3" then
					if _VERSION == "Lua 5.2" then -- only show if on Lua 5.3
						table.insert(geeko.objects, {
							type = "text",
							x = cx,
							y = cy,
							width = v.content:len(),
							height = 1,
							text = v.content,
							color = tonumber(getFirstAttribute(v.parent, "color") or "FFFFFF", 16),
							bgcolor = tonumber(getFirstAttribute(v.parent, "bgcolor") or "0", 16)
						})
					end
				end
			else
				table.insert(geeko.objects, {
					type = "text",
					x = cx,
					y = cy,
					width = v.content:len(),
					height = 1,
					text = v.content,
					color = tonumber(getFirstAttribute(v.parent, "color") or "FFFFFF", 16),
					bgcolor = tonumber(getFirstAttribute(v.parent, "bgcolor") or "0", 16)
				})
			end
			cx = cx + v.content:len()
		elseif v.name == "br" then
			cx = 1
			cy = cy + 1
			geeko.read(v)
		elseif v.name == "canvas" then
			table.insert(geeko.objects, {
				type = "canvas",
				x = cx,
				y = cy,
				width = v.attr.width or 16,
				height = v.attr.height or 8,
				drawHandler = nil,
				tag = v
			})
		else
			geeko.read(v)
			if v.name == "text" or v.name == "h1" or v.name == "h2" or v.name == "h3" or v.name == "h4" or v.name == "h5" then
				cx = 1
				cy = cy + 2
			end
		end
	end
end

function geeko.url(link)
	local schemeEnd, pathStart = link:find("://", 1, true)
	local scheme, path = "", ""
	if not schemeEnd then
		return {
			scheme = nil,
			path = link
		}
	end
	return {
		scheme = link:sub(1, schemeEnd - 1),
		path = link:sub(pathStart + 1, link:len())
	}
end


local function toCharArray(str)
	local t = {}
	for i=1, #str do
		table.insert(t, str:sub(i, i))
	end
	return t
end

--- Tags are tables as follow:
---   name: Name
---   attr: Attributes
---   parent: Parent
---   childrens: Childrens
--- What this function return is a root tag (just a tag with no name, no attribute and no parent, that have all tags (not nested ones) as childrens)
function geeko.parseXML(str)
	local chars = toCharArray(str)
    local line = 1
    local rootTag = {
		name = nil,
		attr = nil,
		parent = nil,
		childrens = {}
	}
    local ok, err = pcall(function()
	local currentTag = rootTag
	
	local i = 1
	local _st = false -- is parsing tag name? (<ohml>)
	local _sta = false -- is parsing attributes?
	local _te = false -- is tag a ending tag? (</ohml>)
	local _tn = "" -- tag name
	local _otn = "" -- old tag name
	local _ott = "" -- old parsing text
	local _tap = "" -- tag attribute propety (name)
	local _tav = "" -- tag attribute value
	local _tavq = 0 -- number of (single or double) quotes in tag attribute value
	local _tt = "" -- currently parsing text
	local _ttcdata = false -- is the current parsing text in a CDATA section? (<![CDATA ]]>)
	local _itap = false -- is parsing attribute property?
	local _ta = {} -- currently parsing attributes
	local _ota = {} -- old parsing attributes
	while i < #chars do
		local ch = chars[i]
		if ch == '/' and not _sta and _tt == "" then
			i = i + 1
			ch = chars[i] -- skip "/"
			_te = true
		end
		if ch == '\n' then
			line = line + 1
		end
		if _sta then
			if _itap then
				if ch == '=' then
					_itap = false
				elseif ch ~= " " then
					_tap = _tap .. ch
				end
			else
				if ch ~= ' ' and ch ~= '>' then
					_tav = _tav .. ch
					if ch == "'" or ch == '"' then
						_tavq = _tavq + 1
					end
				end
			end
		end
		if _st then
			if ch == '>' then
				_st = false
				_sta = false
				if _te then
					currentTag = currentTag.parent
					_te = false
				else
					if _tap ~= "" then
						local f, err = load("return " .. _tav)
						if not f then
							error(err)
						end
						_ta[_tap] = load("return " .. _tav)() -- value conversion, insecure
						_tap = ""
						_tav = ""
						_tavq = 0
					end
					local tag = {
						name = _tn,
						attr = _ta,
						childrens = {},
						parent = currentTag
					}
					table.insert(currentTag.childrens, tag)
					currentTag = tag
				end
			elseif ch == ' ' and not _te and (_tavq == 0 or _tavq == 2) then
				if _tap ~= "" then
					local f, err = load("return " .. _tav)
					if not f then
						error(err)
					end
					_ta[_tap] = load("return " .. _tav)() -- value conversion, insecure
				end
				_tap = ""
				_tav = ""
				_tavq = 0
				_sta = true
				_itap = true
			elseif not _sta then
				_tn = _tn .. ch
				if string.sub(_tn, string.len(_tn)-7) == "![CDATA[" then -- minus length of <![CDATA[
					_ttcdata = true
					table.remove(currentTag.childrens)
					_st = false
					_sta = false
					_te = false
					_tt = _ott
					_tn = _otn
					_ta = _ota
				end
			end
		end
		if ch == '<' and not _ttcdata then
			if _tt ~= "" then
				local textTag = {
					name = "#text",
					content = _tt,
					attr = {},
					childrens = {},
					parent = currentTag
				}
				table.insert(currentTag.childrens, textTag)
			end
			_st = true
			_sta = false
			_te = false
			_otn = _tn
			_tn = ""
			_ott = _tt
			_tt = ""
			_ota = _ta
			_ta = {}
		end
		if not _st then
			if ch ~= "\r" and ch ~= "\n" and ch ~= "\t" then
				_tt = _tt .. ch
			else
				if _ttcdata then
					if string.sub(_tt, string.len(_tt)-2) == "]]>" then -- minus length of ]]>
						_tt = string.sub(_tt, 1, string.len(_tt)-3)
						_ttcdata = false
					else
						_tt = _tt .. ch
					end
				end
			end
			if _tt:sub(1, 1) == ">" then
				_tt = ""
			end
		end
		i = i + 1
	end
	if _ttcdata then
		error("EOF in CDATA section, expected ]]>")
	end
    end) -- end of pcall
    if not ok then
        error("error at line " .. tostring(line) .. ": " .. tostring(err))
    end
	return rootTag
end

function geeko.go(link)
	local schemeEnd = link:find("://", 1, true)
	local url, text = geeko.url(geeko.currentPath), ""

	if schemeEnd ~= nil then
		url = geeko.url(link)
		geeko.currentPath = link
	else
		if link:sub(1, 1) == "/" then
			geeko.currentPath = url.scheme .. "://" .. link
		else
			geeko.currentPath = url.scheme .. ":///" .. geeko.fs.parent(url.path) .. link
		end
		url = geeko.url(geeko.currentPath)
	end

	if url.scheme == "file" then
		text = geeko.fs.readAll(geeko.url(geeko.currentPath).path:sub(2))
	end

	parsed = geeko.parseXML(text) -- only works on Fuchas, to fix
	cx = 1
	cy = 1
	geeko.objects = {}
	geeko.clean()
	geeko.read(parsed)
	if geeko.renderCallback ~= nil and type(geeko.renderCallback) == "function" then
		geeko.renderCallback()
	else
		log("geeko", "warn", "render callback is not defined")
	end
	loadScripts(parsed)
	log("geeko", "info", "loaded " .. geeko.currentPath)
end

-- OS init
if OSDATA or _OSVERSION then -- Fuchas or OpenOS
	geeko.fs = fuchasIO()
	if OSDATA then
		geeko.mt = fuchasMT()
	else
		geeko.mt = openOSMT()
	end
elseif rednet then -- ComputerCraft
	geeko.fs = ccIO()
end

-- Geeko init
makeScriptEnv()

return geeko
