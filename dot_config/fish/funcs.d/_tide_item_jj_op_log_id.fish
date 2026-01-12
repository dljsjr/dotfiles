set -U tide_jj_op_log_id_icon ·
set -U tide_jj_op_log_id_icon_color black
set -U tide_jj_op_log_id_color black
set -U tide_jj_op_log_id_bg_color green

function __jj_op_log_id
    jj root >/dev/null && jj op log --ignore-working-copy --limit 1 --no-graph --template 'id.short(8)'
end

function _tide_item_jj_op_log_id
    _tide_print_item jj_op_log_id (set_color $tide_jj_op_log_id_icon_color)$tide_jj_op_log_id_icon$(set_color $tide_jj_op_log_id_color)' '(__jj_op_log_id)
end
