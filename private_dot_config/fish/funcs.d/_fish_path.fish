# A portable way of getting the path to the current `fish` instance
# via its command line, as opposed to using `status fish-path`.
#
# `status fish-path` attempts to determine the canonical path to the
# fish binary; when this variable is stored and used in e.g. eval'd function
# definitions, it can cause problems. A great example of this is when Homebrew
# installs a new version of fish, which causes symlinks to change all over
# the place.
#
# So what we do here is we extract the command from the command line that was invoked
# to start the given login shell, and use that.
function _fish_path
    set -f ps_cmd (type -P --no-functions ps || echo "ps")
    type -p ($ps_cmd -o 'comm=' -p $fish_pid | string trim -l -c '-')
end
