function ybar --wraps yazi --description 'alias ybar=YAZI_CONFIG_HOME=$HOME/.config/yazi/configs/sidebar yazi'
    YAZI_CONFIG_HOME="$HOME/.config/zide/yazi" yazi $argv
end
