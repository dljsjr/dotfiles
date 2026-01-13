hs.logger.setGlobalLogLevel('debug')

-- configs
hs.accessibilityState(true)
hs.allowAppleScript(true)
hs.autoLaunch(true)
hs.automaticallyCheckForUpdates(true)
hs.consoleOnTop(true)
hs.dockIcon(false)
hs.menuIcon(true)
hs.screenRecordingState(true)

------ START WM Config
local wm = require("windows")
hs.hotkey.bind({"ctrl", "alt"}, "Return", wm.fillScreenWithCycle)
------ END WM Config

-- check for CLI installation
__IPC_MODULE = __IPC_MODULE or nil
HS_CLI_INSTALL_PREFIX = nil
if hs.processInfo.arch == "arm64" then
  HS_CLI_INSTALL_PREFIX = "/opt/hammerspoon"
end

local status = hs.ipc.cliStatus(HS_CLI_INSTALL_PREFIX)
hs.alert.show(string.format("status: %s", status))
if not status then
  hs.alert.show "Installing IPC CLI"
  local success = hs.ipc.cliInstall(HS_CLI_INSTALL_PREFIX)
  if success then
    hs.alert.show "IPC CLI installation successful, restarting Hammerspoon"
    hs.relaunch()
  else
    hs.showError "Failed to install HS IPC CLI"
  end
end

-- load IPC module
if status and not __IPC_MODULE then
  __IPC_MODULE = require('hs.ipc')
end
