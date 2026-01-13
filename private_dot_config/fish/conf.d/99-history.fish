function __history_up
    if commandline --search-mode; or commandline --paging-mode
        up-or-search
        return
    end

    set -l lineno (commandline --line)
    switch $lineno
        case 1
            $argv
        case '*'
            up-or-search
    end
end

function _set_history_bindings
    argparse 'u/up=' 'r/ctrl-r=' -- $argv
    or return

    if functions -q fzf_configure_bindings
        fzf_configure_bindings --history=
    end

    set -l up_opts (string split -n , $_flag_up)
    set -l ctrl_r_opts (string split -n , $_flag_ctrl_r)

    set -l up_mode
    set -l ctrl_r_mode

    if type -q atuin
        if contains atuin $up_opts
            set -a up_mode '+atuin'
        end
        if contains atuin $ctrl_r_opts
            set -a ctrl_r_mode '+atuin'
        end
    end

    if functions -q _fzf_search_history
        if contains fzf $up_opts
            set -a up_mode '+fzf'
        end

        if contains fzf $ctrl_r_opts
            set -a ctrl_r_mode '+fzf'
        end
    end

    set -l up_cmd up-or-search
    set -l ctrl_r_cmd history-pager

    switch (string join '' $up_mode)
        case '+atuin+fzf'
            set up_cmd "__history_up _atuin_fzf_search --filter-mode=session --shell-up-key-binding"
        case '+fzf'
            set up_cmd "__history_up _fzf_search_history"
        case '+atuin'
            set up_cmd _atuin_bind_up
    end

    switch (string join '' $ctrl_r_mode)
        case '+atuin+fzf'
            set ctrl_r_cmd _atuin_fzf_search
        case '+fzf'
            set ctrl_r_cmd _fzf_search_history
        case '+atuin'
            set ctrl_r_cmd _atuin_search
    end

    bind up "$up_cmd"
    bind -M insert up "$up_cmd"

    bind \cr "$ctrl_r_cmd"
    bind -M insert \cr "$ctrl_r_cmd"
end
