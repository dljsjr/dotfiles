local m = {}

function m.pwd()
    return hs.fs.currentDir()
end

local CACHED_USERNAME
function m.username()
    if type(CACHED_USERNAME) == "string" then
        return CACHED_USERNAME
    end
    CACHED_USERNAME = os.getenv("USER")
    return CACHED_USERNAME
end

function m.homedir(username)
    local user = username or m.username()
    return hs.fs.pathToAbsolute(string.format("~%s", user))
end

function m.expandvars(shellString)
    if type(shellString) ~= "string" then shellString = tostring(shellString) end
    local expanded = string.gsub(shellString, "%$(%w*)", function(varName)
        return os.getenv(varName) or string.format("$%s", varName)
    end)

    expanded = string.gsub(expanded, "%$%{([^%}]*)%}", function(varName)
        return os.getenv(varName) or string.format("${%s}", varName)
    end)

    return expanded
end

function m.expanduser(pathString)
    if type(pathString) ~= "string" then pathString = tostring(pathString) end
    local findStart, _, maybeUsername = string.find(pathString, "^~(%w*)")
    if not findStart then
        return pathString
    end
    local homedir = m.homedir(maybeUsername)
    local replaced = string.gsub(pathString, "^~(%w*)", homedir)
    return replaced
end

function m.realpath(pathString)
    if type(pathString) ~= "string" then pathString = tostring(pathString) end
    return hs.fs.pathToAbsolute(pathString)
end

function m.exists(pathString)
    if type(pathString) ~= "string" then pathString = tostring(pathString) end
    return hs.fs.attributes(pathString) ~= nil
end

function m.isfile(pathString)
    if type(pathString) ~= "string" then pathString = tostring(pathString) end
    return hs.fs.attributes(pathString, "mode") == "file"
end

function m.isdir(pathString)
    if type(pathString) ~= "string" then pathString = tostring(pathString) end
    return hs.fs.attributes(pathString, "mode") == "directory"
end

function m.islink(pathString)
    if type(pathString) ~= "string" then pathString = tostring(pathString) end
    return hs.fs.symlinkAttributes(pathString, "mode") == "link"
end

function m.mkdir(pathString, kwargs)
    if type(pathString) ~= "string" then pathString = tostring(pathString) end
    local exists = m.exists(pathString) == true

    if type(kwargs) == "table" then
        if kwargs.existsOk ~= true and exists then
            return nil, string.format("failed to create directory (existsOk = false): %s already exists", pathString)
        end

        if kwargs.existsOk == true and exists and not m.isdir(pathString) then
            return nil,
                string.format(
                    "failed to create directory (existsOk = true): %s already exists but is *not* a directory!",
                    pathString)
        end
    end

    if kwargs.ensureParents == true then
        return os.execute(string.format([[mkdir -p '%s']], pathString))
    end
    return hs.fs.mkdir(pathString)
end

function m.touch(pathString)
    if type(pathString) ~= "string" then pathString = tostring(pathString) end
    return hs.fs.touch(pathString)
end

return m
