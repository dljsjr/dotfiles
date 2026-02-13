if type -q atuin
    _update_completions atuin gen-completions --shell fish
end

if type -q chezmoi
    _update_completions chezmoi completion fish
end

if type -q mise; and type -q usage
    _update_completions --current-version="$(mise version --silent --quiet 2>/dev/null)" mise completion fish
end

if type -q op
    _update_completions op completion fish
end

if type -q gh
    _update_completions gh completion -s fish
end

if type -q jj
    # Capture explicitly because the complete env var will muck
    # up the version command.
    set -f JJ_VERSION (jj --version 2>/dev/null)
    COMPLETE=fish _update_completions --current-version="$JJ_VERSION" jj
end

if type -q zellij
    _update_completions zellij setup --generate-completion fish
end
