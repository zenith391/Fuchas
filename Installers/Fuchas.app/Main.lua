local GUI = require("GUI")
local system = require("System")
local image = require("Image")
local filesystem = require("Filesystem")

local workspace, window, menu = system.addWindow(GUI.filledWindow(1, 1, 60, 20, 0xE1E1E1))
local localization = system.getCurrentScriptLocalization()

localization.tryit = localization.tryit or "Try It!"
localization.install = localization.install or "Install"

local layout = window:addChild(GUI.layout(1, 1, window.width, window.height, 1, 1))
local fuchasIcon = image.load(filesystem.path(system.getCurrentScript()) .. "/Logo.pic")
local icon = GUI.image(1, 1, fuchasIcon)
local tryButton = GUI.roundedButton(1, 1, 35, 5, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.tryit)
local installButton = GUI.roundedButton(1, 1, 13, 3, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, localization.install)
layout:addChild(icon)
layout:addChild(tryButton)
layout:addChild(installButton)

-- Create callback function with resizing rules when window changes its' size
window.onResize = function(newWidth, newHeight)
  window.backgroundPanel.width, window.backgroundPanel.height = newWidth, newHeight
  layout.width, layout.height = newWidth, newHeight
end

---------------------------------------------------------------------------------

-- Draw changes on screen after customizing your window
workspace:draw()
