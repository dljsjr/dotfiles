function fish_prompt
end

if set -q fisher_path; and test -f $fisher_path/functions/fish_prompt.fish
    sed -e 's/status fish-path/_fish_path/g' $fisher_path/functions/fish_prompt.fish | source
end
