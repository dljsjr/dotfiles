function _atuin_fzf_search
    argparse --ignore-unknown 'filter-mode=?' -- $argv
    or return

    set -l filter_mode global

    set -ql _flag_filter_mode
    and set filter_mode $_flag_filter_mode

    set -lx PARENT_ATUIN_SESSION $ATUIN_SESSION
    set -f commands_selected (_atuin_fzf_format --reverse --filter-mode $filter_mode $argv |
        _fzf_wrapper \
            --read0 \
            --print0 \
            --multi \
            --scheme=history \
            --ansi \
            --prompt "History [$filter_mode] > " \
            --preview="string replace -r '^[^│]*│' '' -- {} | string trim | fish_indent --ansi" \
            --preview-window="bottom:10:wrap" \
            --query (commandline) \
            --bind 'ctrl-r:transform:
set -l next_mode
set -l reload_cmd
if string match -qr "\[global\]" {fzf:prompt}
    set next_mode "host"
else if string match -qr  "\[host\]" {fzf:prompt}
    set next_mode "session"
else if string match -qr  "\[session\]" {fzf:prompt}
    set next_mode "directory"
else if string match -qr  "\[directory\]" {fzf:prompt}
    set next_mode "workspace"
else
    set next_mode "global"
end
echo "change-prompt(History [$next_mode] > )+reload:ATUIN_SESSION=$PARENT_ATUIN_SESSION _atuin_fzf_format --reverse --filter-mode $next_mode '"$argv"' -- {q}"
' \
            $fzf_history_opts | string split0 | string replace -r '^[^│]*│' '' | string trim)

    if test $status -eq 0
        commandline --replace -- $commands_selected
    end

    commandline --function repaint
end
