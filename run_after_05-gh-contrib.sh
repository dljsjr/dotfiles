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
    # The clone goes over ssh on machines whose gitconfig rewrites github URLs;
    # that needs this machine's key registered with GitHub first (a manual
    # step). Skip gracefully — the next chezmoi apply retries.
    if ! gh repo clone dljsjr/gh-contrib "$GH_CONTRIB_DIR"
    then
        printf "gh-contrib clone failed (machine ssh key not registered with GitHub yet?); skipping, will retry on a later apply\n" >&2
        exit 0
    fi

    if command -v jj >/dev/null 2>&1
    then
        jj git init --colocate "$GH_CONTRIB_DIR"
    fi
fi

if [ -x "$GH_CONTRIB_DIR/install.sh" ]
then
    "$GH_CONTRIB_DIR/install.sh" --clobber
fi
