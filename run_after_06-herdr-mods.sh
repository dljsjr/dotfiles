#!/usr/bin/env sh

# herdr-mods owns the mods and the jj layout in the Herdr app home. Its
# install.sh tracks what it installed with manifests, so chezmoi manages only
# .config/herdr-app/settings.json there and leaves the rest to the installer.
HERDR_MODS_DIR="${HERDR_MODS_DIR:-$HOME/git/herdr-mods}"
HERDR_APP_HOME="${HERDR_APP_HOME:-$HOME/.config/herdr-app}"

if ! command -v herdr-app >/dev/null 2>&1
then
    printf "herdr-app not installed, skipping herdr-mods setup\n" >&2
    exit 0
fi

# Mods only run in a Herdr window. A headless Linux machine can still have
# herdr-app installed (alongside herdr-core), but it can't even start there,
# so don't run it: without a display server, skip.
if [ "$(uname -s)" = Linux ] && [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]
then
    printf "no display server (DISPLAY and WAYLAND_DISPLAY unset), skipping herdr-mods setup\n" >&2
    exit 0
fi

if ! [ -d "$HERDR_MODS_DIR" ]
then
    # Like gh-contrib, the clone goes over ssh and needs this machine's key
    # registered with GitHub; skip and retry on a later apply until it is.
    if ! command -v gh >/dev/null 2>&1 || ! gh repo clone dljsjr/herdr-mods "$HERDR_MODS_DIR"
    then
        printf "herdr-mods clone failed (gh missing, or machine ssh key not registered with GitHub yet?); skipping, will retry on a later apply\n" >&2
        exit 0
    fi

    if command -v jj >/dev/null 2>&1
    then
        jj git init --colocate "$HERDR_MODS_DIR"
    fi
fi

if ! [ -d "$HERDR_APP_HOME" ]
then
    printf "no Herdr app home at %s yet (open Herdr once); skipping herdr-mods install\n" "$HERDR_APP_HOME" >&2
    exit 0
fi

# install.sh refuses to replace mods edited in place or newer than the repo.
# Report that without failing the whole apply.
if ! sh "$HERDR_MODS_DIR/install.sh" install --app-home "$HERDR_APP_HOME"
then
    printf "herdr-mods install did not finish; see above, or run: %s/install.sh status\n" "$HERDR_MODS_DIR" >&2
fi
