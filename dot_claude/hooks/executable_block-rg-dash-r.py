#!/usr/bin/env -S uv run --script
"""PreToolUse(Bash) guard: block ripgrep invocations using a single-dash
`-r` short-flag cluster (-r, -rn, -rln, -nr, -rhoI, ...).

`rg -r`/`--replace` rewrites every match in the output; ripgrep recurses by
default, so a `grep -r` reflex silently corrupts results. Force `--replace`
(long form) when the rewrite is genuinely intended; everything else drops the
stray `r`. Only the single-dash short form is blocked — `--replace` passes.
"""
import json
import re
import shlex
import sys

# Single-dash cluster of ASCII letters that includes `r`. `--replace` starts
# with `--`, so the char after the first `-` is `-` (not a letter) and never
# matches. A bare `--` (end-of-options) stops flag scanning below.
_CLUSTER = re.compile(r"-[A-Za-z]*r[A-Za-z]*\Z")
_SEGMENT_SPLIT = re.compile(r"\|\||&&|[|;&\n]")


def offending_flag(command: str) -> str | None:
    for segment in _SEGMENT_SPLIT.split(command):
        try:
            tokens = shlex.split(segment)
        except ValueError:
            tokens = segment.split()
        for i, tok in enumerate(tokens):
            if tok != "rg" and not tok.endswith("/rg"):
                continue
            for arg in tokens[i + 1:]:
                if arg == "--":  # end of options; rest are patterns/paths
                    break
                if _CLUSTER.fullmatch(arg):
                    return arg
    return None


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0  # not our concern; let the tool proceed
    command = (data.get("tool_input") or {}).get("command", "")
    if not isinstance(command, str) or not command:
        return 0
    bad = offending_flag(command)
    if bad is None:
        return 0
    reason = (
        "-r is disallowed for confusion with directory recursion flags, "
        "use --replace if you really meant to use this flag"
    )
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": f"ripgrep flag {bad!r}: {reason}",
                }
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
