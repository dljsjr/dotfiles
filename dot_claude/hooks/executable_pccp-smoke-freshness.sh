#!/usr/bin/env sh
# SessionStart hook: surface how stale the PCCP real-CC smoke battery is.
#
# This project has no CI by design (nothing is distributed from a forge)
# and jj supports no git hooks, so the battery only runs when an agent or
# human chooses to run it. An unrun battery looks exactly like a green one
# until it rots — which is how a deterministically-red resume smoke
# survived three weeks of feature work built on top of it.
#
# `cargo xtask smoke all` stamps .sandpiper/state/smoke-last-green.json on
# success; this reads that stamp and reports the age. Cheap, non-blocking,
# and never fails session start: any problem exits 0 silently.

set -u

cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
stamp="$cwd/.sandpiper/state/smoke-last-green.json"

# Only speak up inside this project.
[ -f "$cwd/xtask/src/smoke.rs" ] || exit 0

if [ ! -f "$stamp" ]; then
  printf 'PCCP smoke battery: NEVER recorded green (no stamp at .sandpiper/state/smoke-last-green.json).\nRun `cargo xtask smoke all` before trusting end-to-end behavior — and note red tests are fixed immediately, not filed (AGENTS.md).\n'
  exit 0
fi

last=$(sed -n 's/.*"lastGreenEpochSecs":\([0-9]*\).*/\1/p' "$stamp" 2>/dev/null)
[ -n "$last" ] || exit 0

now=$(date +%s)
age_days=$(( (now - last) / 86400 ))

if [ "$age_days" -ge 3 ]; then
  printf 'PCCP smoke battery last green %s day(s) ago — STALE. Run `cargo xtask smoke all` (Haiku, autonomously authorized) before or alongside this session'"'"'s work; end-to-end rot is invisible until it is run.\n' "$age_days"
elif [ "$age_days" -ge 1 ]; then
  printf 'PCCP smoke battery last green %s day(s) ago.\n' "$age_days"
fi

exit 0
