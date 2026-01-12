function ssh_reset
    argparse --name=ssh_reset -x d,s d/socksdir= s/socket= u/username= r/remote= p/port= -- $argv
    or return
    if set -ql _flag_socket
        if not test -S "$_flag_socket"
            printf "provided socket $_flag_s is not a socket file handle"
            return 1
        end

        set -f -a _control_socks $_flag_socket
    else if set -ql _flag_socksdir
        if not test -d "$_flag_socksdir"
            printf "socks dir is not a dir"
            return 1
        end
        for f in $_flag_socksdir/*
            if test -S "$f"
                set -f -a _control_socks "$f"
            end
        end
    else
        for f in ~/.ssh/controlmasters/*
            if test -S "$f"
                set -f -a _control_socks "$f"
            end
        end
    end

    if set -ql _flag_username
        set -f _control_user $_flag_username
    end

    if set -ql _flag_remote
        set -f _control_remote $_flag_remote
    end

    if set -ql _flag_port
        set -f _control_port $_flag_port
    end

    for f in $_control_socks
        string match --regex --groups-only '^(?<_matched_user>[^@]*)@(?<_matched_remote>[^(?:__)]*)(?:__)?(?<_matched_port>[0-9]+)?$' (basename $f) >/dev/null

        if not set -qf _control_user
            set -f _control_user $_matched_user
        end

        if not set -qf _control_remote
            set -f _control_remote $_matched_remote
        end

        if not set -qf _control_port
            if test -n "$_matched_port"
                set -f _control_port $_matched_port
            else
                set -f _control_port 22
            end
        end
        echo ssh -p $_control_port -O stop -S "$f" $_control_user@$_control_remote
        ssh -p $_control_port -O stop -S "$f" $_control_user@$_control_remote
    end
end
