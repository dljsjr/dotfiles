#!/usr/bin/env bash
# UserPromptSubmit hook — inject the current LOCAL time into the model's context,
# so the assistant has a wall-clock anchor and can sense elapsed time between prompts.
# Output schema: hookSpecificOutput.additionalContext (UserPromptSubmit). Fires every prompt.
set -euo pipefail

# Local time on this machine (date uses the host tz). Weekday + tz/offset included so
# day-rollovers and DST are legible. e.g. "Thursday, 2026-06-18 11:28:09 CDT (-0500)".
now="$(date '+%A, %Y-%m-%d %H:%M:%S %Z (%z)')"
ctx="Current local time: ${now}"

# Emit the hook JSON. Prefer jq (bulletproof escaping); fall back to printf if absent.
if command -v jq >/dev/null 2>&1; then
  jq -nc --arg ctx "$ctx" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
else
  printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$ctx"
fi
