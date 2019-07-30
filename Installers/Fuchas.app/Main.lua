local GUI = require("GUI")
local system = require("System")
local image = require("Image")
local filesystem = require("Filesystem")
local internet = require("Internet")

local workspace, window, menu = system.addWindow(GUI.filledWindow(1, 1, 60, 20, 0xE1E1E1))
local localization = system.getCurrentScriptLocalization()

localization.tryit = localization.tryit or "Try It!"
localization.install = localization.install or "Install"

local layout = window:addChild(GUI.layout(1, 1, window.width, window.height, 1, 1))
local fuchasIcon = image.load(filesystem.path(system.getCurrentScript()) .. "/Logo.pic")
local icon = GUI.image(1, 1, fuchasIcon)
local tryButton = GUI.roundedButton(1, 1, 35, 5, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.tryit)
local installButton = GUI.roundedButton(1, 1, 13, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.install)
local progressText = GUI.text(1, 1, 0x555555, "Downloading..")

tryButton.onTouch = function()
  GUI.alert("Not supported yet! Please Install")
end

local function extract(stream, progressBar)
  local dent = {
    magic = 0,
    dev = 0,
    ino = 0,
    mode = 0,
    uid = 0,
    gid = 0,
    nlink = 0,
    rdev = 0,
    mtime = 0,
    namesize = 0,
    filesize = 0
  }
  local function readint(amt, rev)
    local tmp = 0
    for i=1, amt do
      tmp = bit32.bor(tmp, bit32.lshift(stream:readBytes(1), ((i-1)*8)))
    end
    return tmp
  end
  local function fwrite()
    local dir = dent.name:match("(.+)/.*%.?.+")
    if (dir) then
      filesystem.makeDirectory("/" .. dir)
    end
    local hand = filesystem.open("/" .. dent.name, "w")
    hand:write(stream:readString(dent.filesize))
    hand:close()
  end
  while true do
    dent.magic = readint(2)
    local rev = false
    if (dent.magic ~= tonumber("070707", 8)) then rev = true end
    dent.dev = readint(2)
    dent.ino = readint(2)
    dent.mode = readint(2)
    dent.uid = readint(2)
    dent.gid = readint(2)
    dent.nlink = readint(2)
    dent.rdev = readint(2)
    dent.mtime = bit32.bor(bit32.lshift(readint(2), 16), readint(2))
    dent.namesize = readint(2)
    dent.filesize = bit32.bor(bit32.lshift(readint(2), 16), readint(2))
    local name = stream:read(dent.namesize):sub(1, dent.namesize-1)
    if (name == "TRAILER!!!") then break end
    dent.name = name
    progressText.text = "Extracting " .. dent.name
    progressBar:roll()
    workspace:draw()
    require("Screen").update()
    if (dent.namesize % 2 ~= 0) then
      stream:seek("cur", 1)
    end
    if (bit32.band(dent.mode, 32768) ~= 0) then
      fwrite()
    end
    if (dent.filesize % 2 ~= 0) then
      stream:seek("cur", 1)
    end
  end
end

local function install(progressBar)
  local url = "https://raw.githubusercontent.com/zenith391/Fuchas/master/release.cpio"
  internet.download(url, "/Temporary/fuchas.cpio")
  local stream, err = filesystem.open("/Temporary/fuchas.cpio", "rb")
  if not stream then
    error(err)
  end
  extract(stream, progressBar)
  stream:close()
  internet.download("https://raw.githubusercontent.com/zenith391/Fuchas/master/init.lua", "/init.lua")
end

installButton.onTouch = function()
  tryButton:remove()
  installButton:remove()
  local progressBar = GUI.progressIndicator(1, 1, 0x3C3C3C, 0x00B640, 0x99FF80)
  progressBar.active = true
  layout:addChild(progressBar)
  layout:addChild(progressText)
  install(progressBar)
  filesystem.rename("/OS.lua", "/_OS.lua")
  progressBar:remove()
  progressText.text = "If you want to get back to MineOS. Type 'cp _OS.lua A:/OS.lua' in Fuchas"
end

layout:addChild(icon)
layout:addChild(tryButton)
layout:addChild(installButton)

window.onResize = function(newWidth, newHeight)
  window.backgroundPanel.width, window.backgroundPanel.height = newWidth, newHeight
  layout.width, layout.height = newWidth, newHeight
end

---------------------------------------------------------------------------------

-- Draw changes on screen after customizing your window
workspace:draw()
