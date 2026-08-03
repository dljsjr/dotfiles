local StringUtils = spoon_require("utils.strings")
local OsExt = spoon_require("utils.os_ext")

local ABSOLUTE_ROOT_PATTERN = "^/"
local SYSTEM_SEPARATOR = package.config:sub(1, 1) -- gives '/' on Unix and '\' on Windows

---@param str string
---@param separator string
---@return string[]
local function __extractSegments(str, separator)
    assert(
        type(str) == "string",
        string.format("expected type 'string' for arg #1, received %s", type(str))
    )

    assert(
        type(separator) == "string",
        string.format("expected type 'string' for arg #2, received %s", type(str))
    )

    if #str == 0 or #separator == 0 then return { str } end

    local cursor = 1
    local segments = {}
    local pattern = string.format("[^\\]%s", separator)
    while cursor <= #str do
        local foundStart, foundEnd = string.find(str, pattern, cursor)
        -- if foundStart is `nil`, we're done, so we just add the rest of the string as the final
        -- segment
        local nextSegment = str:sub(cursor, foundStart)
        table.insert(segments, nextSegment)
        cursor = (foundEnd and foundEnd + 1) or (#str + 1)
    end
    return segments
end

---Path abstraction
---@class Path
---@field package segments string[]
---@field package __separator string
---@field package __isAbsolute boolean
local Path = {}
Path.__index = Path
Path.__metatable = Path

function Path:__tostring()
    return (self.__isAbsolute and "/" or "") .. table.concat(self.segments, self.__separator)
end

function Path:__eq(other)
    if not (type(other) == "table" and getmetatable(other) == Path) then
        return false
    end

    local selfResolved = self:resolve({ follow = true, strict = false })
    local otherResolved = self:resolve({ follow = true, strict = false })
    return tostring(selfResolved) == tostring(otherResolved)
end

function Path:__len()
    return #(self.segments)
end

---@param segments string[]
---@return Path
local function __newFromSegments(segments)
    local isAbsolute = (string.find(segments[1], ABSOLUTE_ROOT_PATTERN) ~= nil)
    if isAbsolute then
        segments[1] = segments[1]:gsub(ABSOLUTE_ROOT_PATTERN, "")
    end
    ---@type Path
    return setmetatable({
        segments = segments,
        __separator = SYSTEM_SEPARATOR,
        __isAbsolute = isAbsolute
    }, Path)
end

local function __newFromVarargs(...)
    local numArgs = select("#", ...)
    local segments = {}
    for i = 1, numArgs do
        local nextSegment = select(i, ...)
        local segmentType = type(nextSegment)
        assert(segmentType == "string",
            string.format("invalid input type for Path constructor, expected 'string' but got '%s'", segmentType))
        table.insert(segments, nextSegment)
    end

    return __newFromSegments(segments)
end

local function __newFromString(val)
    return __newFromSegments(__extractSegments(val, SYSTEM_SEPARATOR))
end


local function __newPathInner(kwargs, ...)
    local newPath = Path.new(...)
    if type(kwargs) == "table" then
        if type(kwargs.isAbsolute) == "boolean" then
            newPath.__isAbsolute = kwargs.isAbsolute
        end

        if type(kwargs.separator) == "string" then
            newPath.__separator = kwargs.separator
        end
    end

    return newPath
end

---@param pathA Path
---@param pathB Path
---@return Path
local function __joinPaths(pathA, pathB)
    assert(pathA.__separator == pathB.__separator,
        string.format("Cannot join paths with different separators ('%s' and '%s')", pathA.__separator, pathB
            .__separator))
    local clonedSegments = table.pack(table.unpack(pathA.segments))
    if pathB.__isAbsolute then
        log.wf("cannot join an absolute path to an existing path")
    else
        for _, segment in ipairs(pathB.segments) do
            table.insert(clonedSegments, segment)
        end
    end
    return __newPathInner({
        isAbsolute = pathA.__isAbsolute,
        separator = pathA.__separator
    }, clonedSegments)
end

---@param path Path
---@return Path
local function __clonePath(path)
    return __newPathInner({
        isAbsolute = path.__isAbsolute,
        separator = path.__separator
    }, table.unpack(path.segments))
end

---@param ... string a list of path segments
---@return Path
---@overload fun(path: string|string[]): Path a path or a list of path segments
function Path.new(...)
    local numArgs = select("#", ...)
    if numArgs < 1 or ... == nil then
        return __newFromString(".")
    end

    local firstArg = select(1, ...)
    if numArgs == 1 and type(firstArg) == "string" then
        return __newFromString(firstArg)
    end

    if numArgs == 1 and type(firstArg) == "table" then
        return __newFromVarargs(table.unpack(firstArg))
    end

    return __newFromVarargs(...)
end

function Path:join(other)
    if type(other) == "table" and getmetatable(other) == Path then
        return __joinPaths(self, other)
    end

    return __joinPaths(self, __newPathInner(nil, other))
end

Path.__div = Path.join

function Path:ensureExt(extension)
    local filePart = self.segments[#self]
    if StringUtils.endsWith(filePart, "." .. extension) then
        return self
    end
    filePart = string.format("%s.%s", filePart, extension)
    self.segments[#self] = filePart
    return self
end

function Path:with_separator(separator)
    assert(type(separator) == "string", string.format("Expected argument of type 'string', got %s", type(separator)))
    self.__separator = separator
    return self
end

function Path:absolute()
    local cloned = __clonePath(self)
    if cloned.__isAbsolute then
        return cloned
    end

    if cloned.segments[1] == "." then
        table.remove(cloned.segments, 1)
    end

    local pwd = __newPathInner(nil, OsExt.pwd())
    return __joinPaths(pwd, cloned)
end

---@param resolve_opts nil|{ follow: boolean?, strict: boolean? } table of keyword args.
---
---Kwargs:
---
---strict (default to false if absent): if 'strict' is true, then return nil if the
---resolved path doesn't exist or there are other errors, such as issues following symlinks.
---
---follow (default to true if absent): if 'follow' is true, then symlinks are resolved if their targets exist.
---If 'strict' is also true, and any symlinks don't resolve properly, then the operation
---will fail.
---@return Path? path the resolved path, nil on error
---@return string? err the error message on failure, nil on success
function Path:resolve(resolve_opts)
    local strict = (resolve_opts or {}).strict or false
    local follow = (resolve_opts or {}).follow or true

    local expanded = __newPathInner(nil, OsExt.expanduser(OsExt.expandvars(self))):absolute()

    local resolvedSegments = {}
    for _, segment in ipairs(expanded.segments) do
        if segment == ".." then
            table.remove(resolvedSegments)
        elseif segment ~= "." then
            table.insert(resolvedSegments, segment)
        end
    end

    if follow then
        local pathString = table.concat(resolvedSegments, self.__separator)
        local success, output = OsExt.realpath(pathString)

        if not success then
            if strict then
                return nil, string.format("failed to resolve path: %s", output.stderr)
            end
        else
            resolvedSegments = __extractSegments(output.stdout, self.__separator)
        end
    end

    return __newPathInner({ isAbsolute = true }, resolvedSegments)
end

function Path:basename()
    return self.segments[#self]
end

function Path:dirname()
    return __newPathInner({
        isAbsolute = self.__isAbsolute,
        separator = self.__separator
    }, table.unpack(self.segments, 1, #self - 1))
end

function Path:iter_parents()
    local parents = self:dirname()
    local currentDepth = nil
    return function()
        if not currentDepth then
            currentDepth = #parents
        else
            currentDepth = currentDepth - 1
        end

        if currentDepth > 0 then
            return __newPathInner({
                isAbsolute = parents.__isAbsolute,
                separator = parents.__separator
            }, table.unpack(parents.segments, 1, currentDepth))
        end

        if currentDepth == 0 and parents.__isAbsolute then
            return Path.new("/")
        end
    end
end

function Path:last_extension()
    local lastMatch
    for match in string.gmatch(self:basename(), "(%.[^%.]*)") do
        lastMatch = match
    end
    return lastMatch
end

function Path:all_extensions()
    local exts = {}
    for match in string.gmatch(self:basename(), "(%.[^%.]*)") do
        table.insert(exts, match)
    end
    if #exts > 0 then
        return exts
    end
    return nil
end

function Path:extension()
    local extensions = self:all_extensions()

    return (extensions and table.concat(extensions, "")) or nil
end

function Path:exists()
    return OsExt.exists(self) == true
end

function Path:isFile()
    return OsExt.isfile(self) == true
end

function Path:isDirectory()
    return OsExt.isdir(self) == true
end

function Path:isExecutable()
    return OsExt.isexecutable(self) == true
end

function Path:isSymlink()
    return OsExt.islink(self) == true
end

function Path:create(ensureParents)
    assert(not self:exists(), string.format("Could not create %s: already exists!", self))

    if ensureParents == true then
        local parentPath = self:dirname()
        local mkdirSuccess, mkdirErr = OsExt.mkdir(parentPath, { ensureParents = true, existsOk = true })
        assert(mkdirSuccess, string.format("Failed to ensure parent directory %s exists: %s", parentPath, mkdirErr))
    end

    local createSuccess, createErr = OsExt.touch(self)
    assert(createSuccess, string.format("Failed to create file %s: %s", self, createErr))
    return self
end

return Path
