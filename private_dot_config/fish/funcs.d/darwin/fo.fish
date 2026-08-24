function fo -a dir_arg
    if set -q dir_arg; and test -d "$dir_arg"
        open -a Finder "$dir_arg"
    else
        open -a Finder (pwd)
    end
end
