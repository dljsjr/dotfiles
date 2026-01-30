function cdf
    set -l finder_dir (osascript -e 'tell application "Finder" to get POSIX path of (target of front Finder window as text)')
    if test -d "$finder_dir"
        cd "$finder_dir"
    end
end
