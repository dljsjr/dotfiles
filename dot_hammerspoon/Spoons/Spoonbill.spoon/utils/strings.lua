local m = {}

---Look for any characters that are not in the basic printable ascii range,
---and if there are any results at all, we return false
---@param s string
function m.isAscii(s)
    if string.find(s, "[^\0-\127]") then
        return false
    end
    return true
end

function m.endsWith(str, suffix)
    return str:sub(- #suffix) == suffix
end

local STRINGIFY_ALLOWED_TYPES = {
    ["string"] = true,
    ["table"] = true,
    ["boolean"] = true,
    ["number"] = true,
    ["nil"] = true
}

---If the input is string/boolean/number, return true.
---
---If the input is `nil`, return false.
---
---Otherwise, returns whether or not a table has an explicit `__tostring` implementation.
---Note that it specifically does *not* check for the `__name` metatable key.
---@param input any
---@return boolean
function m.hasToString(input)
    if input == nil then
        return false
    end
    local inputType = type(input)
    if inputType ~= "table" and STRINGIFY_ALLOWED_TYPES[inputType] then
        return true
    end

    local maybeMt = getmetatable(input) or {}
    local maybeDebugMt = (debug and type(debug.getmetatable) == "function" and debug.getmetatable(input)) or {}

    return (input.__tostring ~= nil) or (maybeMt.__tostring) ~= nil or (maybeDebugMt.__tostring) ~= nil
end

---Does the equivalent of applying `tostring` to the input if and only
---if the input type can be trivially coerced to a string, *or* if the type
---is a table that has a `__tostring` implementation. Types that aren't scalars
---or tables, or tables that don't have a `__tostring` implementation, will result in
---returning `nil`. Note that the presence of a `__name` key on a table's metatable does
---*not* result in `tostring` being applied; only a `__tostring` implementation is used.
---@param input any
---@return string? the equivalent of applying `tostring` to the input if the conditions are met, `nil` otherwise.
function m.maybeToString(input)
    if input == nil then
        return nil
    end

    local inputType = type(input)
    if inputType == "string" then
        return input
    end

    if STRINGIFY_ALLOWED_TYPES[inputType] and (inputType ~= "table" or m.hasToString(input)) then
        return tostring(input)
    end
    return nil
end

---Convert arguments to a single string.
---Only certain values can be stringified by this function.
---The 'string', 'boolean', and 'number' primitives work trivially.
---
---If the value is some form of userdata, it must have `__tostring` populated on it or on
---the value returned if `getmetatable` is called on it.
---
---If the value is a table, it must satisfy one of the following conditions:
--- 1. It must have respond to `__tostring` on itself or the value returned by `getmetatable`, or
--- 2. It must be an array of strings, or
--- 3. It must be an array of values that satisfy conditions (1) or (2) or the non-table conditions above
---
--- Non-array tables that do not provide a `__tostring` implementation cannot be used
---@param input any
---@param separator string? optional separator to use when concatenating arrays, defaults to a single space
---@return string? stringified The stringified result, or nil on error
---@return string? err the error message
function m.flattenStringify(input, separator)
    if m.hasToString(input) then
        return tostring(input)
    end

    local inputType = type(input)
    if inputType == "table" then
        -- If this crashes, something has gone quite wrong, but I've seen it crash
        local success, iterOrErr, iterable, startIdx = pcall(ipairs, input)
        if not success then
            return nil, string.format("Error constructing array iterator to stringify: %s", iterOrErr)
        end

        local stringified = {}
        for _, val in iterOrErr, iterable, startIdx do
            local maybeStringifiedChunk, err = m.flattenStringify(val)
            if not maybeStringifiedChunk then
                return nil, string.format("array element is not a valid component for flattenStringify: %s", err)
            end
            table.insert(stringified, maybeStringifiedChunk)
        end
        return table.concat(stringified, separator or " ")
    end

    return nil, string.format("cannot stringify %s", inputType)
end

function m.split(input, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    input:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

return m
