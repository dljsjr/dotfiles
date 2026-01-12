local log = hs.logger.new('WindowManager','debug')
--#region WM Config

local GRID_SIZE = 5
-- local HALF_GRID_SIZE = GRID_SIZE / 2

hs.grid.setGrid(string.format("%sx%s", GRID_SIZE, GRID_SIZE))
hs.grid.setMargins({0,0})
hs.grid.HINTS = {
  {'a','s','d','f','g'},
  {'h','j','k','l',';'},
}
hs.window.animationDuration = 0

--#endregion WM Config

--#region private functions

---@param window hs.window
---@return boolean
local function isWindowMaximized(window)
  local screenFrame = window:screen():frame()
  local winFrame = window:frame()

  return winFrame:equals(screenFrame)
end

---@param window hs.window
local function moveToNextScreen(window)
  window:moveToScreen(window:screen():previous(), false, true)
end

--#endregion private functions

---@class custom.WindowManager
local M = {}

---Tell the given window to fill the screen, i.e., "maximized" but not "Full Screen",
---native or otherwise. If the argument is nil, use the currently focused window.
---
---@param window hs.window? window to maximize, or the currently focused window if nil
function M.fillScreen(window)
  if not window then window = hs.window.focusedWindow() end

  if window then
    local screenFrame = window:screen():frame()
    window:setFrame(screenFrame)
  end
end

---If the given window or the currently focused window is already maximized, then cycle
---its position through the available screens. Otherwise, first maximize the window using
---[fillScreen](lua://custom.WindowManager.fillScreen)
---
---@param window hs.window? window to maximize, or the currently focused window if nil
function M.fillScreenWithCycle(window)
  if window == nil then window = hs.window.focusedWindow() end

  if window then
    if not isWindowMaximized(window)  then
      M.fillScreen(window)
    else
      moveToNextScreen(window)
    end
  end
end

return M
