function _tide_item_ssh_indicator
    if set -q SSH_TTY
        _tide_print_item ssh_indicator $tide_ssh_indicator_icon
    end
end
