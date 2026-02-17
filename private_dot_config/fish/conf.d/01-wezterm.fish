if test -n "$WEZTERM_PANE"; or test -n "$WEZTERM_REMOTE_PANE"
  function __wezterm_set_user_var
    set -l encoded (echo -n $argv[2] | base64)
    if type -q base64
      printf "\033]1337;SetUserVar=%s=%s\007" $argv[1] $encoded
    end
  end
end
