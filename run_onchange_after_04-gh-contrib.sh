#!/usr/bin/env sh

# gh-contrib owns the gh-*.sh alias scripts that land in ~/.local/bin; the
# physical files are install artifacts, not chezmoi-managed payload.
GH_CONTRIB_DIR="$HOME/git/gh-contrib"

if ! command -v gh >/dev/null 2>&1
then
    printf "gh not installed, skipping gh-contrib setup\n" >&2
    exit 0
fi

if ! [ -d "$GH_CONTRIB_DIR" ]
then
    if command -v jj >/dev/null 2>&1
    then
        gh repo clone dljsjr/gh-contrib "$GH_CONTRIB_DIR" && jj git init --colocate "$GH_CONTRIB_DIR"
    else
        gh repo clone dljsjr/gh-contrib "$GH_CONTRIB_DIR"
    fi
fi

if [ -x "$GH_CONTRIB_DIR/install.sh" ]
then
    "$GH_CONTRIB_DIR/install.sh" --clobber
fi
