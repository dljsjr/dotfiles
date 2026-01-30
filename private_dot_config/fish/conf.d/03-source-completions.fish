if type -q chezmoi
    chezmoi completion fish | source
end

if type -q mise; and type -q usage
    mise completion fish | source
end

if type -q op
    op completion fish | source
end

if type -q gh
    gh completion -s fish | source
end

# if type -q jj
#     COMPLETE=fish jj | source
# end
