if type -q zellij
    if not test -f $HOME/.config/fish/completions/zellij.fish
        zellij setup --generate-completion fish >$HOME/.config/fish/completions/zellij.fish
    end
    if test -d "$HOME/.config/zide/bin"
        __prepend_path "$HOME/.config/zide/bin"
    end
end

function zj
    if ! type -q zellij
        printf "'zellij' not on \$PATH\n" >&2
        return 1
    end

    if test (count $argv) -eq 0
        set -l clients (zellij --session 'main' action list-clients)
        if test (count $clients) -gt 1
            zellij
        else
            zellij attach --create main
        end
        return
    end

    argparse --name=zj --ignore-unknown --stop-nonopt -- $argv
    or return

    set -f zellij_cmd zellij
    set -f maybe_subcmd $argv[1]

    argparse --ignore-unknown --stop-nonopt session= -- $argv[2..]
    or return

    set -f remaining $argv
    switch $maybe_subcmd
        case pick
            if set -q ZELLIJ
                zellij action launch-or-focus-plugin zellij:session-manager --floating
                return
            end

            set -l zellij_sessions (zellij list-sessions -n -s 2>/dev/null)
            if test (count $zellij_sessions) -gt 0
                printf "%s\n" $zellij_sessions | fzf --prompt 'Select Zellij Session' \
                    --height='~30%' \
                    --layout=reverse \
                    --info=inline \
                    --border \
                    --margin=1 \
                    --padding=1 \
                    --bind 'enter:become(zellij attach {})'
                return
            else
                printf "No active or serialized Zellij sessions available\n" >&2
                return 1
            end
        case window
            if set -q _flag_session
                set -a zellij_cmd attach --create "$_flag_session"
            end
        case popup pane tab
            if test -z "$_flag_session"; and set -q ZELLIJ_SESSION_NAME
                set _flag_session "$ZELLIJ_SESSION_NAME"
            end

            if test -z "$_flag_session"
                printf "'zj %s' must be called from a Zellij session or be given a --session argument\n" "$maybe_subcmd" >&2
                return 1
            end

            set -a zellij_cmd --session "$_flag_session" action
            switch $maybe_subcmd
                case popup
                    set -a zellij_cmd new-pane --floating
                case pane
                    set -a zellij_cmd new-pane
                case tab
                    set -a zellij_cmd new-tab
            end
    end

    set -a zellij_cmd $remaining

    $zellij_cmd
end
