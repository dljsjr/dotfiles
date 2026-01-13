if type -q fzf
    fzf --fish | source
end

if type -q zoxide
    zoxide init fish | source
end

if type -q op
    op completion fish | source
end

if type -q jira
    jira completion fish | source
end

if type -q gh
    gh completion -s fish | source
end

if type -q jj
    COMPLETE=fish jj | source
end

if type -q atuin
    atuin init fish | source
end
