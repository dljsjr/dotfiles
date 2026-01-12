# tide configure --auto --style=Rainbow --prompt_colors='True color' --show_time='12-hour format' --rainbow_prompt_separators=Slanted --powerline_prompt_heads=Sharp --powerline_prompt_tails=Flat --powerline_prompt_style='Two lines, character and frame' --prompt_connection=Solid --powerline_right_prompt_frame=No --prompt_connection_andor_frame_color=Darkest --prompt_spacing=Sparse --icons='Many icons' --transient=Yes
set -g tide_prompt_min_cols 100000
set -g tide_prompt_add_newline_before true
set -g tide_prompt_pad_items true

set -g tide_pwd_icon_home "󰟒"
set -g tide_character_icon "❯"

set -g tide_cmd_duration_threshold 1
set -g tide_cmd_duration_decimals 2

set -g tide_jobs_number_threshold 1
set -g tide_context_always_display true

set -g tide_git_icon ""
set -g tide_git_bg_color normal
set -g tide_git_bg_color_unstable normal
set -g tide_git_bg_color_urgent normal
set -g tide_git_color_branch cyan
set -g tide_git_color_conflicted red
set -g tide_git_color_dirty bryellow
set -g tide_git_color_operation brred
set -g tide_git_color_staged yellow
set -g tide_git_color_stash brgreen
set -g tide_git_color_untracked green
set -g tide_git_color_upstream blue
set -g tide_git_truncation_length 20
set -g tide_git_truncation_strategy l

set -g tide_status_icon f
set -g tide_status_color green
set -g tide_status_icon '󰸞 '
set -g tide_status_icon_failure ''

set -g tide_right_prompt_items time cmd_duration always_status shlvl jobs

set -g tide_context_color_default $_host_unique_color
set -g tide_context_color_ssh $_host_unique_color
set -g tide_context_color_root red
set -g tide_context_bg_color $_host_unique_bg_color

set -g tide_ssh_indicator_color green
set -g tide_ssh_indicator_bg_color black
set -g tide_ssh_indicator_icon "󰢹"

set -g tide_jj_bg_color normal
set -g tide_jj_color cyan
set -g tide_jj_bookmarks_color brgreen
set -g tide_jj_bookmarks_icon_color brgreen
set -g tide_jj_bookmarks_truncation_strategy count
set -g tide_jj_icon ' '

set -g tide_jj_op_log_id_bg_color normal
set -g tide_jj_op_log_id_color brblue
set -g tide_jj_op_log_id_icon_color cyan
set -g tide_jj_op_log_id_icon '·'

set -l -a tools node python rustc go aws

for tool in $tools
    set -g tide_{$tool}_bg_color normal
end

set -g tide_left_prompt_separator_same_color ''

set -g tide_left_prompt_items os private_mode ssh_indicator context pwd direnv newline $tools vcs character
