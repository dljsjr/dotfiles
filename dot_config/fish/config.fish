set -U fish_greeting

if status is-interactive
    if functions -q __wezterm_set_user_var
        __wezterm_set_user_var WEZTERM_HOME "$HOME"
        __wezterm_set_user_var WEZTERM_USER "$USER"
        __wezterm_set_user_var WEZTERM_HOSTNAME "$hostname"
        __wezterm_set_user_var WEZTERM_REMOTE 1

        function __wezterm_preexec --on-event fish_preexec
            __wezterm_set_user_var WEZTERM_PROG "$argv[1]"
        end

        function __wezterm_postexec --on-event fish_postexec
            __wezterm_set_user_var WEZTERM_PROG ""
            __wezterm_set_user_var WEZTERM_TICK ""
        end

        function __wezterm_pwd --on-variable PWD
            __wezterm_set_user_var WEZTERM_PWD "file://$hostname/$PWD"
        end
        __wezterm_pwd
    end

    if functions -q _set_history_bindings
        _set_history_bindings --up=fzf,atuin --ctrl-r=fzf,atuin
    end
end
