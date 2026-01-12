function __prepend_path
    prepend_pathvar $argv[1] PATH
end

function __append_path
    append_pathvar $argv[1] PATH
end

__prepend_path "$HOME/.local/bin"
