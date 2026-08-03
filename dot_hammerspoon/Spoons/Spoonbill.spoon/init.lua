dofile(hs.spoons.resourcePath("_env.lua"))
local Path = spoon_require("utils.paths")
local SpoonSourceSpec = spoon_require("source_spec")

---Utilities for working with Spoons
---!doctype module
---@class Spoonbill.spoon
local m = {
    name = "Spoonbill",
    version = "1.0",
    author = "Doug Stephen <dljs.jr@dougstephenjr.com>",
    license = "MIT - https://opensource.org/licenses/MIT"
}

function m:init()
    log.v("init called")
    return self
end

local DEFAULT_SOURCE_SPEC = SpoonSourceSpec.newGithub()
local DEFAULT_CONFIG_FILE = Path.new(DEFAULT_CONFIG_DIR .. "/" .. DEFAULT_CONF_FILE_NAME)
m.configFile = DEFAULT_CONFIG_FILE
m.config = DEFAULT_CONFIG_VALUES
m.sourceSpecs = {
    ["default"] = DEFAULT_SOURCE_SPEC
}

function m:saveConfig()
    if not m.configFile:exists() then
        m.configFile:create(true)
    end

    hs.json.write(m.config, tostring(m.configFile), true, true)
end

function m:loadConfig(configFilePath)
    local cfgFile, pathErr = (
        (configFilePath and Path.new(configFilePath))
        or
        m.configFile):resolve()
    if
        cfgFile == DEFAULT_CONFIG_FILE and
        not DEFAULT_CONFIG_FILE:exists()
    then
        assert(DEFAULT_CONFIG_FILE:create(true), "couldn't create default config file!")
        m:saveConfig()
    end

    assert(cfgFile, string.format("Failed to create Path from %s: %s", m.configFile, pathErr))
    cfgFile:ensureExt("json")
    if not cfgFile:exists() then
        log.wf("Config file %s doesn't exist, using default configs", cfgFile)
        return self
    end

    local cfgJson = hs.json.read(tostring(cfgFile))
    if not cfgJson then
        log.ef("Couldn't load JSON data from %s, using default configs", cfgFile)
        return self
    end

    m.configFile = cfgFile
    m.config = cfgJson
    log.df("Loaded configs: %s", hs.inspect(m.config))
    return self
end

---Register a source spec
---@param name string the name to register the source spec under
---@param spec SpoonSourceSpec
---@param overwrite boolean? If 'true' and a spec is already registered under 'name', overwrite the existing spec
function m:registerSourceSpec(name, spec, overwrite)
    if self.sourceSpecs[name] and not overwrite then
        log.wf("Attempted to register source spec under name [%s] but name is already registered", name)
    else
        log.vf("Registering spec for name [%s]", name)
        self.sourceSpecs[name] = spec
    end
    return self
end

local function __handleGithubResponse(httpStatus, responseBody, responseHeaders, urlTable, sourceSpec)
end

---@param spoonName string Name of the Spoon to download
---@param sourceSpec string|SpoonSourceSpec|nil optional source spec to get the spoon from; can be a string identifying a spec previously registered or spec table to be used on-demand
function m:installSpoon(spoonName, sourceSpec)
    local spoonSource =
        (type(sourceSpec == "table") and sourceSpec) --[[@as SpoonSourceSpec]]
        or
        (type(sourceSpec) == "string" and self.sourceSpecs[sourceSpec])
        or
        DEFAULT_SOURCE_SPEC

    local spoonUrl = spoonSource:makeSpoonUrl(spoonName)

    local status, responseBody, responseHeaders = hs.http.get(spoonUrl.standardizedURL)

    if spoonSource:getRepoType() == "github" then
        __handleGithubResponse(status, responseBody, responseHeaders, spoonUrl, spoonSource)
    end

    return self
end

return m
