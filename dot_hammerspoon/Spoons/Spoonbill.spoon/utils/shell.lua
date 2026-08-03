local StringUtils = spoon_require("utils.strings")

local SAFE_SHELL_CHARS = [[%+,-./0123456789:=@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz]]

local SAFE_SHELL_CHARSET_MAP = {}
for _, charbyte in ipairs(table.pack(string.byte(SAFE_SHELL_CHARS, 1, #SAFE_SHELL_CHARS))) do
    SAFE_SHELL_CHARSET_MAP[charbyte] = true
end

local function __isSafeChar(c)
    return SAFE_SHELL_CHARSET_MAP[string.byte(c)]
end

local function __isSafeStr(str)
    for char in str:gmatch(".") do
        if not __isSafeChar(char) then
            return false
        end
    end
    return true
end

---Shell utils
---!doctype module
---@class utils.shell
local m = {}

local function __setupShell(login, interactive, shellCmd)
    local shell = os.getenv("SHELL") or shellCmd or "/bin/sh"
    local cmdArg = shell
    if login == true then
        cmdArg = string.format("%s -l", cmdArg)
    end
    if interactive == true then
        cmdArg = string.format("%s -i", cmdArg)
    end

    return cmdArg
end
---@class utils.shell.ProcReturnInfo
---@field public exitType string
---@field public returnCode integer

---Execute a command, ignoring output
---@param cmd string|string[]|table a command representation
---@param login boolean? if true, use a login shell to run the command
---@param interactive boolean? if true, use an interactive shell to run the command
---@param shellCmd string? path to the shell binary to use; if nil, defaults to the environment's $SHELL variable, with "/bin/sh" as the fallback
---@return boolean,utils.shell.ProcReturnInfo
function m.call(cmd, login, interactive, shellCmd)
    local quoted, quotedErr = m.quote(cmd)
    if not quoted then
        log.e(quotedErr)
    end
    local cmdArg = __setupShell(login, interactive, shellCmd)
    local status, exitType, returnCode = os.execute(string.format("%s -c %s", cmdArg, quoted))
    return (status == true), { exitType = exitType, returnCode = returnCode }
end

---@class utils.shell.ProcOutput: utils.shell.ProcReturnInfo
---@field public stdout string
---@field public stderr string

---Execute a command, with output capture
---@param cmd string|string[]|table a command representation
---@param login boolean? if true, use a login shell to run the command
---@param interactive boolean? if true, use an interactive shell to run the command
---@param shellCmd string? path to the shell binary to use; if nil, defaults to the environment's $SHELL variable, with "/bin/sh" as the fallback
---@return boolean?,utils.shell.ProcOutput|string If the command is able to be executed, then the return value will be 'true' or 'false' for success status, followed by the process return information.
---If there is an I/O error attempting to execute the command, then the return values will be 'nil', '<error message>'
function m.run(cmd, login, interactive, shellCmd)
    local quoted, quotedErr = m.quote(cmd)
    if not quoted then
        log.e(quotedErr)
    end

    local cmdArg = __setupShell(login, interactive, shellCmd)
    local tmpStderr = os.tmpname()
    local stderrFd, tmpfileErr = io.open(tmpStderr, "w+")
    if not stderrFd then
        log.w(string.format("failed to open tmpfile for stderr: %s", tmpfileErr))
    end
    local procFd, popenErr = io.popen(string.format("%s -c %s 2> %s", cmdArg, quoted, tmpStderr), 'r')
    if not procFd then
        if stderrFd then
            stderrFd:close()
        end
        return nil, string.format("couldn't open command file handle: %s", popenErr)
    end

    local procStdout = procFd:read('*a')
    local procStderr = nil
    if stderrFd then
        procStderr = stderrFd:read('*a')
        stderrFd:close()
    end
    local status, exitType, returnCode = procFd:close()
    return (status == true),
        { stdout = (procStdout or ""), stderr = (procStderr or ""), exitType = exitType, returnCode = returnCode }
end

---shell escape a command string
---
---@param input string|string[]|table If input is a table, it must either be an array of strings, or it must implement __tostring explicitly
---It's up to the implementor of __tostring to make sure that the implementation makes sense for being used as a shell command.
---
---@return string|nil escaped the escaped string, or nil on error
---@return nil|string err an error message describing why the shell quoting failed
function m.quote(input)
    local maybeStringified, stringifyErr = StringUtils.flattenStringify(input)

    if maybeStringified then
        -- if it's all ASCII and in the safe set of characters, we can return it as-is
        if StringUtils.isAscii(maybeStringified) and __isSafeStr(maybeStringified) then
            return maybeStringified
        end
        return string.format("'%s'", maybeStringified:gsub("'", "'\\''"))
    end
    return nil, string.format("input problem: %s", stringifyErr)
end

function m.which(command)
    local status, output = m.run({ "command", "-v", command })
    if status then
        return output.stdout
    end
    return nil, string.format("command [%s] not found", command)
end

return m
