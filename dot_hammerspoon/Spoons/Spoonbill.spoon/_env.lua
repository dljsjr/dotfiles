_G["log"] = dofile(hs.spoons.resourcePath("log.lua")) "Spoonbill.spoon"
log.lineinfo = false
log.usecolor = false
log.datefmt = false
_G["log"] = log.hs_install()
log.setLogLevel("debug")

_G["spoon_require"] = function(req_path)
    local path_to_file = req_path:gsub("%.", "/")
    if path_to_file:sub(- #".lua") ~= ".lua" then
        path_to_file = path_to_file .. ".lua"
    end
    return dofile(hs.spoons.resourcePath(path_to_file))
end

DEFAULT_HAMMERSPOON_SPOONS_DIR = "~/.hammerspoon/Spoons"
DEFAULT_CONFIG_DIR = (os.getenv("XDG_CONFIG_HOME") or "~/.config") .. "/spoonbill"
DEFAULT_CONF_FILE_NAME = "config.json"
DEFAULT_DATA_DIR = (os.getenv("XDG_DATA_HOME") or "~/.local/share") .. "/spoonbill"
DEFAULT_CONFIG_VALUES = {
    use_gh_cli = false,
    enable_luarocks = false,
    data_dir = DEFAULT_DATA_DIR,
    spoons_dir = DEFAULT_HAMMERSPOON_SPOONS_DIR,
}
