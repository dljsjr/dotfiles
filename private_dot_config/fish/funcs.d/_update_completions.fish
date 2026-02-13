function _update_completions
    argparse --name '_update_completions' --min-args 1 --strict-longopts --stop-nonopt C/current-version=+ v/verbose -- $argv
    or return

    set -f cli $argv[1]
    set -e argv[1]

    set -f __VARNAME __"$cli"_VERSION
    set -f __EXISTING_VERSION ""

    if set -q $__VARNAME
        set -f __EXISTING_VERSION "$$__VARNAME"
    end

    set -f __CURRENT_VERSION ""
    if set -q _flag_current_version
        set -f __CURRENT_VERSION "$_flag_current_version"
    else
        set -f __CURRENT_VERSION ($cli --version 2>/dev/null)
    end

    if test ! \( "$__EXISTING_VERSION" = "$__CURRENT_VERSION" -a -f "$__fish_config_dir/completions/$cli.fish" \)
        if set -q _flag_verbose
            printf "updating completions for %s\n\texisting version: %s\n\tcurrent version: %s\n" "$cli" "$__EXISTING_VERSION" "$__CURRENT_VERSION"
        end
        $cli $argv | tee "$__fish_config_dir/completions/$cli.fish" | source
        set -Ux "$__VARNAME" "$__CURRENT_VERSION"
    end
end
