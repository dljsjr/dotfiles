set -U tide_jj_conflict_icon '×'
set -U tide_jj_divergent_icon '󰃻'
set -U tide_jj_hidden_icon ''
set -U tide_jj_immutable_icon ''
set -U tide_jj_empty_icon ''
set -U tide_jj_bookmark_icon '󰃀 '
set -U tide_jj_multi_bookmark_icon '󰸕 '

set -U tide_jj_bookmarks_icon_color magenta
set -U tide_jj_conflict_icon_color red
set -U tide_jj_divergent_icon_color magenta
set -U tide_jj_hidden_icon_color blue
set -U tide_jj_immutable_icon_color yellow
set -U tide_jj_empty_icon_color green

set -U tide_jj_change_id_color magenta
set -U tide_jj_bookmarks_color magenta
set -U tide_jj_change_id_rest_color brblack
set -U tide_jj_description_color brblack

set -U tide_jj_bookmarks_truncation_strategy end
set -U tide_jj_bookmarks_truncation_length 20

set -U tide_jj_description_truncation_strategy end
set -U tide_jj_description_truncation_length 10

function __jj_prompt
    set bookmarks_icon_template 'raw_escape_sequence("'(set_color $tide_jj_bookmarks_icon_color)'") ++ if(bookmarks.len() == 1, "'$tide_jj_bookmark_icon'", "'$tide_jj_multi_bookmark_icon'")'
    switch $tide_jj_bookmarks_truncation_strategy
        case count
            set bookmarks_inner_template $bookmarks_icon_template' ++ raw_escape_sequence("'(set_color $tide_jj_bookmarks_color)'") ++ bookmarks.len()'
        case '*'
            set bookmarks_inner_template $bookmarks_icon_template' ++ raw_escape_sequence("'(set_color $tide_jj_bookmarks_color)'") ++ truncate_'$tide_jj_bookmarks_truncation_strategy'('$tide_jj_bookmarks_truncation_length', bookmarks, raw_escape_sequence("'(set_color $tide_jj_bookmarks_color)'") ++ "…")'
    end
    set bookmarks_template 'if(bookmarks.len() >= 1, '"$bookmarks_inner_template"', "")'
    jj root >/dev/null && jj log \
        --config "colors.change_id=$(string replace -r '^br' 'bright ' $tide_jj_change_id_color)" \
        --config "colors.rest=$(string replace -r '^br' 'bright ' $tide_jj_change_id_rest_color)" \
        --config "colors.bookmarks=$(string replace -r '^br' 'bright ' $tide_jj_bookmarks_color)" \
        --revisions @ --no-graph --ignore-working-copy --color always --limit 1 --template '
        separate(" ",
          change_id.shortest(4),
          '$bookmarks_template',
          concat(
            if(conflict, raw_escape_sequence("'(set_color $tide_jj_conflict_icon_color)'") ++ "'$tide_jj_conflict_icon'"),
            if(divergent, raw_escape_sequence("'(set_color $tide_jj_divergent_icon_color)'") ++ "'$tide_jj_divergent_icon'"),
            if(hidden, raw_escape_sequence("'(set_color $tide_jj_hidden_icon_color)'") ++ "'$tide_jj_hidden_icon'"),
            if(immutable, raw_escape_sequence("'(set_color $tide_jj_immutable_icon_color)'") ++ "'$tide_jj_immutable_icon'"),
            if(empty, raw_escape_sequence("'(set_color $tide_jj_empty_icon_color)'") ++ "'$tide_jj_empty_icon'"),
          ),
          raw_escape_sequence("'(set_color $tide_jj_description_color)'") ++ truncate_'$tide_jj_description_truncation_strategy'('$tide_jj_description_truncation_length', if(description.first_line().len() == 0,
            "(no description)",
            description.first_line()
          ), "…"),
        )
      '
end

function _tide_item_jj
    if test $PWD != $HOME
        _tide_print_item jj $tide_jj_icon' '(__jj_prompt)(set_color normal)
    end
end
