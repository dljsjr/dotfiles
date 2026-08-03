local StringUtils = spoon_require("utils.strings")
local PathUtils = spoon_require("utils.paths")

---@alias SpoonRepoType
---| '"github"' # a github repository containing Spoon packages
---| '"local"' # a location on disk that contains Spoon packages
---| '"url"' # a URL from which Spoons can be downloaded

---@alias SpoonPackageType
---| '"packed"' # a .zip file containing the fully packaged Spoon
---| '"source"' # a directory containing a Spoon's lua source code

---@class SpoonSourceSpec A table that captures information on where to acquire a Spoon from.
---@field package repoType SpoonRepoType The repository type
---@field package packType SpoonPackageType The packaging type
---@field package hostname string? the hostname portion for the repo's URL for non-local sources; nil if repoType is `"local"`
---@field package path string the path containing the Spoons
local SpoonSourceSpec = {}
SpoonSourceSpec.__index = SpoonSourceSpec

---@param repoType SpoonRepoType
---@param packType SpoonPackageType
---@param path string
---@param hostname string?
---@return SpoonSourceSpec
function SpoonSourceSpec.new(repoType, packType, path, hostname)
    return setmetatable({
        repoType = repoType,
        packType = packType,
        hostname = hostname,
        path = path,
    }, SpoonSourceSpec)
end

---Create a new GitHub-based spec. If all arguments are left empty, this creates
---a source spec for the main Hammerspooon Spoons repo set to use the ['"packed"'](lua://SpoonPackageType) package type
---@param packType SpoonPackageType? The packing type, defaults to `'"packed"'` if nil
---@param spoonsDir string? the path under the repo with the spoon listings.
---defaults to '"Source"' if nil and `packType` is `'"source"'`, and '"Spoons"' if `packType` is `'"packed"'`.
---@param repoOwner string? The GitHub repo owner, defaults to '"Hammerspooon"' if nil
---@param repoName string? The GitHub repository, defaults to '"Spoons"' if nil
---@return SpoonSourceSpec
function SpoonSourceSpec.newGithub(packType, spoonsDir, repoOwner, repoName)
    local packType = packType or "packed"
    local spoonsDir = spoonsDir or (packType == "packed" and "Spoons" or "Source")
    local repoOwner = repoOwner or "Hammerspoon"
    local repoName = repoName or "Spoons"

    local path = string.format("repos/%s/%s/contents/%s", repoOwner, repoName, spoonsDir)

    return SpoonSourceSpec.new("github", packType, path, "api.github.com")
end

---Get the repo type for the source spec
---@return "github"|"local"|"url"
function SpoonSourceSpec:getRepoType()
    return self.repoType
end

---@param spoonName string
---@return table
function SpoonSourceSpec:makeSpoonUrl(spoonName)
    local urlScheme
    if self.repoType == "local" then
        urlScheme = "file"
    else
        urlScheme = "https"
    end

    local normalizedName = PathUtils.ensureExt(spoonName, "spoon")
    if self.packType == "packed" then
        normalizedName = PathUtils.ensureExt(normalizedName, "zip")
    end
    local urlTable = hs.http.urlParts(
        string.format("%s://%s/%s/%s", urlScheme, self.hostname or "", self.path, normalizedName)
    )
    return urlTable
end

return SpoonSourceSpec
