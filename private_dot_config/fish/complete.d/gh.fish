if set -l og_completion (path filter -f $fish_complete_path/gh.fish | string match -m 1 --invert (status current-filename))
    source $og_completion
end

set -l subcommand get-license
complete -c gh -f -n "__fish_seen_subcommand_from $subcommand" -a "agpl-3.0 apache-2.0 bsd-2-clause bsd-3-clause bsl-1.0 cc0-1.0 epl-2.0 gpl-2.0 gpl-3.0 lgpl-2.1 mit mpl-2.0 unlicense"
