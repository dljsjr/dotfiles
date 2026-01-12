function install_watchman
  set_color -o
  printf "installing watchman for %s\n" (builtin pwd -P)
  set_color normal
  set -f gitdir (git rev-parse --git-dir)
  if [ -z "$gitdir" ]
    return 1
  end
  set -f gitdir (builtin realpath $gitdir)
  if not test -f $gitdir/hooks/query-watchman
    set_color -o green
    printf "copying hook fsmonitor-watchman.sample as query-watchman in gitdir %s\n" "$gitdir"
    set_color normal
    cp $gitdir/hooks/fsmonitor-watchman.sample $gitdir/hooks/query-watchman
  else
    set_color -o yellow
    printf "query-watchman hook already present in gitdir %s\n" "$gitdir"
    set_color normal
  end

  set -f git_fsmonitor (git config core.fsmonitor)

  if test -f "$git_fsmonitor"; and test (basename "$git_fsmonitor") = "query-watchman"
    set_color -o yellow
    printf "query-watchman hook already set as fsmonitor in gitdir %s\n" "$gitdir"
    set_color normal
  else
    set_color -o green
    printf "setting git config to use query-watchman hook in gitdir %s\n" "$gitdir"
    set_color normal
    git config core.fsmonitor $gitdir/hooks/query-watchman
  end

  set -f submodules (git submodule status | xargs -L 1 echo | cut -d ' ' -f 2- | sed -n 's/^\([^(]*\)(.*$/\1/p' | cut -d ' ' -f 1)
  for mod in $submodules
    pushd $mod
    install_watchman
    popd
  end
  set_color normal
end
