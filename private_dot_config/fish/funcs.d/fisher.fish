function fisher
end

if set -q fisher_path; and test -f $fisher_path/functions/fisher.fish
    sed -e 's/status fish-path/_fish_path/g' $fisher_path/functions/fisher.fish | source
end
