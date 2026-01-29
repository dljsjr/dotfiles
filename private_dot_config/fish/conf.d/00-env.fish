set -gx COLORTERM truecolor
set -g fish_term24bit 1
# set -Ux _host_unique_bg_color brblack
set -Ux _host_unique_color brwhite

# We prepend our own directories here to separate the stuff that we vendor via dotfiles from the
# stuff that plugins might install
set -U fisher_path $__fish_config_dir/fisher
set --prepend fish_function_path $fisher_path/functions
set --prepend fish_complete_path $fisher_path/completions
set --prepend fish_function_path "$__fish_config_dir/funcs.d"
set --prepend fish_complete_path "$__fish_config_dir/complete.d"

if not set -q _host_unique_bg_color
    set -l hex_chars 0 1 2 3 4 5 6 7 8 9 a b c d e f
    set -l gen_color

    # seed the RNG with a hex integer derived from hashing the hostname; the
    # double md5 hash is a janky way of introducing more variance
    random (math "0x$(echo -n "ssh://$USER@$hostname" | md5sum | md5sum | cut -c1-8)")

    for i in (seq 1 6)
        set -a gen_color (random choice $hex_chars)
    end

    set -Ux _host_unique_bg_color (string join '' $gen_color)
end

set -Ux fish_color_autosuggestion 808080
set -Ux fish_color_command blue

prepend_pathvar /etc/terminfo TERMINFO_DIRS
prepend_pathvar /lib/terminfo TERMINFO_DIRS
prepend_pathvar /usr/share/terminfo TERMINFO_DIRS
prepend_pathvar $HOME/.terminfo TERMINFO_DIRS
prepend_pathvar $HOME/.local/share/terminfo TERMINFO_DIRS

set -Ux TERMINFO_DIRS $TERMINFO_DIRS

if [ "$TERM" = xterm-kitty ]; and test -n $KITTY_PID; and test -n $KITTY_WINDOW_ID
    set -gx TERM_PROGRAM kitty
end

set -Ux EDITOR nvim
set -Ux VISUAL nvim
set -Ux ALTERNATE_EDITOR vim
set -Ux LESS -FRX

if test -s "$HOME/.cargo/env.fish"
    source "$HOME/.cargo/env.fish"
else if test -d "$HOME/.cargo/bin"
    prepend_pathvar "$HOME/.cargo/bin" PATH
end

if test -x "/home/linuxbrew/.linuxbrew/bin/brew"
    /home/linuxbrew/.linuxbrew/bin/brew shellenv | source
end

if test -x "/usr/local/bin/brew"
    /usr/local/bin/brew shellenv | source
end

if test -x "/opt/homebrew/bin/brew"
    /opt/homebrew/bin/brew shellenv | source
end

set -gx TZ America/Chicago

if type -q curl; and type -q curl-config; and curl-config --configure | string match --entire --quiet -r Cellar/curl
    set -l os (uname)

    if test "$os" = Darwin
        set -gx CURL_SSL_BACKEND secure-transport
    else if test "$os" = Linux
        set -gx CURL_CA_BUNDLE /etc/ssl/certs/ca-certificates.crt
    end
end
