if type -q atuin
    set -gx ATUIN_NOBIND true

    set -l format_string (
        echo -ns "{time}";
        set_color $fish_color_user;
        echo -ns " {user}";
        set_color normal;
        echo -ns "@";
        set_color $fish_color_host_remote;
        echo -ns "{host}";
        set_color normal;
        echo -ns " │ {command}";
    )\n\n

    function _atuin_fzf_format -V format_string
        switch (uname)
            case Darwin
                string replace -ra '\n{2,}' '\x00' "$(atuin search --format "$format_string" $argv)" | tail -r | tail -c +1 | tail -r
            case '*'
                string replace -ra '\n{2,}' '\x00' "$(atuin search --format "$format_string" $argv)" | head -c -1
        end
    end
end
