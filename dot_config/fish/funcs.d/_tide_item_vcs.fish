function _tide_item_vcs
    if type -q jj; and jj root >/dev/null 2>&1
        _tide_item_jj
        _tide_item_jj_op_log_id
        set_color normal
    else
        if not set -q _tide_location_color
            set_color $tide_git_color_branch | read -gx _tide_location_color
        end
        _tide_item_git
    end
end
