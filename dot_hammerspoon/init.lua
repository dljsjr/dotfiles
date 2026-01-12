hs.logger.setGlobalLogLevel('debug')

-- check for CLI installation
local status = hs.ipc.cliStatus()
if not status then
  hs.alert.show "Installing IPC CLI"
  local success = hs.ipc.cliInstall()
  if success then
    hs.alert.show "IPC CLI installation successful, restarting Hammerspoon"
    hs.relaunch()
  else
    hs.showError "Failed to install HS IPC CLI"
  end
end

-- load IPC module
if status then
  __IPC_MODULE = require('hs.ipc')
end

-- configs
hs.accessibilityState(true)
hs.allowAppleScript(true)
hs.autoLaunch(true)
hs.automaticallyCheckForUpdates(true)
hs.consoleOnTop(true)
hs.dockIcon(false)
hs.menuIcon(true)
hs.screenRecordingState(true)

-- Load Spoons
-- PaperWM = hs.loadSpoon("PaperWM")
-- Visor = hs.loadSpoon("Visor")
EmmyLua = hs.loadSpoon("EmmyLua")

------ START Visor Config
-- spoon.Visor:configureForKitty({
--   kitten = "$HOME/.local/bin/kitten",
--   height = 0.35, -- 1.0 is full height
--   opacity = 0.9 -- 0.0 is fully invisible, 1.0 is no transparency
-- })
-- spoon.Visor:bindHotKeys {
--   toggleTerminal = { {}, "f12" }
-- }
-- spoon.Visor:showOnDisplayBehavior(spoon.Visor.DisplayOptions.PrimaryDisplay)
-- spoon.Visor:start()
------ END Visor Config


------ START WM Config
local wm = require("windows")
hs.hotkey.bind({"ctrl", "alt"}, "Return", wm.fillScreenWithCycle)

-- PaperWM.window_gap = 0
-- 
-- 
-- local is_tiling = false
-- hs.hotkey.bind({"cmd", "alt", "ctrl"}, "p", function()
--   if is_tiling then
--     PaperWM:bindHotkeys({})
--     PaperWM:stop()
--     is_tiling = false
--   else
--     PaperWM:bindHotkeys(PaperWM.default_hotkeys)
--     PaperWM:start()
--     is_tiling = true
--   end
-- end)

------ END WM Config
