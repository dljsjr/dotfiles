#!/usr/bin/env sh

if { command -v rustup >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; } || { mise which rustup >/dev/null 2>&1 && mise which cargo >/dev/null 2>&1; }
then
    exit 0
fi

if command -v mise >/dev/null 2>&1
then
    mise use -g rust
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi
